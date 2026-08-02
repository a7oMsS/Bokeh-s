extends Line2D

# Número máximo de puntos que mantendrá el rastro
@export var max_points: int = 10
# Distancia mínima en píxeles antes de agregar un nuevo punto (evita puntos duplicados)
@export var min_distance: float = 5.0


func _process(_delta: float) -> void:
	# Comprobar si el botón izquierdo del mouse se mantiene presionado
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = get_global_mouse_position()
		
		# Solo añade un punto si el mouse se ha movido lo suficiente
		if get_point_count() == 0 or mouse_pos.distance_to(points[get_point_count() - 1]) > min_distance:
			add_point(mouse_pos)
		
		# Limita la cantidad de puntos almacenados
		while get_point_count() > max_points:
			remove_point(0)
	else:
		# Si se suelta el clic, se van borrando los puntos progresivamente hasta desaparecer
		if get_point_count() > 0:
			remove_point(0)
