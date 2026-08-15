extends Control
class_name StartScreen

const WORLD_1_SCENE := "res://scenes/core/worlds/world_base.tscn"
const PROLOGUE_SCENE := "res://scenes/core/prologue.tscn"


const LOCALES := ["es", "en"]  # ajustar cuando existan traducciones reales

@onready var btn_jugar: Label = $BtnJugar
@onready var btn_config: TextureButton = $BtnConfiguracion
@onready var settings_panel: Control = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer2/VolumeSlider
@onready var language_dropdown: OptionButton = $SettingsPanel/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/LanguageDropdown
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var def_text = "Presiona cualquier lugar para "


@export var base_window_width: float = 1152.0
@export var base_font_size: int = 30

func _ready() -> void:
	settings_panel.visible = false
	btn_jugar.text = def_text + "Continuar" if SaveManager.has_save() else def_text +  "Jugar"
	gui_input.connect(_play_fade_in)
	anim_player.animation_finished.connect(_start_game)
	btn_config.pressed.connect(_on_config_pressed)

	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = SettingsManager.master_volume
	volume_slider.value_changed.connect(SettingsManager.set_master_volume)

	language_dropdown.clear()
	for loc in LOCALES:
		language_dropdown.add_item(loc.to_upper())
	language_dropdown.selected = max(LOCALES.find(SettingsManager.locale), 0)
	language_dropdown.item_selected.connect(_on_language_selected)

	_resize_ui()
	get_window().size_changed.connect(_resize_ui)
	

func _on_language_selected(index: int) -> void:
	SettingsManager.set_locale(LOCALES[index])

func _play_fade_in(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		anim_player.play("play")

func _start_game(anim_name) -> void:
	if anim_name == "play":
		get_tree().change_scene_to_file(WORLD_1_SCENE)

func _on_config_pressed() -> void:
	settings_panel.visible = not settings_panel.visible

func _resize_ui() -> void:
	var current_window_width = get_viewport().get_visible_rect().size.x
	
	# Calculate scaling ratio based on width
	var scale_factor = current_window_width / base_window_width
	var new_font_size = clampi(side_effect_floor(base_font_size * scale_factor), 12, 128)
	
	# Override the current font size theme property
	btn_jugar.add_theme_font_size_override("font_size", new_font_size)

# Helper function to compute floor cleanly
func side_effect_floor(value: float) -> int:
	return int(floor(value))
