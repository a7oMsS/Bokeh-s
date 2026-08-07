extends Node
class_name RitualController

signal ritual_resolved(data: Dictionary)

var active_ritual: BaseRitual = null

@export var condense_ritual_scene: PackedScene


func start_condense(position: Vector2) -> void:
	if active_ritual != null:
		return
	active_ritual = condense_ritual_scene.instantiate()
	get_tree().current_scene.add_child(active_ritual)
	active_ritual.finished.connect(_on_ritual_finished)
	active_ritual.begin(position)


func on_condense_held(spin_ratio: float, angle: float) -> void:
	if active_ritual and active_ritual.ritual_type == RitualConstants.TYPE_CONDENSE:
		active_ritual.update(spin_ratio)
		active_ritual.add_trail_point(angle)


func on_condense_resolved(_position: Vector2, spin_ratio: float) -> void:
	if active_ritual and active_ritual.ritual_type == RitualConstants.TYPE_CONDENSE:
		active_ritual.resolve(spin_ratio)


func on_ritual_cancelled() -> void:
	if active_ritual:
		active_ritual.cancel()


func _on_ritual_finished(data: Dictionary) -> void:
	active_ritual = null
	emit_signal("ritual_resolved", data)
