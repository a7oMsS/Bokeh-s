extends Node
class_name InputRitualManager

signal condense_started(position: Vector2)
signal condense_held(spin_ratio: float, angle: float)
signal condense_resolved(position: Vector2, spin_ratio: float)
signal ritual_cancelled()

var is_pressing := false
var start_position := Vector2.ZERO
var press_time := 0.0
var accumulated_rotation := 0.0

var _last_angle := 0.0
var _has_last_angle := false

const MIN_HOLD_TIME := 0.5

## Only gesture movement inside this ring counts. Leaving it cancels the ritual.
const MIN_RADIUS := 20.0
const MAX_RADIUS := 300.0

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
	press_time = _now()
	accumulated_rotation = 0.0
	_has_last_angle = false
	emit_signal("condense_started", pos)


func _update_motion(current_pos: Vector2) -> void:
	var offset = current_pos - start_position
	var distance = offset.length()

	if distance > MAX_RADIUS:
		_cancel_out_of_bounds()
		return

	## No rotation is accumulated inside the dead zone — near the center,
	## tiny mouse jitter produces huge angle swings.
	if distance <= MIN_RADIUS:
		_has_last_angle = false
		return

	var current_angle = offset.angle()

	if _has_last_angle:
		## Signed delta: if the player moves back and forth, the angle
		## oscillates between two values and the reversals cancel out.
		## Only consistent rotation in one direction accumulates net spin.
		var delta_angle = wrapf(current_angle - _last_angle, -PI, PI)
		accumulated_rotation += delta_angle

	_last_angle = current_angle
	_has_last_angle = true

	var spin_ratio = clamp(abs(accumulated_rotation) / ROTATION_FOR_MAX_BONUS, 0.0, 1.0)
	emit_signal("condense_held", spin_ratio, current_angle)


func _cancel_out_of_bounds() -> void:
	if not is_pressing:
		return
	is_pressing = false
	emit_signal("ritual_cancelled")


func _end_press() -> void:
	if not is_pressing:
		return

	var hold_duration = _now() - press_time
	is_pressing = false

	if hold_duration < MIN_HOLD_TIME:
		emit_signal("ritual_cancelled")
		return

	var spin_ratio = clamp(abs(accumulated_rotation) / ROTATION_FOR_MAX_BONUS, 0.1, 1.0)
	emit_signal("condense_resolved", start_position, spin_ratio)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001
