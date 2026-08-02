extends CanvasLayer

# Referencias

# Recursos precargados
var FloatingText = preload("res://escenas/ui/FloatingText.tscn")

# variables globales
var viewport_size: Vector2
var expanded := false

# --------------------------------------
# Eventos de GUI
# --------------------------------------
func show_floating_text(points: float):
	var ft := FloatingText.instantiate() 
	add_child(ft) 
	ft.show_value(points, get_viewport().get_mouse_position())
	
