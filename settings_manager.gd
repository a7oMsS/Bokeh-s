extends Node
class_name SettingManager

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "es"

var master_volume: float = 1.0   # 0.0–1.0 lineal; se convierte a dB al aplicar
var locale: String = DEFAULT_LOCALE


func _ready() -> void:
	load_settings()
	_apply_all()


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_volume()
	save_settings()


func set_locale(new_locale: String) -> void:
	locale = new_locale
	TranslationServer.set_locale(locale)
	save_settings()


func _apply_all() -> void:
	_apply_volume()
	TranslationServer.set_locale(locale)


func _apply_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(master_volume, 0.0001)))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("general", "locale", locale)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return  # sin settings guardados todavía, se quedan los defaults
	master_volume = config.get_value("audio", "master_volume", master_volume)
	locale = config.get_value("general", "locale", locale)
