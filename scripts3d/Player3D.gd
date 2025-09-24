extends CharacterBody3D

class_name Player3D

@export var is_team_a: bool = true
@export var role: String = "midfielder"
@export var grid_cell_size: float = 4.0

var ball: CharacterBody3D
var speed: float = 8.0
var ai: Node = null
var home_position: Vector3 = Vector3.ZERO

var current_grid: Vector2i
var target_grid: Vector2i

@export var field_half_width_x: float = 60.0
@export var field_half_height_z: float = 35.0

func setup(_ball: CharacterBody3D, _ai: Node) -> void:
	ball = _ball
	ai = _ai
	ai.set("player", self)
	ai.set("ball", ball)
	add_child(ai)
	# Initialize grid at current position
	current_grid = _world_to_grid(global_transform.origin)
	target_grid = current_grid

func set_home_position(pos: Vector3) -> void:
	home_position = pos

func _physics_process(_delta: float) -> void:
	if ai and ai.has_method("decide"):
		var d: Dictionary = ai.decide()
		if d.get("action", "") == "idle" and ball:
			# Avoid idle stalls: nudge toward ball
			var to_ball: Vector3 = ball.global_transform.origin - global_transform.origin
			to_ball.y = 0.0
			if to_ball.length() > 0.01:
				velocity = to_ball.normalized() * speed * 0.6
				move_and_slide()
		else:
			_apply_decision(d)
	# Keep player locked to pitch plane
	global_position.y = 1.0
	# Relaxed bounds to allow slight overlap near walls
	var margin: float = 0.3
	var clamped_x: float = clamp(global_position.x, -field_half_width_x + margin, field_half_width_x - margin)
	var clamped_z: float = clamp(global_position.z, -field_half_height_z + margin, field_half_height_z - margin)
	if clamped_x != global_position.x or clamped_z != global_position.z:
		global_position.x = clamped_x
		global_position.z = clamped_z

func _apply_decision(decision: Dictionary) -> void:
	var action: String = decision.get("action", "move")
	var to_ball: Vector3 = ball.global_transform.origin - global_transform.origin
	to_ball.y = 0.0
	# Boundary pursuit override: if ball near boundary, chase directly (ignore grid)
	if _is_ball_near_boundary(1.5):
		if to_ball.length() > 0.01:
			velocity = to_ball.normalized() * speed
			# Wall-hug nudge when extremely close and slow
			if to_ball.length() < 1.0 and velocity.length() < 0.2:
				velocity += _wall_hug_tangent() * 0.6
			move_and_slide()
			return
	if action == "move":
		var dir: Vector3 = decision.get("direction", Vector3.ZERO)
		# If close enough to the ball, move continuously toward it (ignore grid snap)
		if to_ball.length() < 6.0:
			var move_vec: Vector3 = to_ball
			move_vec.y = 0.0
			velocity = move_vec.normalized() * speed
			move_and_slide()
		else:
			# Grid-constrained movement toward desired direction
			if dir == Vector3.ZERO:
				dir = to_ball
			var step: Vector2i = _dir_to_grid_step(dir)
			var target_center: Vector3 = _grid_to_world(target_grid)
			var to_target: Vector3 = target_center - global_transform.origin
			to_target.y = 0.0
			if to_target.length() < 0.1:
				current_grid = target_grid
				if step != Vector2i.ZERO:
					target_grid = current_grid + step
					target_center = _grid_to_world(target_grid)
					to_target = target_center - global_transform.origin
					to_target.y = 0.0
			if to_target != Vector3.ZERO:
				velocity = to_target.normalized() * speed
			else:
				velocity = Vector3.ZERO
			move_and_slide()
	elif action == "kick":
		var default_target_x: float = (field_half_width_x - 2.0) if is_team_a else -(field_half_width_x - 2.0)
		var forward_from_ball: Vector3 = Vector3(default_target_x, 0.0, ball.global_transform.origin.z) - ball.global_transform.origin
		var dir: Vector3 = decision.get("direction", forward_from_ball)
		ball.kick(dir, decision.get("force", 15.0))
		# Record last touch team for restarts
		if ball.has_method("set"):
			ball.set("last_touch_team_a", is_team_a)
		velocity = Vector3.ZERO
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_and_slide()

func _world_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(round(pos.x / grid_cell_size), round(pos.z / grid_cell_size))

func _grid_to_world(g: Vector2i) -> Vector3:
	return Vector3(float(g.x) * grid_cell_size, global_transform.origin.y, float(g.y) * grid_cell_size)

func _dir_to_grid_step(dir: Vector3) -> Vector2i:
	var x_mag: float = abs(dir.x)
	var z_mag: float = abs(dir.z)
	if x_mag < 0.01 and z_mag < 0.01:
		return Vector2i.ZERO
	if x_mag >= z_mag:
		return Vector2i(1 if dir.x > 0.0 else -1, 0)
	else:
		return Vector2i(0, 1 if dir.z > 0.0 else -1)

func _is_ball_near_boundary(threshold: float) -> bool:
	var bx: float = ball.global_transform.origin.x
	var bz: float = ball.global_transform.origin.z
	return abs(bx) > (field_half_width_x - threshold) or abs(bz) > (field_half_height_z - threshold)

func _wall_hug_tangent() -> Vector3:
	# Compute a tangent direction along the nearest wall to help slide into corners
	var pos: Vector3 = global_transform.origin
	var dx_left: float = abs(-field_half_width_x - pos.x)
	var dx_right: float = abs(field_half_width_x - pos.x)
	var dz_top: float = abs(-field_half_height_z - pos.z)
	var dz_bottom: float = abs(field_half_height_z - pos.z)
	var min_d: float = min(min(dx_left, dx_right), min(dz_top, dz_bottom))
	if min_d == dx_left or min_d == dx_right:
		# Near vertical wall → move along Z
		return Vector3(0, 0, (ball.global_transform.origin.z - pos.z)).normalized()
	else:
		# Near horizontal wall → move along X
		return Vector3((ball.global_transform.origin.x - pos.x), 0, 0).normalized()
