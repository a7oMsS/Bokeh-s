extends Node
class_name InputRitualManager

# Señales
signal condense_started(position: Vector2)
signal condense_held(position: Vector2, circular_progress: float, stability: float)
signal condense_pushed(position: Vector2)

signal ritual_cancelled()

# Estados
var is_pressing := false
var is_trace := false
var start_position := Vector2.ZERO
var last_position := Vector2.ZERO
var press_time := 0.0
var circular_accumulator := 0.0
var stability := 1.0

const MIN_CIRCLE_RADIUS := 30.0
const MAX_CIRCLE_RADIUS := 120.0
const MIN_TRACE_DISTANCE := 80.0

func process_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_press(event.position)
		else:
			_end_press(event.position)
	
	elif event is InputEventMouseMotion and is_pressing:
		_update_motion(event.position, event.relative)

func _start_press(pos: Vector2):
	is_pressing = true
	start_position = pos
	last_position = pos
	press_time = Time.get_ticks_msec() * 0.001
	circular_accumulator = 0.0
	stability = 1.0
	is_trace = false

	# Doble clic = Trace
	if _is_double_click():
		is_trace = true
		emit_signal("trace_started", pos)
	else:
		emit_signal("condense_started", pos)

func _update_motion(current_pos: Vector2, relative: Vector2):
	var _delta_time = (Time.get_ticks_msec() * 0.001) - press_time
	
	if is_trace:
		var distance = current_pos.distance_to(start_position)
		var progress = clamp(distance / 700.0, 0.0, 1.0)
		var _speed = relative.length()
		var resistance = lerp(0.9, 0.3, progress)  # resistencia alta al principio
		
		emit_signal("trace_dragging", current_pos, progress, resistance)
		
	else:  # Condense - Micro movimientos circulares
		var center = start_position
		var dist_from_center = current_pos.distance_to(center)
		
		if dist_from_center > MIN_CIRCLE_RADIUS:
			# 1. Calcular vectores desde el centro
			var prev_vec = (last_position - center).normalized()
			var curr_vec = (current_pos - center).normalized()
			
			# 2. Obtener la diferencia de ángulo (en radianes)
			var angle_delta = prev_vec.angle_to(curr_vec)
			
			# 3. Acumular (usamos abs para que cuente giro en cualquier sentido)
			circular_accumulator += abs(angle_delta)
			
			# Estabilidad: penaliza si se aleja demasiado del radio óptimo
			var ideal_radius = (MAX_CIRCLE_RADIUS + MIN_CIRCLE_RADIUS) / 2.0
			var dist_error = abs(dist_from_center - ideal_radius) / MAX_CIRCLE_RADIUS
			stability = lerp(stability, clamp(1.0 - dist_error, 0.0, 1.0), 0.1)
			
			emit_signal("condense_held", center, circular_accumulator, stability)
	
	last_position = current_pos # Crucial para el próximo cálculo de ángu

func _end_press(end_pos: Vector2):
	if not is_pressing:
		return
	
	var _duration = (Time.get_ticks_msec() * 0.001) - press_time
	
	if is_trace:
		var quality = _calculate_trace_quality(end_pos)
		emit_signal("trace_finished", end_pos, quality)
	else:
		# Detectar empujón final
		var push_vector = (end_pos - start_position)
		if push_vector.length() > 35.0:
			emit_signal("condense_pushed", end_pos)
		else:
			emit_signal("ritual_cancelled")
	
	is_pressing = false
	is_trace = false

# Helper para doble clic
var last_click_time := 0.0
func _is_double_click() -> bool:
	var now = Time.get_ticks_msec() * 0.001
	var is_double = (now - last_click_time) < 0.32
	last_click_time = now
	return is_double

func _calculate_trace_quality(end_pos: Vector2) -> float:
	var distance = start_position.distance_to(end_pos)
	return clamp(distance / 650.0, 0.0, 1.0)
