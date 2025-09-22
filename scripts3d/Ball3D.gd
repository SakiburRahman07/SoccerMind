extends CharacterBody3D

var max_speed: float = 30.0
var friction: float = 0.98
var gravity: float = 24.0
var restitution: float = 0.4
var last_touch_team_a: bool = true

func _physics_process(delta: float) -> void:
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	# Apply gravity to enable lobbed passes
	velocity.y -= gravity * delta
	move_and_slide()
	# Basic floor bounce
	if global_transform.origin.y <= 0.6 and velocity.y < -0.01:
		velocity.y = -velocity.y * restitution
	# Horizontal friction
	var horiz: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * pow(friction, delta * 60.0)
	velocity.x = horiz.x
	velocity.z = horiz.z

func kick(direction: Vector3, force: float) -> void:
	velocity += direction.normalized() * clamp(force, 0.0, max_speed)


