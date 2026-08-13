extends Node
class_name MasteryManager

## Reconversión de ScoreManager: la lógica de tiers y combo se queda tal
## cual estaba. Lo nuevo es todo el sistema de mastery/niveles, que reutiliza
## el mismo evento de éxito (_register_success) para no duplicar conexiones.
##
## Nivel 4 en adelante no existe en este demo a propósito -- según lo
## acordado, eso depende de superar el Mundo 1, algo que todavía no está
## construido. mastery_level se congela en MASTERY_MAX_LEVEL hasta entonces.

const TIER_GOOD_MIN := 0.35
const TIER_PERFECT_MIN := 0.75

const TIER_MULT_NORMAL := 1.0
const TIER_MULT_GOOD := 1.5
const TIER_MULT_PERFECT := 2.5

const BASE_SCORE := 10.0

const COMBO_WINDOW := 4.0
const COMBO_STEP := 0.12
const COMBO_MULT_MAX := 3.0

var score: float = 0.0
var combo: int = 0
var max_combo: int = 0
var count_good: int = 0
var count_perfect: int = 0
var count_normal: int = 0

var _time_since_last_success: float = 999.0

signal score_updated(total: float, delta: float)
signal combo_updated(combo: int, max_combo: int)


# ======== Mastery / niveles ========
const MASTERY_PER_INVOKE := 1.0
const VIGNETTE_DISPERSE_MASTERY := 0.2
const ELITE_DEFEATED_MASTERY := 5.0

## Nivel 1 = tus primeros 5 Bokeh, confirmado. El crecimiento exponencial
## y el factor 2.5 son ⚠️ propuesta mía -- da 5 / 12.5 / 31.25 de umbral
## acumulado para los niveles 1/2/3.
const MASTERY_LEVEL_BASE := 5.0
const MASTERY_LEVEL_GROWTH := 2.5
const MASTERY_MAX_LEVEL := 3

## Cupo de Bokeh al iniciar, antes de cualquier nivel ganado. Cada nivel
## suma +1 encima de esto.
const BASE_FIGURE_LIMIT := 5

var mastery: float = 0.0
var mastery_level: int = 0

signal mastery_changed(current: float, level: int)

@onready var figure_manager = $"../FigureManager"


func _ready() -> void:
	figure_manager.figure_limit = BASE_FIGURE_LIMIT + mastery_level
	EventBusAuto.vignette_dispersed.connect(_on_vignette_dispersed)
	emit_signal("mastery_changed", mastery, mastery_level)
	add_to_group("saveable_player")


func _process(delta: float) -> void:
	_time_since_last_success += delta


func on_ritual_resolved(data: Dictionary) -> void:
	if data.get("type", "") != RitualConstants.TYPE_CONDENSE:
		return

	if data.get("result", "") != RitualConstants.RESULT_SUCCESS:
		_break_combo()
		return

	_register_success(data.get("quality", 0.0))


func _register_success(quality: float) -> void:
	if _time_since_last_success > COMBO_WINDOW:
		combo = 0
	combo += 1
	max_combo = max(max_combo, combo)
	_time_since_last_success = 0.0

	var tier := _get_tier(quality)
	match tier:
		RitualConstants.TIER_PERFECT: count_perfect += 1
		RitualConstants.TIER_GOOD: count_good += 1
		_: count_normal += 1

	var tier_mult := _get_tier_multiplier(tier)
	var combo_mult: float = min(1.0 + (combo - 1) * COMBO_STEP, COMBO_MULT_MAX)
	var gained := BASE_SCORE * tier_mult * combo_mult
	score += gained

	_add_mastery(MASTERY_PER_INVOKE * tier_mult)

	emit_signal("score_updated", score, gained)
	emit_signal("combo_updated", combo, max_combo)

	EventBusAuto.emit_signal("score_changed", gained, score)
	EventBusAuto.emit_signal("timing_hit", tier)
	EventBusAuto.emit_signal("stats_changed", get_stats())


func _break_combo() -> void:
	if combo > 0:
		combo = 0
		emit_signal("combo_updated", combo, max_combo)
		EventBusAuto.emit_signal("stats_changed", get_stats())


func _get_tier(quality: float) -> String:
	if quality >= TIER_PERFECT_MIN:
		return RitualConstants.TIER_PERFECT
	elif quality >= TIER_GOOD_MIN:
		return RitualConstants.TIER_GOOD
	return RitualConstants.TIER_NORMAL


func _get_tier_multiplier(tier: String) -> float:
	match tier:
		RitualConstants.TIER_PERFECT: return TIER_MULT_PERFECT
		RitualConstants.TIER_GOOD: return TIER_MULT_GOOD
		_: return TIER_MULT_NORMAL


func get_stats() -> Dictionary:
	return {
		"score": score, "combo": combo, "max_combo": max_combo,
		"good": count_good, "perfect": count_perfect, "normal": count_normal,
	}


# ---------------- Mastery ----------------

func _on_vignette_dispersed(_vig: Node) -> void:
	_add_mastery(VIGNETTE_DISPERSE_MASTERY)


func _mastery_threshold(level: int) -> float:
	return MASTERY_LEVEL_BASE * pow(MASTERY_LEVEL_GROWTH, level - 1)


func _add_mastery(amount: float) -> void:
	if mastery_level >= MASTERY_MAX_LEVEL:
		return
	mastery += amount
	emit_signal("mastery_changed", mastery, mastery_level)
	_check_level_up()


func _check_level_up() -> void:
	if mastery_level >= MASTERY_MAX_LEVEL:
		return
	if mastery >= _mastery_threshold(mastery_level + 1):
		mastery_level += 1
		_apply_level_unlock(mastery_level)
		figure_manager.figure_limit = BASE_FIGURE_LIMIT + mastery_level
		EventBusAuto.emit_signal("level_up", mastery_level, _unlock_name_for_level(mastery_level))
		emit_signal("mastery_changed", mastery, mastery_level)


func _apply_level_unlock(level: int) -> void:
	match level:
		1: figure_manager.enable_shape(FigureEnums.Shape.SQUARE)
		2: figure_manager.enable_personality(FigureEnums.PersonalityType.BLINK)
		3: figure_manager.enable_size(FigureEnums.SizeCategory.MEDIUM)


func _unlock_name_for_level(level: int) -> String:
	match level:
		1: return "Forma: Cuadrado"
		2: return "Personalidad: Parpadeo"
		3: return "Tamaño: Mediano"
		_: return ""


# -------------------------------------------------
# Guardado
# -------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"mastery": mastery,
		"mastery_level": mastery_level,
		"score": score,
		"max_combo": max_combo,
		"good": count_good,
		"perfect": count_perfect,
		"normal": count_normal,
	}


## No alcanza con restaurar las dos variables — los desbloqueos reales
## viven como efecto secundario en FigureManager. Hay que re-aplicar cada
## nivel ganado, o el jugador ve "Nivel 2" sin tener el Parpadeo de verdad.
func load_save_data(data: Dictionary) -> void:
	mastery = data.get("mastery", 0.0)
	mastery_level = data.get("mastery_level", 0)
	score = data.get("score", 0.0)
	max_combo = data.get("max_combo", 0)
	count_good = data.get("good", 0)
	count_perfect = data.get("perfect", 0)
	count_normal = data.get("normal", 0)

	for level in range(1, mastery_level + 1):
		_apply_level_unlock(level)

	figure_manager.figure_limit = BASE_FIGURE_LIMIT + mastery_level
	emit_signal("mastery_changed", mastery, mastery_level)
