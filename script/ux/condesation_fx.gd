extends BaseRitual
class_name CondenseRitual

signal condense_start(data: Dictionary)
signal condense_progress(data: Dictionary)
signal condense_release(data: Dictionary)
signal condense_cancel(data: Dictionary)

@onready var core: Sprite2D = $Core
@onready var sparks: CPUParticles2D = $Sparks
@onready var light: PointLight2D = $PointLight2D
@onready var ring: Sprite2D = $Ring

const COLOR_EMBER := Color(1.0, 0.55, 0.1, 0.85)
const COLOR_CHARGED := Color(1.0, 0.84, 0.0, 1.0)
const COLOR_BONUS := Color(0.0, 0.778, 0.785, 1.0)  # mismo pastel, hue corregido a 180° exacto

const SCALE_MIN := 0.35
const SCALE_MAX := 0.85
const SCALE_BONUS := 0.35

const SPRING_STIFFNESS := 55.0
const SPRING_DAMPING := 0.78
const SPIN_KICK_STRENGTH := 2.0

# Cuánto tarda el núcleo en "sentirse lleno" con solo sostener.
# Es un parámetro de presentación del ritual, no de validación de input.
const HOLD_FOR_GUARANTEED := 0.5

var _scale_current := SCALE_MIN
var _scale_velocity := 0.0
var _last_quality := 0.0

const TRAIL_RADIUS := 125.0

@onready var trail: Line2D = $Trail
@onready var boundary_ring: Line2D = $BoundaryRing

func begin(pos: Vector2) -> void:
	super.begin(pos)
	ritual_type = "condense"
	
	trail.reset()
	trail.modulate.a = 1.0
	trail.visible = true

	boundary_ring.modulate.a = 0.25
	_build_boundary_ring()

	_scale_current = SCALE_MIN
	_scale_velocity = 0.0
	_last_quality = 0.0

	core.modulate = COLOR_EMBER
	sparks.modulate = COLOR_EMBER
	light.color = COLOR_EMBER
	ring.modulate = COLOR_EMBER*1.6

	core.scale = Vector2.ONE * SCALE_MIN
	ring.scale = Vector2.ZERO
	sparks.emitting = true

	emit_signal("condense_start", {"position": pos})


func _process(delta: float) -> void:
	super._process(delta)
	if _resolved:
		return

	progress = clamp(elapsed / HOLD_FOR_GUARANTEED, 0.0, 1.0)

	var target_scale = SCALE_MIN + (SCALE_MAX - SCALE_MIN) * progress + SCALE_BONUS * quality
	var force = (target_scale - _scale_current) * SPRING_STIFFNESS
	_scale_velocity += force * delta
	_scale_velocity *= SPRING_DAMPING
	_scale_current += _scale_velocity * delta
	
	var pulse_speed = 5.0 + (progress * 10.0) # Más rápido al cargar
	var pulse_amplitude = 0.5 + (progress * 0.15) # Más violento al cargar
	var oscillation = sin(elapsed * pulse_speed) * pulse_amplitude

	core.scale = Vector2.ONE * (_scale_current + (oscillation * 0.1))
	ring.scale = Vector2.ONE * (_scale_current * 0.55) * quality
	ring.rotation += quality * delta * 10.0

	var charge_color = COLOR_EMBER.lerp(COLOR_CHARGED, progress)
	var final_color = charge_color.lerp(COLOR_BONUS, quality)
	core.modulate = final_color
	sparks.modulate = final_color
	light.color = final_color
	light.energy = lerp(1.2, 2.6, progress) + quality * 0.8

	sparks.speed_scale = lerp(0.3, 1.2, progress)
	sparks.radial_accel_max = lerp(-75.0, -250.0,quality)
	sparks.tangential_accel_min = lerp(22.0, 280.0,quality)
	sparks.radial_accel_min = lerp(-100.0, -400.0,quality)
	sparks.tangential_accel_max = lerp(90.0, 450.0,quality)
	

func update(new_quality: float) -> void:
	super.update(new_quality)
	
	# Cada fracción nueva de giro empuja el resorte — de ahí el rebote.
	if new_quality > _last_quality:
		_scale_velocity += (new_quality - _last_quality) * SPIN_KICK_STRENGTH
	_last_quality = new_quality

	emit_signal("condense_progress", {"progress": progress, "quality": quality})


func resolve(final_quality: float = 0.0) -> void:
	super.resolve(final_quality)

	emit_signal("condense_release", {"quality": quality})
	sparks.emitting = false

	var tween = create_tween()
	tween.tween_property(core, "scale", core.scale * (1.6 + quality * 0.8), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(core, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	# dentro de resolve(), junto al tween existente:
	tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(boundary_ring, "modulate:a", 0.0, 0.3)
	
	tween.finished.connect(func():
		_finish("success")
		queue_free()
	)


func cancel() -> void:
	emit_signal("condense_cancel", {})
	sparks.emitting = false

	var tween = create_tween()
	tween.tween_property(core, "scale", Vector2.ZERO, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(core, "modulate:a", 0.0, 0.35)
	# dentro de cancel(), junto al tween existente:
	tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(boundary_ring, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		_finish("cancel")
		queue_free()
	)
	
func add_trail_point(angle: float) -> void:
	var point = Vector2(cos(angle), sin(angle)) * TRAIL_RADIUS
	trail.add_point_at(point)


# Anillo estático que marca el límite de la zona de interacción — referencia
# la MISMA constante que usa InputRitualManager, para que nunca se desincronicen.
func _build_boundary_ring() -> void:
	boundary_ring.clear_points()
	var segments := 48
	for i in range(segments + 1):
		var t = (float(i) / segments) * TAU
		boundary_ring.add_point(Vector2(cos(t), sin(t)) * InputRitualManager.MAX_RADIUS)
