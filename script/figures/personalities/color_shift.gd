# color_shift.gd
extends FigurePersonality

const CYCLE_DURATION := 1.0

func setup(_owner):
	owner = _owner
	_loop()

func _loop():
	if owner == null:
		return
	var tween = owner.create_tween()
	tween.tween_property(owner.body_mesh.material, "shader_parameter/color_a", get_random_color(), CYCLE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(owner.body_mesh.material, "shader_parameter/color_b", get_random_color(), CYCLE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_loop)

func get_random_color() -> Color:
	var hue = randf()
	var saturation = randf_range(0.55, 0.85)
	var value = randf_range(0.8, 1.3)
	return Color.from_hsv(hue, saturation, value, 1.0)
