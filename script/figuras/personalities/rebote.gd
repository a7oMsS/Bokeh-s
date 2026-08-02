# PersonalityRebote.gd
extends FiguraPersonality

func setup(_owner):
	super.setup(_owner)
	velocity = Vector2(randf_range(-200,200), randf_range(-200,200))

func _process(delta):
	super._process(delta)
