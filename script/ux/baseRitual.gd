extends Node2D
class_name BaseRitual

@warning_ignore("unused_signal")
signal finished(data: Dictionary)

var ritual_type := ""
var origin := Vector2.ZERO
var elapsed := 0.0
var entropy := 0.0
var result := "String"

@warning_ignore("shadowed_variable_base_class")
func begin(position: Vector2) -> void:
	origin = position
	elapsed = 0.0
	entropy = 0.0

func begin_from(other: BaseRitual) -> void:
	origin = other.origin
	elapsed = other.elapsed
	entropy = other.entropy
	position = other.position

func update(delta_elapsed: float, new_entropy: float) -> void:
	elapsed = delta_elapsed
	entropy = new_entropy

func resolve(_result: String) -> void:
	result = _result
