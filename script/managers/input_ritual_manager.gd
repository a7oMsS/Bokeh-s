extends Node
class_name InputRitualManager

signal condense_started(position: Vector2)
signal condense_held(position: Vector2, spin_ratio: float)
signal condense_resolved(position: Vector2, spin_ratio: float)
signal ritual_cancelled()

var is_pressing := false
var start_position := Vector2.ZERO
var last_position := Vector2.ZERO
var press_time := 0.0
var accumulated_rotation := 0.0

const MIN_HOLD_TIME := 0.25
const ROTATION_DEADZONE := 24.0
const ROTATION_FOR_MAX_BONUS := TAU * 2.0


func process_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_press(event.position)
		else:
			_end_press()
	elif event is InputEventMouseMotion and is_pressing:
		_update_motion(event.position)


func _start_press(pos: Vector2) -> void:
	is_pressing = true
	start_position = pos
	last_position = pos
	press_time = _now()
	accumulated_rotation = 0.0
	emit_signal("condense_started", pos)


func _update_motion(current_pos: Vector2) -> void:
	if current_pos.distance_to(start_position) > ROTATION_DEADZONE \
	and last_position.distance_to(start_position) > ROTATION_DEADZONE:
		var prev_vec = (last_position - start_position).normalized()
		var curr_vec = (current_pos - start_position).normalized()
		accumulated_rotation += abs(prev_vec.angle_to(curr_vec))

	last_position = current_pos

	var spin_ratio = clamp(accumulated_rotation / ROTATION_FOR_MAX_BONUS, 0.0, 1.0)
	emit_signal("condense_held", start_position, spin_ratio)


func _end_press() -> void:
	if not is_pressing:
		return

	var hold_duration = _now() - press_time
	is_pressing = false

	if hold_duration < MIN_HOLD_TIME:
		emit_signal("ritual_cancelled")
		return

	var spin_ratio = clamp(accumulated_rotation / ROTATION_FOR_MAX_BONUS, 0.0, 1.0)
	emit_signal("condense_resolved", start_position, spin_ratio)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001
