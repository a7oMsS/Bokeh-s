extends Node
class_name ScoreManager

# ======== Tiers de calidad del gesto (quality = spin_ratio, 0-1) ========
const TIER_BUENO_MIN := 0.35
const TIER_PERFECTO_MIN := 0.75

const TIER_MULT_NORMAL := 1.0
const TIER_MULT_BUENO := 1.5
const TIER_MULT_PERFECTO := 2.5

const BASE_SCORE := 10.0

# ======== Combo ========
const COMBO_WINDOW := 4.0     # segundos entre éxitos para mantener el combo
const COMBO_STEP := 0.12      # cuánto suma cada nivel de combo al multiplicador
const COMBO_MULT_MAX := 3.0

# ======== Estado ========
var score: float = 0.0
var combo: int = 0
var max_combo: int = 0
var count_buenos: int = 0
var count_perfectos: int = 0
var count_normales: int = 0

var _time_since_last_success: float = 999.0

signal score_updated(total: float, delta: float)
signal combo_updated(combo: int, max_combo: int)


func _process(delta: float) -> void:
	_time_since_last_success += delta


func on_ritual_resolved(data: Dictionary) -> void:
	if data.get("type", "") != "condense":
		return

	if data.get("result", "") != "success":
		_break_combo()
		return

	_register_success(data.get("quality", 0.0), data.get("position", get_viewport().get_mouse_position()))


func _register_success(quality: float, position: Vector2) -> void:
	if _time_since_last_success > COMBO_WINDOW:
		combo = 0
	combo += 1
	max_combo = max(max_combo, combo)
	_time_since_last_success = 0.0

	var tier := _get_tier(quality)
	match tier:
		"perfecto": count_perfectos += 1
		"bueno": count_buenos += 1
		_: count_normales += 1

	var tier_mult := _get_tier_multiplier(tier)
	var combo_mult: float = min(1.0 + (combo - 1) * COMBO_STEP, COMBO_MULT_MAX)
	var gained := BASE_SCORE * tier_mult * combo_mult
	score += gained

	position += Vector2(50,-80)

	emit_signal("score_updated", score, gained, position)
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
	if quality >= TIER_PERFECTO_MIN:
		return "perfecto"
	elif quality >= TIER_BUENO_MIN:
		return "bueno"
	return "normal"


func _get_tier_multiplier(tier: String) -> float:
	match tier:
		"perfecto": return TIER_MULT_PERFECTO
		"bueno": return TIER_MULT_BUENO
		_: return TIER_MULT_NORMAL


func get_stats() -> Dictionary:
	return {
		"score": score, "combo": combo, "max_combo": max_combo,
		"buenos": count_buenos, "perfectos": count_perfectos, "normales": count_normales,
	}
