extends Node
class_name FiguraPersonality

var velocity: Vector2

func setup(_owner):
	owner = _owner
	velocity = Vector2(randf_range(-30,30), randf_range(-30,30))

func _process(delta):
	owner.position += velocity * delta
	var rect = owner.get_viewport_rect()
	if owner.position.x < 0 or owner.position.x > rect.size.x:
		velocity.x *= -1
	if owner.position.y < 0 or owner.position.y > rect.size.y:
		velocity.y *= -1
