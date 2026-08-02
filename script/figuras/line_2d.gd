extends Line2D

@export var max_points = 20;
@export var min_point_distance: float = 5.0;
var last_point_position = Vector2.ZERO

func _ready() -> void:
	last_point_position = get_parent().global_position
	global_position = Vector2.ZERO
	global_rotation = 0.0
	set_process(false)
	
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	global_position = Vector2.ZERO
	global_rotation = 0.0
	var current_position = get_parent().global_position
	
	if last_point_position.distance_to(current_position) >= min_point_distance: 
		add_point(current_position)
		last_point_position = current_position
	
	while get_point_count() > max_points:
		remove_point(0)
