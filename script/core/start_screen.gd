extends Control
class_name StartScreen

const WORLD_1_SCENE := "res://scenes/core/world_1.tscn"

@onready var btn_jugar: Button = $BtnJugar
@onready var btn_config: Button = $BtnConfiguracion
@onready var settings_panel: Control = $SettingsPanel


func _ready() -> void:
	settings_panel.visible = false
	btn_jugar.text = "Continuar" if SaveManager.has_save() else "Jugar"
	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_config.pressed.connect(_on_config_pressed)

func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file(WORLD_1_SCENE)

func _on_config_pressed() -> void:
	settings_panel.visible = not settings_panel.visible
