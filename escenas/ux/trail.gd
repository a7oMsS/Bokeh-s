extends Line2D
class_name CondenseTrail

# Mismo patrón que trail.gd original: lifetime + max_points + min_distance.
# Diferencia clave: ya no lee el mouse por su cuenta. CondenseRitual le
# manda puntos ya proyectados sobre el círculo ideal (add_trail_point),
# así que el resultado siempre es geométricamente un círculo, sin
# importar qué tan errático sea el gesto real del mouse.

@export var lifetime: float = 0.4
@export var min_distance: float = 6.0
@export var max_points: int = 8

# [posición_local, tiempo_restante] por cada punto activo
var _trail_data: Array = []


func _process(delta: float) -> void:
	if _trail_data.is_empty():
		return

	# Envejecer y filtrar puntos expirados (igual que el original)
	var active_data: Array = []
	for point_data in _trail_data:
		var remaining_time = point_data[1] - delta
		if remaining_time > 0:
			active_data.append([point_data[0], remaining_time])

	# Límite estricto de puntos, conservando los más recientes
	if active_data.size() > max_points:
		active_data = active_data.slice(active_data.size() - max_points)

	_trail_data = active_data

	clear_points()
	for point_data in _trail_data:
		add_point(point_data[0])


func add_point_at(local_pos: Vector2) -> void:
	if _trail_data.is_empty():
		_trail_data.append([local_pos, lifetime])
		return

	var last_pos: Vector2 = _trail_data[-1][0]
	if last_pos.distance_to(local_pos) >= min_distance:
		_trail_data.append([local_pos, lifetime])


func reset() -> void:
	_trail_data.clear()
	clear_points()
