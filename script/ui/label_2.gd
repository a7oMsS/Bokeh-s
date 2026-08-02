extends Label

func _ready():
	var tween = create_tween()
	
	tween.tween_property(self, "modulate:a", 0.1,0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.6,0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
	tween.play()
