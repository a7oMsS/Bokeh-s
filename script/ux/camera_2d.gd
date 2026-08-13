extends Camera2D

var target_zoom := Vector2(1.0, 1.0)
var zoom_velocity := Vector2.ZERO
@export var random_shake_strength: float = 30.0
@export var shake_decay_rate: float = 5.0
@export var zoom_hold_speed: float = 0.1
@export var max_zoom: float = 1.3
@onready var rand = RandomNumberGenerator.new()
var shake_strength: float = 0.0
var is_holding := false


func get_random_offset() -> Vector2:
	return Vector2(
		rand.randf_range(-shake_strength, shake_strength),
		rand.randf_range(-shake_strength, shake_strength)
	)


func _ready() -> void:
	get_window().size_changed.connect(_on_window_resize)
	position_smoothing_enabled = false
	rand.randomize()
	_on_window_resize()


func _on_window_resize():
	@warning_ignore("integer_division")
	position = DisplayServer.window_get_size() / 2


func _process(delta):
	var stiffness = 40.0
	var damping = 0.8

	if is_holding:
		var increment = zoom_hold_speed * delta
		target_zoom += Vector2(increment, increment)
		target_zoom = target_zoom.min(Vector2(max_zoom, max_zoom))

	var force = (target_zoom - zoom) * stiffness
	zoom_velocity += force * delta
	zoom_velocity *= damping
	zoom += zoom_velocity * delta

	shake_strength = lerp(shake_strength, 0.0, shake_decay_rate * delta)
	offset = get_random_offset()


func process_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_holding = true
		else:
			is_holding = false
			zoom_reset()


func zoom_reset():
	target_zoom = Vector2(1.0, 1.0)


func do_condensation_shake(_level: int):
	shake_strength = random_shake_strength
