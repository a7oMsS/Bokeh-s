extends Label

@export var normal_color: Color = Color(1, 1, 1, 1)
@export var gold_color: Color = Color(1.0, 0.84, 0.0, 1)
@export var normal_scale: float = 1.0
@export var crit_scale: float = 1.4
@export var gold_scale: float = 1.2

@export var rise_speed: float = 50.0
@export var lifetime: float = 1.0
@export var fade_time: float = 0.4

@export var rainbow_speed: float = 2.0

var _age := 0.0
var _base_pos := Vector2.ZERO
var _rainbow_active := false
var _hue := 0.0


func show_value(value, at_pos: Vector2) -> void:
	if fmod(value, 1.0) == 0:
		value = int(value)
	text = "+" + str(value)
	position = at_pos
	_base_pos = at_pos

	modulate = normal_color
	scale = Vector2.ONE * normal_scale


func show_text(_text: String, _color: Color, at_pos: Vector2) -> void:
	var message: String
	match _text:
		"perfect": message = "Perfect +50%"
		"good": message = "Good +20%"
		"none": message = "Missed"
	text = message
	position = at_pos
	_age = 0.0
	modulate = _color


func _process(delta: float) -> void:
	_age += delta
	position.y -= rise_speed * delta

	if _rainbow_active:
		_hue = fposmod(_hue + rainbow_speed * delta, 1.0)
		var a := modulate.a
		modulate = Color.from_hsv(_hue, 1.0, 1.0, a)

	if _age > lifetime - fade_time:
		var t := (_age - (lifetime - fade_time)) / fade_time
		modulate.a = lerp(1.0, 0.0, clamp(t, 0.0, 1.0))

	if _age >= lifetime:
		queue_free()
