extends CharacterBody2D

var max_speed: float = 600.0
var friction: float = 0.98

func _physics_process(delta: float) -> void:
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	move_and_slide()
	velocity *= pow(friction, delta * 60.0)

func kick(direction: Vector2, force: float) -> void:
	velocity += direction.normalized() * clamp(force, 0.0, max_speed)


