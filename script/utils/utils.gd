extends Node
class_name Utils

static func is_node_visible(node, scroll: ScrollContainer) -> bool:
	var rect = node.get_global_rect()
	var view = scroll.get_global_rect()
	return rect.intersects(view)
	
static func _set_language_default():
	TranslationServer.set_locale(OS.get_locale_language())

static func defaultConfig(position):
		# Construcción de parametros
		return {
			"forma": "aleatorio",
			"estilo": "aleatorio",
			"color_a": Color.DODGER_BLUE,
			"color_b": Color.HOT_PINK,
			"tamano": "aleatorio",
			"personalidad": "aleatorio",
			"tamanoMaximo": 120.0,
			"usar_paleta": false,
			"color_b_relacionado": false,
			"posicion": position,
		}
