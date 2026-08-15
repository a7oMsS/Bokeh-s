extends Node
class_name ShadowManager

@export var vignette_scene = preload("res://scenes/objects/vignette.tscn")

var active_vignette: Array = []

@export var vignette_limit := 16

signal vignette_spawned(vig: Node, counts_as_spawn: bool)
signal vignette_dispersed(vig: Node)
signal elite_spawned(vig: Node)
signal elite_defeated(vig: Node)

var _elite: Node = null

var all_hardness: Array[VignetteEnums.Hardness] = [
	VignetteEnums.Hardness.SOFT, VignetteEnums.Hardness.NORMAL, VignetteEnums.Hardness.DENSE,
]
var all_sizes: Array[VignetteEnums.SizeCategory] = [
	VignetteEnums.SizeCategory.SMALL, VignetteEnums.SizeCategory.MEDIUM, VignetteEnums.SizeCategory.LARGE,
]

const ALL_DEPTHS: Array[FigureEnums.Depth] = [
	FigureEnums.Depth.NEAR, FigureEnums.Depth.MID, FigureEnums.Depth.FAR
]
# PersonalityType.STATIC es el único activo por ahora — ver Vignette.gd.


# ======== Ritmo de aparición ========
@export var spawn_interval := 4.0
@export var initial_count := 8

var _time_since_last_spawn := 0.0
var _world_active := false
var _figure_manager: FigureManager
var vignette_container: Node


func _ready() -> void:
	set_process(false) 


func start_world(fm: FigureManager, container: Node) -> void:
	_figure_manager = fm
	vignette_container = container
	active_vignette.clear()
	_time_since_last_spawn = 0.0
	_world_active = true
	set_process(true)
	_spawn_initial_population()


func stop_world() -> void:
	_world_active = false
	set_process(false)
	for vig in active_vignette.duplicate():
		if is_instance_valid(vig):
			vig.queue_free()
	active_vignette.clear()


func _process(delta: float) -> void:
	_time_since_last_spawn += delta
	if _time_since_last_spawn >= spawn_interval:
		_time_since_last_spawn = 0.0
		_try_spawn_procedural()


func _spawn_initial_population() -> void:
	for i in range(initial_count):
		_spawn_at(_random_edge_biased_position(), false)



func _try_spawn_procedural() -> void:
	if active_vignette.size() >= vignette_limit:
		return
	_spawn_at(_find_least_defended_position(), true)


func _find_least_defended_position() -> Vector2:
	const CANDIDATES := 10
	var best_pos := Vector2.ZERO
	var best_score := -1.0
	for i in range(CANDIDATES):
		var candidate = _random_edge_biased_position()
		var score = _distance_to_nearest_bokeh(candidate)
		if score > best_score:
			best_score = score
			best_pos = candidate
	return best_pos

func _distance_to_nearest_bokeh(pos: Vector2) -> float:
	if _figure_manager == null or _figure_manager.active_figures.is_empty():
		return INF
	var nearest := INF
	for fig in _figure_manager.active_figures:
		if is_instance_valid(fig):
			nearest = min(nearest, pos.distance_to(fig.global_position))
	return nearest

func _random_edge_biased_position() -> Vector2:
	var screen = DisplayServer.window_get_size()
	var margin := 60.0
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(margin, screen.x - margin), randf_range(margin, screen.y * 0.25))
		1: return Vector2(randf_range(margin, screen.x - margin), randf_range(screen.y * 0.75, screen.y - margin))
		2: return Vector2(randf_range(margin, screen.x * 0.25), randf_range(margin, screen.y - margin))
		_: return Vector2(randf_range(screen.x * 0.75, screen.x - margin), randf_range(margin, screen.y - margin))


func _spawn_at(pos: Vector2, counts_as_spawn: bool, is_elite: bool = false) -> Node:
	if vignette_scene == null:
		push_warning("ShadowManager: vignette_scene is not assigned")
		return null

	var vig = vignette_scene.instantiate()
	var params = generate_params(pos)
	params["is_elite"] = is_elite
	vig.init(params)
	vignette_container.add_child(vig)

	if is_elite:
		_elite = vig
	else:
		active_vignette.append(vig)

	vig.tree_exiting.connect(_on_vignette_tree_exiting.bind(vig))

	if is_elite:
		emit_signal("elite_spawned", vig)
	else:
		emit_signal("vignette_spawned", vig, counts_as_spawn)
		EventBusAuto.emit_signal("vignette_spawned", vig, counts_as_spawn)
	return vig


func _on_vignette_tree_exiting(vig: Node) -> void:
	if vig.is_elite:
		_elite = null
		emit_signal("elite_defeated", vig)
	else:
		active_vignette.erase(vig)
		emit_signal("vignette_dispersed", vig)


func spawn_elite() -> void:
	if _elite != null:
		return
	_spawn_at(_find_stronghold_position(), true, true)

func _find_stronghold_position() -> Vector2:
	if _figure_manager == null or _figure_manager.active_figures.is_empty():
		return _random_edge_biased_position()  # caso raro: sin Bokeh vivos
	var target = _figure_manager.active_figures[randi() % _figure_manager.active_figures.size()]
	var offset = Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))
	return target.global_position + offset


func generate_params(position: Vector2) -> Dictionary:
	var size_category = get_random_size_category()
	return {
		"position": position,
		"depth": get_random_depth(),
		"noise_seed": randi(),
		"hardness": get_random_hardness(),
		"size_category": size_category,
		"size": get_scale_by_category(size_category),
	}


func get_random_hardness() -> VignetteEnums.Hardness:
	return all_hardness[randi() % all_hardness.size()]


func get_random_size_category() -> VignetteEnums.SizeCategory:
	return all_sizes[randi() % all_sizes.size()]

func get_random_depth() -> FigureEnums.Depth:
	return ALL_DEPTHS[randi() % ALL_DEPTHS.size()]

func get_scale_by_category(category: VignetteEnums.SizeCategory) -> float:
	match category:
		VignetteEnums.SizeCategory.SMALL: return randf_range(0.75, 0.9)
		VignetteEnums.SizeCategory.MEDIUM: return randf_range(0.9, 1.1)
		VignetteEnums.SizeCategory.LARGE: return randf_range(1.1, 1.3)
		_: return get_scale_by_category(get_random_size_category())



func get_active_count() -> int:
	return active_vignette.size()
