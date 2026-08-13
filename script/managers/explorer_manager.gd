extends Node
class_name ExplorerManager

# -------------------------------------------------
# Parámetros base
# -------------------------------------------------
@export var regen_rate := 0.06        # energía por segundo
@export var soft_cap := 1.0           # referencia, no límite duro
@export var min_energy := 0.0

# -------------------------------------------------
# Estado interno
# -------------------------------------------------
var energy := 1.0
var reserved := 0.0

# -------------------------------------------------
# Proceso
# -------------------------------------------------
func _ready():
	set_process(true)
	add_to_group("saveable_player")

func _process(delta: float) -> void:
	_regenerate(delta)


func _regenerate(delta: float) -> void:
	if energy < soft_cap:
		energy += regen_rate * delta
		energy = min(energy, soft_cap)


# -------------------------------------------------
# API pública
# -------------------------------------------------

func can_afford(amount: float) -> bool:
	return energy - reserved >= amount


func reserve(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var available = max(energy - reserved, 0.0)
	var taken = min(amount, available)

	reserved += taken
	return taken


func release(amount: float) -> void:
	if amount <= 0.0:
		return

	reserved -= amount
	reserved = max(reserved, 0.0)


func consume(amount: float) -> void:
	if amount <= 0.0:
		return

	energy -= amount
	energy = max(energy, min_energy)


# -------------------------------------------------
# Información útil (lectura)
# -------------------------------------------------
func energy_ratio() -> float:
	return clamp(energy / soft_cap, 0.0, 1.0)


func available_energy() -> float:
	return max(energy - reserved, 0.0)


# -------------------------------------------------
# Guardado
# -------------------------------------------------
func get_save_data() -> Dictionary:
	return {"energy": energy}


func load_save_data(data: Dictionary) -> void:
	energy = data.get("energy", energy)
