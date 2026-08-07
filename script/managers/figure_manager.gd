extends Node
class_name FigureManager

@onready var figure_scene = preload("res://scenes/objects/figure.tscn")

var active_figures: Array = []
var figure_limit := 40
signal figure_spawned(fig: Node)


# ======== Full catalog ========
var all_shapes: Array[FigureEnums.Shape] = [
	FigureEnums.Shape.CIRCLE, FigureEnums.Shape.SQUARE, FigureEnums.Shape.TRIANGLE,
	FigureEnums.Shape.STAR5, FigureEnums.Shape.STAR4, FigureEnums.Shape.HEXAGON,
	FigureEnums.Shape.RHOMBUS, FigureEnums.Shape.HEART,
]
var all_styles: Array[FigureEnums.Style] = [
	FigureEnums.Style.SOLID, FigureEnums.Style.GRADIENT,
	FigureEnums.Style.OUTLINE, FigureEnums.Style.OUTLINE_GRADIENT,
]
var all_sizes: Array[FigureEnums.SizeCategory] = [
	FigureEnums.SizeCategory.SMALL, FigureEnums.SizeCategory.MEDIUM, FigureEnums.SizeCategory.LARGE,
]
var all_personalities: Array[FigureEnums.PersonalityType] = [
	FigureEnums.PersonalityType.STATIC, FigureEnums.PersonalityType.BOUNCE,
	FigureEnums.PersonalityType.BLINK, FigureEnums.PersonalityType.VIBRATION,
	FigureEnums.PersonalityType.COLOR_SHIFT,
]

# ======== Unlocked subset ========
var shapes: Array[FigureEnums.Shape] = [FigureEnums.Shape.CIRCLE]
var styles: Array[FigureEnums.Style] = [FigureEnums.Style.SOLID]
var sizes: Array[FigureEnums.SizeCategory] = [FigureEnums.SizeCategory.LARGE]
var personalities: Array[FigureEnums.PersonalityType] = [
	FigureEnums.PersonalityType.VIBRATION, FigureEnums.PersonalityType.COLOR_SHIFT, FigureEnums.PersonalityType.BOUNCE
]

# ======== Gesture-quality bonuses (spin_ratio, 0-1) ========
const QUALITY_SIZE_BONUS_MAX := 0.35
const QUALITY_BRIGHTEN_MAX := 0.25

# ======== Depth drift ========
const DEPTH_FOCUS_CHANCE_MIN := 0.33
const DEPTH_FOCUS_CHANCE_MAX := 0.66
const DEPTH_HOLD_MIN := 1.5
const DEPTH_HOLD_MAX := 4.0
const DEPTH_DRIFT_MIN := 3.0
const DEPTH_DRIFT_MAX := 6.0


# ---------------- Unlock methods ----------------
func enable_shape(shape: FigureEnums.Shape) -> void:
	if all_shapes.has(shape) and not shapes.has(shape):
		shapes.append(shape)

func enable_style(style: FigureEnums.Style) -> void:
	if all_styles.has(style) and not styles.has(style):
		styles.append(style)

func enable_personality(personality: FigureEnums.PersonalityType) -> void:
	if all_personalities.has(personality) and not personalities.has(personality):
		personalities.append(personality)

func enable_size(size: FigureEnums.SizeCategory) -> void:
	if all_sizes.has(size) and not sizes.has(size):
		sizes.append(size)

# ---------------- Getters ----------------
func get_random_shape() -> FigureEnums.Shape:
	return shapes[randi() % shapes.size()]

func get_random_style() -> FigureEnums.Style:
	return styles[randi() % styles.size()]

func get_random_personality() -> FigureEnums.PersonalityType:
	return personalities[randi() % personalities.size()]

func get_available_shapes() -> Array:
	return shapes

func get_available_styles() -> Array:
	return styles

func get_available_sizes() -> Array:
	return sizes

func get_available_personalities() -> Array:
	return personalities

## Triadic harmony (gold / cyan / magenta) at 60/30/10.
func get_random_color() -> Color:
	var hue_gold := 60.0 / 360.0
	var hue_cyan := 180.0 / 360.0
	var hue_magenta := 300.0 / 360.0

	var roll = randf()
	var hue: float
	if roll < 0.6:
		hue = hue_gold
	elif roll < 0.9:
		hue = hue_cyan
	else:
		hue = hue_magenta

	var saturation = randf_range(0.5, 1.0)
	var value = randf_range(0.5, 1.0)
	return Color.from_hsv(hue, saturation, value)

func get_similar_color(base_color: Color) -> Color:
	var h = base_color.h
	var s = base_color.s
	var v = base_color.v
	h = wrapf(h + randf_range(-0.1, 0.1), 0, 2.0)
	s = clamp(s + randf_range(-0.1, 0.1), 0.05, 2.0)
	v = clamp(v + randf_range(-0.4, 0.4), 0.05, 1.2)
	return Color.from_hsv(h, s, v, base_color.a)

func get_random_size() -> float:
	var probability = randi_range(0, 99)
	if probability < 10:
		return get_size_by_category(FigureEnums.SizeCategory.LARGE)
	elif probability < 65:
		return get_size_by_category(FigureEnums.SizeCategory.MEDIUM)
	else:
		return get_size_by_category(FigureEnums.SizeCategory.SMALL)

func get_max_size() -> float:
	var screen = DisplayServer.window_get_size()
	var reference = min(screen.x, screen.y)
	return reference * 0.35

func get_size_by_category(category: FigureEnums.SizeCategory) -> float:
	var screen = DisplayServer.window_get_size()
	var reference = min(screen.x, screen.y)

	match category:
		FigureEnums.SizeCategory.SMALL:
			return randf_range(reference * 0.075, reference * 0.10)
		FigureEnums.SizeCategory.MEDIUM:
			return randf_range(reference * 0.14, reference * 0.18)
		FigureEnums.SizeCategory.LARGE:
			return randf_range(reference * 0.25, reference * 0.35)
		_:
			return get_random_size()

# ---------------- Depth drift ----------------

## Higher quality biases toward staying in focus (Mid); on a miss, Near
## and Far are equally likely.
func get_depth_target(quality: float) -> FigureEnums.Depth:
	var focus_chance = lerp(DEPTH_FOCUS_CHANCE_MIN, DEPTH_FOCUS_CHANCE_MAX, quality)
	if randf() < focus_chance:
		return FigureEnums.Depth.MID
	return FigureEnums.Depth.NEAR if randf() < 0.5 else FigureEnums.Depth.FAR


func generate_params(config: Dictionary, quality: float = 0.1) -> Dictionary:
	var shape = config.shape
	if shape == FigureEnums.Shape.RANDOM:
		shape = get_random_shape()

	var style = config.style
	if style == FigureEnums.Style.RANDOM:
		style = get_random_style()

	var size_category = config.size
	var size_px: float
	if size_category == FigureEnums.SizeCategory.RANDOM:
		size_px = get_random_size()
	else:
		size_px = get_size_by_category(size_category)

	size_px *= 1.0 + (quality * QUALITY_SIZE_BONUS_MAX)

	var personality = config.personality
	if personality == FigureEnums.PersonalityType.RANDOM:
		personality = get_random_personality()

	var color_a = config.color_a
	var color_b = config.color_b

	if config.use_palette:
		if config.color_b_related:
			color_b = get_similar_color(color_a)
			color_a = get_similar_color(color_a)
		else:
			color_a = get_similar_color(color_a)
			color_b = get_random_color()
	else:
		if config.color_b_related:
			color_a = get_random_color()
			color_b = get_similar_color(color_a)
		else:
			color_a = get_random_color()
			color_b = get_random_color()

	color_a = color_a.lightened(quality * QUALITY_BRIGHTEN_MAX)
	color_b = color_b.lightened(quality * QUALITY_BRIGHTEN_MAX)

	var depth_target = get_depth_target(quality)
	var depth_hold = lerp(DEPTH_HOLD_MIN, DEPTH_HOLD_MAX, quality)
	var depth_drift_duration = randf_range(DEPTH_DRIFT_MIN, DEPTH_DRIFT_MAX)

	return {
		"shape": shape,
		"style": style,
		"color_a": color_a,
		"color_b": color_b,
		"size": size_px,
		"personality": personality,
		"max_size": get_max_size(),
		"depth": FigureEnums.Depth.MID,
		"depth_target": depth_target,
		"depth_hold": depth_hold,
		"depth_drift_duration": depth_drift_duration,
		"quality": quality,
		"position": config.position,
	}

var figures_container

func _ready():
	figures_container = $"../../ClicArea/FiguresLayer"

func on_invoke(type: String, data: Dictionary):
	match type:
		RitualConstants.TYPE_CONDENSE:
			spawn_random(data.position, data.get("quality", 0.0))

func spawn_random(position: Vector2, quality: float = 0.0) -> Node:
	if active_figures.size() >= figure_limit:
		_despawn_oldest()

	var fig = figure_scene.instantiate()
	var params = generate_params(Utils.default_config(position), quality)

	fig.init(params)
	figures_container.add_child(fig)
	active_figures.append(fig)
	fig.tree_exiting.connect(_on_figure_tree_exiting.bind(fig))

	emit_signal("figure_spawned", fig)
	EventBusAuto.emit_signal("figure_spawned", fig)
	return fig

func _on_figure_tree_exiting(fig: Node) -> void:
	active_figures.erase(fig)

func _despawn_oldest() -> void:
	if active_figures.is_empty():
		return
	var oldest = active_figures.pop_front()
	if is_instance_valid(oldest):
		oldest.disappear_fast()
