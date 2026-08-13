extends CanvasLayer
class_name Hud

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_text.tscn")

@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var cursor_visual: CursorVisual = $CursorVisual
@onready var luminance_bar: LuminanceBar = $LuminanceBar


func setup(figure_manager: FigureManager) -> void:
	cursor_visual.figure_manager = figure_manager


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


func on_condense_started(pos: Vector2) -> void:
	cursor_visual.on_condense_started(pos)


func on_ritual_resolved(data: Dictionary) -> void:
	cursor_visual.on_ritual_resolved(data)


func update_luminance(current: float, max_value: float) -> void:
	luminance_bar.update_luminance(current, max_value)


func trigger_condensation_reset(level: int) -> void:
	luminance_bar.trigger_condensation_reset(level)
