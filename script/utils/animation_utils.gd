extends Node
class_name AnimationUtils

static func fade_scale_in(node: Control, delay: float=0.0, duration: float=0.25):
	var t = node.create_tween()
	node.modulate.a = 0
	node.scale = Vector2(0.5,0.5)
	t.tween_interval(delay)
	t.tween_property(node, "modulate:a", 1, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "scale", Vector2.ONE, duration)

static func fade_scale_out(node: Control, delay: float=0.0, duration: float=0.15):
	var t = node.create_tween()
	t.tween_interval(delay)
	t.tween_property(node, "modulate:a", 0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "scale", Vector2(0.5,0.5), duration)
