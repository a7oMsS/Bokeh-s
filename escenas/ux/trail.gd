extends Line2D

# Tiempo en segundos que dura cada parte del rastro
@export var lifetime: float = 0.3
@export var min_distance: float = 10.0
@export var max_points: int = 10

# Lista para guardar los datos de cada punto: [posición, tiempo_restante]
var trail_data: Array = []

func _process(delta: float) -> void:
	# 1. Obtener la posición actual del mouse
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var current_pos = get_global_mouse_position()
		
		# 2. Agregar el nuevo punto a nuestra lista interna si el mouse se mueve
		if trail_data.is_empty():
			trail_data.append([current_pos, lifetime])
		else:
			var last_pos = trail_data[-1][0]
			if last_pos.distance_to(current_pos) >= min_distance:
				trail_data.append([current_pos, lifetime])
		
		# 3. Actualizar el tiempo de vida de los puntos y filtrar los que expiraron
		var active_data: Array = []
		for point_data in trail_data:
			var remaining_time = point_data[1] - delta
			if remaining_time > 0:
				active_data.append([point_data[0], remaining_time])
				
		trail_data = active_data
		
		# 3. Limitar estrictamente a un máximo de 10 puntos (mantiene los más recientes)
		if active_data.size() > max_points:
			active_data = active_data.slice(active_data.size() - max_points)
		
		trail_data = active_data
		
		# 4. Redibujar la Line2D con las posiciones actualizadas
		clear_points()
		for point_data in trail_data:
			add_point(point_data[0])
		
	else:
		if get_point_count() > 0:
			remove_point(0)
		else:
			trail_data.clear()
