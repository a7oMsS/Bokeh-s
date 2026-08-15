# bounce.gd
extends FigurePersonality

var velocity: Vector2

func setup(_owner):
	super.setup(_owner)
	velocity = Vector2(randf_range(-200, 200), randf_range(-200, 200))

func _process(delta):
	owner.position += velocity * delta
	var rect = owner.get_viewport_rect()
	if owner.position.x < 0 or owner.position.x > rect.size.x:
		velocity.x *= -1
	if owner.position.y < 0 or owner.position.y > rect.size.y:
		velocity.y *= -1
