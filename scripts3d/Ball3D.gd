extends CharacterBody3D

var max_speed: float = 30.0
var friction: float = 0.98
var gravity: float = 24.0
var restitution: float = 0.4
var last_touch_team_a: bool = true
var still_time: float = 0.0
var unstick_threshold_speed: float = 0.05
var unstick_time: float = 1.0

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
	# Detect stall and gently nudge toward nearest player to prevent deadlocks
	var horiz_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var on_ground: bool = global_transform.origin.y <= 0.65 and abs(velocity.y) < 0.2
	if horiz_speed < unstick_threshold_speed and on_ground:
		still_time += delta
	else:
		still_time = 0.0
	if still_time > unstick_time:
		var nearest: Node = _nearest_player()
		if nearest:
			var dir: Vector3 = (nearest.global_transform.origin - global_transform.origin)
			dir.y = 0.0
			if dir.length() < 0.01:
				dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			velocity += dir.normalized() * 2.5
		still_time = 0.0

func kick(direction: Vector3, force: float) -> void:
	velocity += direction.normalized() * clamp(force, 0.0, max_speed)

func _nearest_player() -> Node:
	var a := get_tree().get_nodes_in_group("team_a")
	var b := get_tree().get_nodes_in_group("team_b")
	var all := a + b
	var best: Node = null
	var best_d: float = 1e9
	for p in all:
		var d: float = p.global_transform.origin.distance_to(global_transform.origin)
		if d < best_d:
			best_d = d
			best = p
	return best
