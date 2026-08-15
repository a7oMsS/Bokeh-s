extends Label

var tween: Tween

func _ready():
	tween = create_tween()
	
	tween.tween_property(self, "modulate:a", 0.1,0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.6,0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
	tween.play()

func _stop_tween():
	tween.stop()
