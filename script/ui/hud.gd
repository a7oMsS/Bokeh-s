extends CanvasLayer
class_name Hud

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_text.tscn")

@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel


func show_floating_text(points: float):
	var ft := FLOATING_TEXT_SCENE.instantiate()
	add_child(ft)
	ft.show_value(points, get_viewport().get_mouse_position())


func update_score(total: float, delta: float) -> void:
	#score_label.text = "Score: %d" % int(round(total))
	show_floating_text(delta)


func update_combo(combo: int, _max_combo: int) -> void:
	return
	#combo_label.text = "" if combo <= 1 else "Combo x%d" % combo
