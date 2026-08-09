extends ProgressBar
class_name LuminanceBar

@onready var label: Label = $"../Luminalbl"
@onready var particles: GPUParticles2D = $progressBarParticles

var start_color := Color(0.703, 0.74, 0.0, 1.0)
var end_color := Color(0.0, 0.505, 0.463, 1.0)
var start_color_glow := Color(0.95, 0.855, 0.0, 0.298)
var end_color_glow := Color(0.047, 0.553, 0.94, 0.38)

var tween: Tween

func _ready():
	max_value = 100.0
	get_window().size_changed.connect(_on_window_resize)
	_on_window_resize()
	particles.amount_ratio = 0


func _on_window_resize():
	particles.process_material.emission_box_extents = Vector3(size.x / 5 * 3, size.y * 1.7, 1.0)
	particles.position = Vector2(size.x / 2, size.y / 4)


func update_luminance(current: float, max_val: float):
	max_value = max_val
	value = current

	var t = clamp(current / max_val, 0.0, 1.0)
	var fill_color = start_color.lerp(end_color, t)
	var glow_color = start_color_glow.lerp(end_color_glow, t)

	var style = get_theme_stylebox("fill") as StyleBoxFlat
	style.bg_color = fill_color
	style.shadow_color = glow_color

	var target_ratio = lerp(0.0, 1.0, t)
	particles.amount_ratio = target_ratio

	## Compensates particle emission offset for the bar's skew shader.
	var skew_offset_x = size.x * t * 0.05
	var skew_offset_y = size.y * t * 0.2

	particles.position = Vector2(
		size.x * t * 0.5 + skew_offset_x,
		size.y * 0.5 - skew_offset_y
	)

	particles.process_material.emission_box_extents = Vector3(
		size.x * t * 0.5,
		size.y * 0.5,
		1.0
	)

	particles.modulate = fill_color * 2

	if t > 0.85:
		particles.amount_ratio = int(target_ratio * 1.6)


func trigger_condensation_reset(_level: int):
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "value", 0.0, 0.48) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35) \
		.set_delay(0.1)

	tween.tween_property(self, "modulate", Color(1.992, 1.313, 2.0, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.4) \
		.set_delay(0.1)
