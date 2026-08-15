extends Control

@onready var backdrop: ColorRect = $DarkBackdrop

func _ready() -> void:
	backdrop.gui_input.connect(_on_config_pressed)
func _on_config_pressed(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		visible = not visible

func _on_button_pressed() -> void:
	visible = not visible
