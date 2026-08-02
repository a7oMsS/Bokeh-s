extends BaseRitual
class_name CondenseRitual

signal condense_start(data: Dictionary)
signal condense_held(data: Dictionary)
signal condense_pushed(data: Dictionary)
signal condense_release(data: Dictionary)
signal condense_cancel(data: Dictionary)

@onready var core = $Core
@onready var sparks = $Sparks
@onready var light = $PointLight2D
@onready var ring = $Ring

var result_type := ""
var energy := 0.0
const ENERGY_REQUIRED := 12.5 # Aprox. 2 vueltas completas (2 * PI * 2)
var is_charged := false
var stability := 1.0
var last_mouse_pos := Vector2.ZERO

func begin(pos: Vector2) -> void:
	super.begin(pos)
	ritual_type = "condense"
	position = pos

	var tween = create_tween()
	
	tween.tween_property(core, "scale", Vector2.ONE*0.45, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring.scale = Vector2.ZERO
	
	var base_color = Color.html("ffd700a6")
	core.modulate = base_color
	sparks.modulate = base_color
	light.color = base_color
	ring.modulate = base_color
	sparks.emitting = true
	
	emit_signal("condense_start", {"position": pos})


func update(acc_rotation: float, new_stability: float) -> void:
	energy = acc_rotation
	stability = new_stability
	
	if energy >= ENERGY_REQUIRED:
		is_charged = true
	
	# Progresión normalizada (0.0 a 1.0)
	var progress = clamp(energy / ENERGY_REQUIRED, 0.0, 1.0)
	
	# --- EFECTO VISUAL SINUSOIDAL INESTABLE ---
	# Aumentamos la frecuencia y la amplitud de la pulsación según el progreso
	var pulse_speed = 5.0 + (progress * 10.0) # Más rápido al cargar
	var pulse_amplitude = 0.05 + (progress * 0.15) # Más violento al cargar
	var oscillation = sin(elapsed * pulse_speed) * pulse_amplitude
	
	# Aplicar escalas
	core.scale = Vector2.ONE * (0.4 + (progress * 0.6) + (oscillation * 0.5))
	ring.scale = Vector2.ONE * (0.2 + (progress * 0.3) + oscillation)
	ring.rotation += progress
	
	# Feedback de color por inestabilidad y carga
	var charge_color = Color.html("ffd700").lerp(Color.html("ff4500"), progress * (1.0 - stability))
	ring.modulate = charge_color
	
	emit_signal("condense_held", {
		"progress": progress,
		"stability": stability,
		"is_charged": is_charged
	})


func push_final() -> void:
	if is_charged:
		resolve("success")
	else:
		resolve("cancel")


func resolve(type: String) -> void:
	if result_type != "": return
	result_type = type
	
	match type:
		"success":
			_release()
		"overload", "cancel":
			_dissipate()


func _release() -> void:
	emit_signal("condense_release", {"energy": clamp(elapsed / 3.8, 0.0, 1.0)})
	sparks.emitting = false
	emit_signal("finished", {
		"type": ritual_type,
		"result": "success",
		"energy": clamp(elapsed / 3.8, 0.0, 1.0),
		"stability": stability,
		"position": position
	})
	
	var tween = create_tween()
	tween.tween_property(core, "scale", core.scale * 2.4, 0.75).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(core, "modulate:a", 0.0, 0.85)
	tween.finished.connect(queue_free)


func _dissipate() -> void:
	emit_signal("condense_cancel", {})
	var tween = create_tween()
	tween.tween_property(core, "scale", Vector2.ZERO, 0.45)
	tween.finished.connect(queue_free)
