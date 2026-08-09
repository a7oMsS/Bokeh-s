extends PanelContainer
class_name MasteryToast

## Toast de subida de nivel. Se autoconecta a EventBusAuto.level_up en su
## propio _ready(), igual que MasteryManager se conecta a
## EventBusAuto.vignette_dispersed — no necesita wiring desde main.gd.
##
## Evento raro (máximo 3 veces en todo el demo) — a diferencia del anillo
## de energía, aquí sí vale la pena un hold largo y una entrada con "pop".

@onready var message: Label = $HBoxContainer/PanelContainer2/MarginContainer2/Message
@onready var message_mc: MarginContainer = $HBoxContainer/PanelContainer2/MarginContainer2
@onready var icon_container: PanelContainer = $HBoxContainer/PanelContainer

const LEFT_MARGIN := 30.0
const TOP_MARGIN := 40.0

const POP_IN_TIME := 0.25
const HOLD_TIME := 3.5
const FADE_OUT_TIME := 0.5

var _tween: Tween
var sb_icon: StyleBoxFlat

func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2.ZERO
	
	message_mc.add_theme_constant_override("margin_left",0)
	message_mc.add_theme_constant_override("margin_right",0)
	
	sb_icon = icon_container.get_theme_stylebox("panel").duplicate()
	icon_container.add_theme_stylebox_override("panel", sb_icon)
	
	EventBusAuto.level_up.connect(_on_level_up)

func _on_level_up(_level: int, unlock_name: String) -> void:
	message.text = ""
	
	position = Vector2(
		-LEFT_MARGIN,
		TOP_MARGIN
	)
	
	pivot_offset = size * 0.5

	if _tween and _tween.is_valid():
		_tween.kill()

	scale = Vector2.ZERO
	modulate.a = 0.0
	
	sb_icon.corner_radius_top_right = 20
	sb_icon.corner_radius_bottom_right = 20
	
	message_mc.add_theme_constant_override("margin_left",0)
	message_mc.add_theme_constant_override("margin_right",0)
	
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, POP_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position", Vector2(LEFT_MARGIN,TOP_MARGIN), POP_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, POP_IN_TIME)
	_tween.tween_interval(0.25)	
	
	_tween.tween_property(sb_icon, "corner_radius_top_right", 0, 0.1)
	_tween.parallel().tween_property(sb_icon, "corner_radius_bottom_right", 0, 0.1)
	_tween.tween_property(message_mc, "theme_override_constants/margin_left", 20, 0.1)
	_tween.parallel().tween_property(message_mc, "theme_override_constants/margin_right", 20, 0.1)
	_tween.tween_property(message, "text", unlock_name, 0.5)
	
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	
