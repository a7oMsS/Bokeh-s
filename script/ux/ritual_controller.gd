extends Node
class_name RitualController

signal ritual_resolved(data: Dictionary)

var active_ritual: BaseRitual = null

@export var condense_ritual_scene: PackedScene

# ================================================================
# 1. INICIO — crear y conectar ritual
# ================================================================

func start_condense(position: Vector2) -> void:
	if active_ritual != null:
		return
	active_ritual = condense_ritual_scene.instantiate()
	get_tree().current_scene.add_child(active_ritual)
	active_ritual.finished.connect(_on_ritual_finished)
	active_ritual.begin(position)


# ================================================================
# 2. DURANTE EL GESTO — actualizar visuales
# ================================================================

func on_condense_held(spin_ratio: float, angle: float) -> void:
	if active_ritual and active_ritual.ritual_type == "condense":
		active_ritual.update(spin_ratio)
		active_ritual.add_trail_point(angle)


# ================================================================
# 3. RESOLUCIÓN — mandar señal para el spawn
# ================================================================

func on_condense_resolved(_position: Vector2, spin_ratio: float) -> void:
	if active_ritual and active_ritual.ritual_type == "condense":
		active_ritual.resolve(spin_ratio)


# ================================================================
# 4. CANCELACIÓN — mitigar ritual
# ================================================================

func on_ritual_cancelled() -> void:
	if active_ritual:
		active_ritual.cancel()


# ================================================================
# FIN DEL RITUAL (siempre, sea éxito o cancelado)
# ================================================================

func _on_ritual_finished(data: Dictionary) -> void:
	active_ritual = null
	emit_signal("ritual_resolved", data)
