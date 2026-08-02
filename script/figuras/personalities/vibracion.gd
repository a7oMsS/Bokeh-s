# PersonalityVibracion.gd
extends FiguraPersonality

var original_position: Vector2
var time: float = 0.0
var amplitude: float = 4.0   # qué tanto se mueve
var frequency: float = 3.0  # qué tan rápido oscila

func setup(_owner):
	owner = _owner
	original_position = owner.position

func _process(delta):
	time += delta * frequency
	# Oscila en X y Y usando seno y coseno
	var offset = Vector2(sin(time), cos(time)) * amplitude
	owner.position = original_position + offset
