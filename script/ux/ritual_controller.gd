extends Node
class_name RitualController

signal ritual_resolved(data: Dictionary)

var active_ritual: BaseRitual = null

@export var condense_ritual_scene: PackedScene = preload("res://escenas/ux/condesation_fx.tscn")

# ================================================================
# INICIO DE RITUALES (llamados desde InputRitualManager)
# ================================================================

func start_condense(position: Vector2) -> void:
	if active_ritual != null:
		return
	active_ritual = condense_ritual_scene.instantiate()
	get_tree().current_scene.add_child(active_ritual)
	active_ritual.finished.connect(_on_ritual_finished)
	active_ritual.begin(position)


# ================================================================
# UPDATE DURANTE EL GESTO
# ================================================================

func on_condense_held(_position: Vector2, circular_progress: float, stability: float) -> void:
	if active_ritual and active_ritual.ritual_type == "condense":
		active_ritual.update(circular_progress, stability)

# ================================================================
# GESTO FINAL / EMPUJÓN
# ================================================================

func on_condense_pushed(_position: Vector2) -> void:
	if active_ritual and active_ritual.ritual_type == "condense":
		active_ritual.push_final()  


# ================================================================
# CANCELACIÓN
# ================================================================

func on_ritual_cancelled() -> void:
	if active_ritual:
		active_ritual.resolve("cancel")


# ================================================================
# FIN DEL RITUAL
# ================================================================

func _on_ritual_finished(data: Dictionary) -> void:
	active_ritual = null
	emit_signal("ritual_resolved", data)
