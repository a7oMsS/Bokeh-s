extends Node
class_name ScoreManager

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
