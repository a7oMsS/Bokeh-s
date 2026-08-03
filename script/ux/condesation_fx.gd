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
const COLOR_BONUS := Color(0.7, 0.9, 1.0, 1.0)

const SCALE_MIN := 0.35
const SCALE_MAX := 0.85
const SCALE_BONUS := 0.35

const SPRING_STIFFNESS := 55.0
const SPRING_DAMPING := 0.78
const SPIN_KICK_STRENGTH := 2.0

# Cuánto tarda el núcleo en "sentirse lleno" con solo sostener.
# Es un parámetro de presentación del ritual, no de validación de input.
const HOLD_FOR_GUARANTEED := 0.8

var _scale_current := SCALE_MIN
var _scale_velocity := 0.0
var _last_quality := 0.0


func begin(pos: Vector2) -> void:
	super.begin(pos)
	ritual_type = "condense"

	_scale_current = SCALE_MIN
	_scale_velocity = 0.0
	_last_quality = 0.0

	core.modulate = COLOR_EMBER
	sparks.modulate = COLOR_EMBER
	light.color = COLOR_EMBER
	ring.modulate = COLOR_EMBER

	core.scale = Vector2.ONE * SCALE_MIN
	ring.scale = Vector2.ZERO
	sparks.emitting = true

	emit_signal("condense_start", {"position": pos})


func _process(delta: float) -> void:
	super._process(delta)

	progress = clamp(elapsed / HOLD_FOR_GUARANTEED, 0.0, 1.0)

	var target_scale = SCALE_MIN + (SCALE_MAX - SCALE_MIN) * progress + SCALE_BONUS * quality
	var force = (target_scale - _scale_current) * SPRING_STIFFNESS
	_scale_velocity += force * delta
	_scale_velocity *= SPRING_DAMPING
	_scale_current += _scale_velocity * delta
	
	var pulse_speed = 5.0 + (progress * 10.0) # Más rápido al cargar
	var pulse_amplitude = 0.1 + (progress * 0.15) # Más violento al cargar
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

	sparks.speed_scale = lerp(0.3, 1.5, progress)


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
	tween.tween_property(core, "scale", core.scale * (1.6 + quality * 0.8), 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(core, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
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
	tween.finished.connect(func():
		_finish("cancel")
		queue_free()
	)
