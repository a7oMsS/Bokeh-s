extends Node
class_name Utils

static func is_node_visible(node, scroll: ScrollContainer) -> bool:
	var rect = node.get_global_rect()
	var view = scroll.get_global_rect()
	return rect.intersects(view)

static func _set_language_default():
	TranslationServer.set_locale(OS.get_locale_language())

## Base parameter set for a new figure. Shape/style/size/personality default
## to RANDOM; FigureManager.generate_params() resolves them before a Figure
## ever sees this dictionary.
static func default_config(position: Vector2) -> Dictionary:
	return {
		"shape": FigureEnums.Shape.RANDOM,
		"style": FigureEnums.Style.RANDOM,
		"color_a": Color.DODGER_BLUE,
		"color_b": Color.HOT_PINK,
		"size": FigureEnums.SizeCategory.RANDOM,
		"personality": FigureEnums.PersonalityType.RANDOM,
		"max_size": 120.0,
		"use_palette": false,
		"color_b_related": false,
		"position": position,
	}
