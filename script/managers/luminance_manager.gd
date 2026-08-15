extends Node
class_name LuminanceManager

signal luminance_changed(current: float, max_value: float)
signal world_purified()

@export var energia_total: float = 1200.0

var current_luminance: float = 0.0

const BOKEH_INVOKE_BONUS := 35.0
const BOKEH_PASSIVE_PER_SECOND := 1.0
const VIGNETTE_SPAWN_HIT := 8.0
const VIGNETTE_PASSIVE_PER_SECOND := 0.5
const VIGNETTE_DISPERSE_BONUS := 3.0

const ELITE_SPAWN_HIT := 14.0
const ELITE_PASSIVE_PER_SECOND := 1.25
const ELITE_DEFEAT_BONUS := 50.0
const ELITE_TRIGGER_RATIO := 0.9

var _elite_triggered := false
var _elite_active := false

var _purified := false

var figure_manager: FigureManager
var shadow_manager: ShadowManager


## Reemplaza a los @onready var ... = $"../X" que tenía antes — ya no
## asume su posición en el árbol, la recibe de world.gd.
func setup(fm: FigureManager, sm: ShadowManager) -> void:
	figure_manager = fm
	shadow_manager = sm
	figure_manager.figure_spawned.connect(_on_bokeh_invoked)
	shadow_manager.vignette_spawned.connect(_on_vignette_spawned)
	shadow_manager.vignette_dispersed.connect(_on_vignette_dispersed)
	shadow_manager.elite_spawned.connect(_on_elite_spawned)
	shadow_manager.elite_defeated.connect(_on_elite_defeated)


func _ready() -> void:
	emit_signal("luminance_changed", current_luminance, energia_total)
	add_to_group("saveable_world")

func _process(delta: float) -> void:
	if _purified:
		return

	var bokeh_count = figure_manager.active_figures.size()
	var vignette_count = shadow_manager.active_vignette.size()  # ya excluye al Elite por construccion

	var net_per_second = (BOKEH_PASSIVE_PER_SECOND * bokeh_count) - (VIGNETTE_PASSIVE_PER_SECOND * vignette_count)
	if _elite_active:
		net_per_second -= ELITE_PASSIVE_PER_SECOND
	_apply_delta(net_per_second * delta)

	if not _elite_triggered and current_luminance >= energia_total * ELITE_TRIGGER_RATIO:
		_elite_triggered = true
		shadow_manager.spawn_elite()


func _on_bokeh_invoked(_fig: Node) -> void:
	_apply_delta(BOKEH_INVOKE_BONUS)


func _on_vignette_spawned(_vig: Node, counts_as_spawn: bool) -> void:
	if counts_as_spawn:
		_apply_delta(-VIGNETTE_SPAWN_HIT)

func _on_elite_spawned(_vig: Node) -> void:
	_elite_active = true
	_apply_delta(-ELITE_SPAWN_HIT)

func _on_elite_defeated(_vig: Node) -> void:
	_elite_active = false
	_apply_delta(ELITE_DEFEAT_BONUS)

func _on_vignette_dispersed(_vig: Node) -> void:
	_apply_delta(VIGNETTE_DISPERSE_BONUS)


func _apply_delta(amount: float) -> void:
	if _purified:
		return

	current_luminance = clamp(current_luminance + amount, 0.0, energia_total)
	emit_signal("luminance_changed", current_luminance, energia_total)

	if current_luminance >= energia_total and not _elite_active:
		_purified = true
		emit_signal("world_purified")


# ====================== API PÚBLICA ======================

func get_current_luminance() -> float:
	return current_luminance

func get_progress() -> float:
	return current_luminance / energia_total

func reset_for_new_world() -> void:
	current_luminance = 0.0
	_purified = false
	emit_signal("luminance_changed", current_luminance, energia_total)


# -------------------------------------------------
# Guardado
# -------------------------------------------------
func get_save_data() -> Dictionary:
	return {"current_luminance": current_luminance, "purified": _purified}


func load_save_data(data: Dictionary) -> void:
	current_luminance = data.get("current_luminance", 0.0)
	_purified = data.get("purified", false)
	emit_signal("luminance_changed", current_luminance, energia_total)
