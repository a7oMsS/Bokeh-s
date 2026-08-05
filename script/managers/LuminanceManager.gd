extends Node
class_name LuminanceManager

signal luminance_changed(current: float, max_value: float)
signal threshold_reached(threshold: float, level: int)
signal condensation_triggered(level: int)

@export var starting_luminance: float = 0.0
@export var thresholds = [100, 200, 500, 1000]
@export var threshold_growth_factor: float = 1.5  # escalado tras agotar la lista

var current_luminance: float = 0.0
var max_luminance: float = 9999.0

var current_limit: int = 5
var luminance_per_figure_base: float = 12.0
var passive_per_second_per_figure: float = 1.8

var time_since_last_spawn: float = 0.0
var decay_delay: float = 12.0
var decay_rate: float = 0.8

var condensation_level: int = 0

@onready var figura_manager = $"../FiguraManager"

func _ready():
	current_luminance = starting_luminance
	figura_manager.figure_spawned.connect(_on_figure_spawned)
	emit_signal("luminance_changed", current_luminance, _get_threshold_for_level(condensation_level))


func _process(delta: float):
	if figura_manager.figuras_vivas.is_empty():
		return

	time_since_last_spawn += delta

	var active_figures = figura_manager.figuras_vivas.size()
	var passive_gain = passive_per_second_per_figure * active_figures
	var cluster_bonus = _calculate_cluster_bonus() * active_figures
	current_luminance += (passive_gain + cluster_bonus) * delta

	if time_since_last_spawn > decay_delay:
		var decay_amount = decay_rate * (time_since_last_spawn - decay_delay) * delta
		current_luminance -= decay_amount

	current_luminance = clamp(current_luminance, 0.0, max_luminance)

	emit_signal("luminance_changed", current_luminance, _get_threshold_for_level(condensation_level))
	_check_thresholds()


func _on_figure_spawned(_fig: Node):
	time_since_last_spawn = 0.0
	current_luminance += luminance_per_figure_base
	emit_signal("luminance_changed", current_luminance, _get_threshold_for_level(condensation_level))
	_check_thresholds()


func _calculate_cluster_bonus() -> float:
	var count = figura_manager.figuras_vivas.size()
	if count >= 8:
		return 1.4
	elif count >= 5:
		return 0.9
	elif count >= 3:
		return 0.5
	return 0.0


func _check_thresholds():
	var target = _get_threshold_for_level(condensation_level)

	if current_luminance >= target:
		condensation_level += 1
		current_luminance = 0.0
		_trigger_condensation(condensation_level)

		current_limit = 5 + (condensation_level * 8)
		figura_manager.limite_figuras = current_limit

		emit_signal("threshold_reached", target, condensation_level)


func _trigger_condensation(level: int):
	emit_signal("condensation_triggered", level)
	print("🌟 CONDENSACIÓN NIVEL ", level, " - Límite ahora: ", current_limit)


# Umbrales diseñados a mano para los primeros niveles; más allá de la
# lista, escala geométricamente para que el juego nunca se quede sin
# umbral que consultar.
func _get_threshold_for_level(level: int) -> float:
	if level < thresholds.size():
		return thresholds[level]
	var last = thresholds[thresholds.size() - 1]
	var extra_levels = level - thresholds.size() + 1
	return last * pow(threshold_growth_factor, extra_levels)


# ====================== MÉTODOS PÚBLICOS ======================

func get_current_luminance() -> float:
	return current_luminance

func get_progress_to_next_threshold() -> float:
	# Antes multiplicaba por (condensation_level + 1), lo cual no
	# coincidía con el umbral real usado en _check_thresholds().
	var target = _get_threshold_for_level(condensation_level)
	return current_luminance / target

func reset_for_new_world():
	current_luminance = 0.0
	condensation_level = 0
	current_limit = 5
	figura_manager.limite_figuras = 5
