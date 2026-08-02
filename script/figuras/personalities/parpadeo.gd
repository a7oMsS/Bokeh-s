# PersonalityParpadeo.gd
extends FiguraPersonality

@warning_ignore("shadowed_variable_base_class")
func setup(_owner) -> void:
	super.setup(_owner)
	var tween = owner.create_tween().set_loops()
	tween.tween_property(owner, "modulate:a", 0.2, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(owner, "modulate:a", 1.0, 0.5)

func _process(delta):
	super._process(delta)
