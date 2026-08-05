extends CanvasLayer

var FloatingText = preload("res://escenas/ui/FloatingText.tscn")

var viewport_size: Vector2
var expanded := false

@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel


func show_floating_text(points: float, position):
	var ft := FloatingText.instantiate()
	add_child(ft)
	ft.show_value(points, position)

func update_score(total: float, delta: float, position: Vector2) -> void:
	#score_label.text = "Puntos: %d" % int(round(total))
	show_floating_text(delta, position)

func update_combo(combo: int, _max_combo: int) -> void:
	return
	#combo_label.text = "" if combo <= 1 else "Combo x%d" % combo
