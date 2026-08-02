extends FiguraPersonality

func setup(_owner):
	super.setup(_owner)
	# Tween que va cambiando a colores random
	_loop()

func _loop():
	if owner == null:
		return
	var tween = owner.create_tween()
	tween.tween_property(owner.mesh_instance, "material:shader_parameter/color_a", get_color_aleatorio(), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) 
	tween.tween_property(owner.mesh_instance, "material:shader_parameter/color_b", get_color_aleatorio(), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) 
	tween.finished.connect(_loop) # vuelve a iniciar

func get_color_aleatorio() -> Color:
	return Color(randf()*1.2, randf()*1.2, randf()*1.2, randf_range(0.1, 0.5))
	
func _process(delta):
	super._process(delta)
