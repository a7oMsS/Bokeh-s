extends Label

@export var normal_color: Color = Color(1, 1, 1, 1)
@export var gold_color: Color   = Color(1.0, 0.84, 0.0, 1)   # “oro”
@export var normal_scale: float = 1.0
@export var crit_scale: float   = 1.4
@export var gold_scale: float   = 1.2

@export var rise_speed: float = 50.0
@export var lifetime: float   = 1.0
@export var fade_time: float  = 0.4

# Arcoíris (críticos)
@export var rainbow_speed: float = 2.0   # vueltas de tono por segundo (aprox)

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
	
	# 3) Caso normal
	modulate = normal_color
	scale = Vector2.ONE * normal_scale

func show_text(_text: String, _color: Color, at_pos: Vector2) -> void:
	var message:String
	match _text:
		"perfect": message = "Perfecto +50%"
		"good": message = "Bien +20%"
		"none": message = "Fallaste"
	text = message
	position = at_pos
	_age = 0.0
	modulate = _color

func _process(delta: float) -> void:
	_age += delta
	position.y -= rise_speed * delta

	# Arcoíris activo: rotación de tono continua
	if _rainbow_active:
		_hue = fposmod(_hue + rainbow_speed * delta, 1.0)
		# Mantén el alpha actual en el fade-out
		var a := modulate.a
		modulate = Color.from_hsv(_hue, 1.0, 1.0, a)

	# Fade out al final
	if _age > lifetime - fade_time:
		var t := (_age - (lifetime - fade_time)) / fade_time
		modulate.a = lerp(1.0, 0.0, clamp(t, 0.0, 1.0))

	if _age >= lifetime:
		queue_free()
