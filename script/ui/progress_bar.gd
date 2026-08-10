extends ProgressBar
class_name LuminanceBar

@onready var label: Label = $"../Luminalbl"
@onready var particles: GPUParticles2D = $progressBarParticles

var start_color := Color(0.703, 0.74, 0.0, 1.0)
var end_color := Color(0.0, 0.505, 0.463, 1.0)
var start_color_glow := Color(0.95, 0.855, 0.0, 0.298)
var end_color_glow := Color(0.047, 0.553, 0.94, 0.38)

var tween: Tween

# ---- Visibilidad: oculta hasta que sale de 0 por primera vez; si vuelve
# a caer exactamente a 0 y se queda ahí un rato, se oculta otra vez. ----
const ZERO_EPSILON := 0.01
const HIDE_AFTER_ZERO_TIME := 3.0
const VISIBILITY_FADE_TIME := 0.4

var _is_at_zero := true
var _zero_timer := 0.0
var _visibility_tween: Tween


func _ready():
	max_value = 100.0
	get_window().size_changed.connect(_on_window_resize)
	_on_window_resize()
	particles.amount_ratio = 0

	modulate.a = 0.0
	label.modulate.a = 0.0


func _process(delta: float) -> void:
	if not _is_at_zero:
		return
	_zero_timer += delta
	if modulate.a > 0.0 and _zero_timer >= HIDE_AFTER_ZERO_TIME:
		_set_visibility(false)


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

	# ---- visibilidad ----
	_is_at_zero = current <= ZERO_EPSILON
	if not _is_at_zero:
		_zero_timer = 0.0
		_set_visibility(true)


func _set_visibility(should_show: bool) -> void:
	if _visibility_tween and _visibility_tween.is_valid():
		_visibility_tween.kill()

	var target_alpha := 1.0 if should_show else 0.0
	_visibility_tween = create_tween()
	_visibility_tween.set_parallel(true)
	_visibility_tween.tween_property(self, "modulate:a", target_alpha, VISIBILITY_FADE_TIME)
	_visibility_tween.tween_property(label, "modulate:a", target_alpha, VISIBILITY_FADE_TIME)


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
