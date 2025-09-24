extends CharacterBody3D

class_name Player3D

@export var is_team_a: bool = true
@export var role: String = "midfielder"
@export var grid_cell_size: float = 4.0

var ball: CharacterBody3D
var speed: float = 9.5
var ai: Node = null
var home_position: Vector3 = Vector3.ZERO

# Optional per-player grid bounds (assigned by team manager)
var grid_bounds_enabled: bool = false
var grid_min_x: float = 0.0
var grid_max_x: float = 0.0
var grid_min_z: float = 0.0
var grid_max_z: float = 0.0
var grid_center: Vector3 = Vector3.ZERO

# Staging flow: start off-grid then run to assigned grid on kickoff
var is_staging: bool = false
var staging_target: Vector3 = Vector3.ZERO
var staging_timeout: float = 0.0
var max_staging_time: float = 5.0  # Max 5 seconds in staging mode

var current_grid: Vector2i
var target_grid: Vector2i

# Emergency recovery system
var idle_time: float = 0.0
var max_idle_time: float = 3.0
var last_position: Vector3 = Vector3.ZERO
var position_check_timer: float = 0.0

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

func set_grid_bounds(min_x: float, max_x: float, min_z: float, max_z: float, center: Vector3) -> void:
	grid_bounds_enabled = true
	grid_min_x = min_x
	grid_max_x = max_x
	grid_min_z = min_z
	grid_max_z = max_z
	grid_center = center

func set_staging_target(target: Vector3) -> void:
	is_staging = true
	staging_target = target

func _physics_process(_delta: float) -> void:
	# Handle staging first with timeout protection
	if is_staging:
		staging_timeout += _delta
		# Force exit staging after timeout
		if staging_timeout > max_staging_time:
			is_staging = false
			staging_timeout = 0.0
			print("Player forced out of staging mode due to timeout")
		else:
			var to_target: Vector3 = staging_target - global_transform.origin
			to_target.y = 0.0
			if to_target.length() > 0.05:
				velocity = to_target.normalized() * speed
				move_and_slide()
			else:
				is_staging = false
				staging_timeout = 0.0
				velocity = Vector3.ZERO
				move_and_slide()
		return
	# Emergency recovery system - track idle time and position
	position_check_timer += _delta
	if position_check_timer >= 1.0:  # Check every second
		var current_pos = global_transform.origin
		if current_pos.distance_to(last_position) < 0.5:  # Haven't moved much
			idle_time += position_check_timer
		else:
			idle_time = 0.0
		last_position = current_pos
		position_check_timer = 0.0
	
	# Force emergency action if idle too long
	if idle_time > max_idle_time and ball:
		print("Emergency recovery for player - forcing ball pursuit")
		var to_ball: Vector3 = ball.global_transform.origin - global_transform.origin
		to_ball.y = 0.0
		if to_ball.length() > 0.01:
			velocity = to_ball.normalized() * speed
			move_and_slide()
		idle_time = 0.0
		return
	
	if ai and ai.has_method("decide"):
		var d: Dictionary = ai.decide()
		# Grid-aware tactics have priority when the ball is inside this player's grid
		if _apply_grid_tactics_if_applicable():
			# Movement/act handled by grid tactics
			pass
		if d.get("action", "") == "idle" and ball:
			# Robust ball pursuit: actively chase the ball when idle
			var to_ball: Vector3 = ball.global_transform.origin - global_transform.origin
			to_ball.y = 0.0
			if to_ball.length() > 0.01:
				# Use full speed for ball pursuit instead of reduced speed
				velocity = to_ball.normalized() * speed
				move_and_slide()
		elif d.get("action", "") == "move" or d.get("action", "") == "kick":
			_apply_decision(d)
		else:
			# Fallback: if no valid action, pursue the ball
			if ball:
				var to_ball: Vector3 = ball.global_transform.origin - global_transform.origin
				to_ball.y = 0.0
				if to_ball.length() > 0.01:
					velocity = to_ball.normalized() * speed * 0.8
					move_and_slide()
	# Keep player locked to pitch plane
	global_position.y = 1.0
	# Relaxed bounds to allow slight overlap near walls
	var margin: float = 0.3
	var clamped_x: float = clamp(global_position.x, -field_half_width_x + margin, field_half_width_x - margin)
	var clamped_z: float = clamp(global_position.z, -field_half_height_z + margin, field_half_height_z - margin)
	# Soft grid bounds - only apply when not chasing ball actively
	if grid_bounds_enabled and ball:
		var dist_to_ball = global_transform.origin.distance_to(ball.global_transform.origin)
		# Only enforce grid bounds if ball is far away (not actively pursuing)
		if dist_to_ball > 10.0:
			clamped_x = clamp(clamped_x, grid_min_x, grid_max_x)
			clamped_z = clamp(clamped_z, grid_min_z, grid_max_z)
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
			var mult: float = 1.0
			if to_ball.length() < 8.0:
				mult = 1.12
			velocity = move_vec.normalized() * speed * mult
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
		ball.kick(dir, decision.get("force", 17.0))
		# Record last touch team for restarts
		if ball.has_method("set"):
			ball.set("last_touch_team_a", is_team_a)
		velocity = Vector3.ZERO
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_and_slide()

# -----------------
# Grid tactics
# -----------------
func _apply_grid_tactics_if_applicable() -> bool:
	if not grid_bounds_enabled or ball == null:
		return false
	var bpos: Vector3 = ball.global_transform.origin
	if bpos.x < grid_min_x or bpos.x > grid_max_x or bpos.z < grid_min_z or bpos.z > grid_max_z:
		return false
	# Ball is inside my grid. Determine roles based on last touch
	var my_group := "team_a" if is_team_a else "team_b"
	var opp_group := "team_b" if is_team_a else "team_a"
	var my_teammates := _players_in_my_grid(my_group)
	var opp_players := _players_in_my_grid(opp_group)
	var last_touch_a: bool = true
	if ball.has_method("get"):
		last_touch_a = bool(ball.get("last_touch_team_a"))
	var my_team_in_possession: bool = (last_touch_a == is_team_a)
	var i_am_closest_on_my_team := _is_self_closest_to_ball(my_teammates)
	var i_am_closest_on_opp := _is_self_closest_to_ball(opp_players)
	var to_ball: Vector3 = (bpos - global_transform.origin)
	to_ball.y = 0.0
	var dist_to_ball: float = to_ball.length()

	if my_team_in_possession and i_am_closest_on_my_team:
		# Try to gain control and act: if close enough, kick toward goal; else move to ball
		if dist_to_ball < 1.1:
			var target_x: float = -(field_half_width_x - 2.0) if is_team_a else (field_half_width_x - 2.0)
			# Slight aim toward center of goal mouth
			var shoot_dir: Vector3 = Vector3(target_x, 0.0, clamp(ball.global_transform.origin.z, -field_half_height_z + 4.0, field_half_height_z - 4.0)) - ball.global_transform.origin
			ball.kick(shoot_dir, 17.0)
			if ball.has_method("set"):
				ball.set("last_touch_team_a", is_team_a)
			velocity = Vector3.ZERO
			move_and_slide()
		else:
			velocity = to_ball.normalized() * speed
			move_and_slide()
		return true

	# Defending behaviors when my team is not in possession
	if (not my_team_in_possession) and i_am_closest_on_opp:
		# Closest defender: intercept path by moving directly to ball
		velocity = to_ball.normalized() * speed
		move_and_slide()
		return true
	else:
		if my_team_in_possession:
			# Supporting attacker: move to open passing lane inside cell toward opponent goal
			var support_x: float = (field_half_width_x * 0.5) * (1.0 if is_team_a else -1.0)
			var support_point: Vector3 = Vector3(support_x, 0.0, clamp(bpos.z + randf_range(-4.0, 4.0), grid_min_z + 0.5, grid_max_z - 0.5))
			var to_support: Vector3 = (support_point - global_transform.origin)
			to_support.y = 0.0
			if to_support.length() > 0.05:
				velocity = to_support.normalized() * (speed * 0.8)
				move_and_slide()
			return true
		else:
			# Secondary defender: block shooting lane (stand between ball and goal)
			var defend_target_x: float = (field_half_width_x - 2.0) if is_team_a else -(field_half_width_x - 2.0)
			var lane_mid: Vector3 = ball.global_transform.origin.lerp(Vector3(defend_target_x, 0.0, ball.global_transform.origin.z), 0.35)
			var to_lane: Vector3 = (lane_mid - global_transform.origin)
			to_lane.y = 0.0
			if to_lane.length() > 0.05:
				velocity = to_lane.normalized() * (speed * 0.9)
				move_and_slide()
			return true

	return false

func _players_in_my_grid(group_name: String) -> Array:
	var res: Array = []
	var nodes := get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n is Player3D:
			var p: Player3D = n
			if not p.grid_bounds_enabled:
				continue
			# Check same cell bounds (approximate equality)
			if abs(p.grid_min_x - grid_min_x) < 0.001 and abs(p.grid_max_x - grid_max_x) < 0.001 and abs(p.grid_min_z - grid_min_z) < 0.001 and abs(p.grid_max_z - grid_max_z) < 0.001:
				res.append(p)
	return res

func _is_self_closest_to_ball(players_in_cell: Array) -> bool:
	var best: Player3D = null
	var best_d: float = 1e9
	for n in players_in_cell:
		var p: Player3D = n
		var d: float = p.global_transform.origin.distance_to(ball.global_transform.origin)
		if d < best_d:
			best_d = d
			best = p
	return best == self

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
