extends Node
class_name LuminanceManager

# ==================== SEÑALES ====================
signal luminance_changed(current: float, max_value: float)
signal threshold_reached(threshold: float, level: int)
signal condensation_triggered(level: int)

# ==================== CONFIG ====================
@export var starting_luminance: float = 0.0
@export var thresholds = [100, 200, 500, 1000]

var current_luminance: float = 0.0
var max_luminance: float = 9999.0  # se irá expandiendo

var current_limit: int = 5                    # límite inicial de figuras
var luminance_per_figure_base: float = 12.0   # al spawnear
var passive_per_second_per_figure: float = 1.8

# Control de decaimiento
var time_since_last_spawn: float = 0.0
var decay_delay: float = 12.0                 # segundos sin crear antes de decaer
var decay_rate: float = 0.8                   # por segundo

var condensation_level: int = 0

@onready var figura_manager = $"../FiguraManager"

func _ready():
	current_luminance = starting_luminance
	figura_manager.figure_spawned.connect(_on_figure_spawned)
	
	# Actualizar UI inicial
	emit_signal("luminance_changed", current_luminance, thresholds[condensation_level])


func _process(delta: float):
	if figura_manager.figuras_vivas.is_empty():
		return
	
	time_since_last_spawn += delta
	
	# === Generación pasiva ===
	var active_figures = figura_manager.figuras_vivas.size()
	var passive_gain = passive_per_second_per_figure * active_figures
	
	# Bonus por clusters (simple pero efectivo)
	var cluster_bonus = _calculate_cluster_bonus() * active_figures
	current_luminance += (passive_gain + cluster_bonus) * delta
	
	# === Decaimiento (tensión suave) ===
	if time_since_last_spawn > decay_delay:
		var decay_amount = decay_rate * (time_since_last_spawn - decay_delay) * delta
		current_luminance -= decay_amount
	
	current_luminance = clamp(current_luminance, 0.0, max_luminance)
	
	emit_signal("luminance_changed", current_luminance,  thresholds[condensation_level])
	
	_check_thresholds()


func _on_figure_spawned(_fig: Node):
	time_since_last_spawn = 0.0  # resetear contador de decaimiento
	
	# Ganancia al crear
	current_luminance += luminance_per_figure_base
	emit_signal("luminance_changed", current_luminance,  thresholds[condensation_level])
	
	_check_thresholds()


func _calculate_cluster_bonus() -> float:
	# Bonus simple: cuantas más figuras, mejor (puedes mejorarlo después)
	var count = figura_manager.figuras_vivas.size()
	if count >= 8:
		return 1.4
	elif count >= 5:
		return 0.9
	elif count >= 3:
		return 0.5
	return 0.0


func _check_thresholds():
	var target =  thresholds[condensation_level]
	
	if current_luminance >= target:
		condensation_level += 1
		current_luminance = 0.0
		_trigger_condensation(condensation_level)
		
		# Aumentar límite de figuras
		current_limit = 5 + (condensation_level * 8)
		figura_manager.limite_figuras = current_limit
		
		emit_signal("threshold_reached", target, condensation_level)


func _trigger_condensation(level: int):
	emit_signal("condensation_triggered", level)
	
	# Feedback fuerte (puedes conectar esto a partículas, shake, etc.)
	print("🌟 CONDENSACIÓN NIVEL ", level, " - Límite ahora: ", current_limit)


# ====================== MÉTODOS PÚBLICOS ======================

func get_current_luminance() -> float:
	return current_luminance

func get_progress_to_next_threshold() -> float:
	var next =  thresholds[condensation_level] * (condensation_level + 1)
	return current_luminance / next

func reset_for_new_world():
	current_luminance = 0.0
	condensation_level = 0
	current_limit = 5
	figura_manager.limite_figuras = 5
