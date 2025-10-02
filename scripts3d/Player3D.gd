extends CharacterBody3D

class_name Player3D

@export var is_team_a: bool = true
@export var role: String = "midfielder"
@export var grid_cell_size: float = 4.0

var ball: CharacterBody3D
var speed: float = 8.0  # INCREASED from 9.5 for faster movement
var ai: Node = null
var home_position: Vector3 = Vector3.ZERO

# Animation system variables
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var current_animation: String = "idle"
var animation_blend_time: float = 0.1
var kick_animation_playing: bool = false

# Attack mode for forward players - allows breaking grid constraints
var attack_mode: bool = false
var attack_mode_timer: float = 0.0
var max_attack_mode_time: float = 15.0  # INCREASED for longer attacks

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

# Recent kick intent for conflict resolution
var last_kick_intent_dir: Vector3 = Vector3.ZERO
var last_kick_intent_force: float = 0.0
var last_kick_intent_time_ms: int = 0

func setup(_ball: CharacterBody3D, _ai: Node) -> void:
	ball = _ball
	ai = _ai
	ai.set("player", self)
	ai.set("ball", ball)
	add_child(ai)
	# Initialize grid at current position
	current_grid = _world_to_grid(global_transform.origin)
	target_grid = current_grid
	# Setup team appearance
	setup_team_appearance()

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
	# Update attack mode timer
	if attack_mode:
		attack_mode_timer += _delta
		if attack_mode_timer > max_attack_mode_time:
			attack_mode = false
			attack_mode_timer = 0.0
	
	# Check if forward players should enter attack mode
	_check_attack_mode()
	
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
	# Update animations based on player state
	update_animation()
	
	# Keep player locked to pitch plane
	global_position.y = 1.0
	# Relaxed bounds to allow slight overlap near walls
	var margin: float = 0.3
	var clamped_x: float = clamp(global_position.x, -field_half_width_x + margin, field_half_width_x - margin)
	var clamped_z: float = clamp(global_position.z, -field_half_height_z + margin, field_half_height_z - margin)
	
	# CRITICAL FIX: Much more flexible grid constraints for goal scoring
	# Allow ALL players to break grid when very close to opponent goal
	if grid_bounds_enabled and not _should_ignore_grid_for_goal():
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
		var my_group_name := "team_a" if is_team_a else "team_b"
		var my_team_rank: int = _team_rank_to_ball(my_group_name)
		var direct_chase: bool = (to_ball.length() < 8.0) or (to_ball.length() < 25.0 and my_team_rank > 0 and my_team_rank <= 4)  # INCREASED range
		if direct_chase:
			var move_vec: Vector3 = to_ball
			move_vec.y = 0.0
			var mult: float = 1.0
			if to_ball.length() < 12.0:  # INCREASED from 8.0
				mult = 1.25  # INCREASED speed multiplier
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
		var force: float = decision.get("force", 17.0)
		# Record my intent
		last_kick_intent_dir = dir
		last_kick_intent_force = force
		last_kick_intent_time_ms = Time.get_ticks_msec()
		# Detect conflicting intent from another nearby player and resolve via fuzzy logic
		var resolved_dir: Vector3 = dir
		var resolved_force: float = force
		var now_ms: int = Time.get_ticks_msec()
		var conflict_found: bool = false
		var my_group := "team_a" if is_team_a else "team_b"
		var opp_group := "team_b" if is_team_a else "team_a"
		var teammates := get_tree().get_nodes_in_group(my_group)
		var opponents := get_tree().get_nodes_in_group(opp_group)
		for n in teammates + opponents:
			if n == self:
				continue
			if n is Player3D:
				var p: Player3D = n
				var near_ball: bool = p.global_transform.origin.distance_to(ball.global_transform.origin) < 1.5
				var recent: bool = abs(now_ms - p.last_kick_intent_time_ms) <= 200
				if near_ball and recent and p.last_kick_intent_dir != Vector3.ZERO:
					# Consider it a conflict if directions differ significantly
					var cosang: float = dir.normalized().dot(p.last_kick_intent_dir.normalized())
					if cosang < 0.8:
						var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
						var result: Dictionary = fuzzy.resolve_kick_conflict(self, p, dir, force, ball, teammates, opponents, is_team_a)
						resolved_dir = result.get("direction", dir)
						resolved_force = result.get("force", force)
						conflict_found = true
						break
		# Execute kick with resolved outcome
		ball.kick(resolved_dir, resolved_force)
		# Record last touch team for restarts
		if ball.has_method("set"):
			ball.set("last_touch_team_a", is_team_a)
		# Trigger kick animation
		play_kick_animation()
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
	var my_rank_among_closest: int = _rank_among_closest(my_teammates)
	var opp_rank_among_closest: int = _rank_among_closest(opp_players)
	var to_ball: Vector3 = (bpos - global_transform.origin)
	to_ball.y = 0.0
	var dist_to_ball: float = to_ball.length()

	# If in possession: let the two closest teammates in this grid chase/act
	if my_team_in_possession and my_rank_among_closest > 0 and my_rank_among_closest <= 2:
		# Try to gain control and act: if close enough, kick toward goal; else move to ball
		# INCREASED shooting range for grid tactics
		if dist_to_ball < 4.0:  # INCREASED from 1.6
			var target_x: float = -(field_half_width_x - 2.0) if is_team_a else (field_half_width_x - 2.0)
			# Aim away from goalkeeper within grid tactic too
			var keeper_z: float = 0.0
			var have_gk: bool = false
			for o in get_tree().get_nodes_in_group(opp_group):
				if o is Player3D and o.role == "goalkeeper":
					keeper_z = o.global_transform.origin.z
					have_gk = true
					break
			var aim_z: float = clamp(ball.global_transform.origin.z, -field_half_height_z + 6.0, field_half_height_z - 6.0)
			if have_gk:
				var away_sign: float = 1.0 if (ball.global_transform.origin.z < keeper_z) else -1.0
				aim_z = clamp(keeper_z + away_sign * 6.0, -field_half_height_z + 6.0, field_half_height_z - 6.0)
			var shoot_dir: Vector3 = Vector3(target_x, 0.0, aim_z) - ball.global_transform.origin
			# ENHANCED shot power and lift
			shoot_dir.y = 2.0  # INCREASED lift
			ball.kick(shoot_dir, 25.0)  # INCREASED power from 19.0
			if ball.has_method("set"):
				ball.set("last_touch_team_a", is_team_a)
			# Trigger kick animation
			play_kick_animation()
			velocity = Vector3.ZERO
			move_and_slide()
		else:
			velocity = to_ball.normalized() * speed
			move_and_slide()
		return true

	# Defending behaviors when my team is not in possession: allow two closest opponents to press
	if (not my_team_in_possession) and opp_rank_among_closest > 0 and opp_rank_among_closest <= 2:
		# Pressing defender: intercept path by moving directly to ball
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

func _team_rank_to_ball(group_name: String) -> int:
	var nodes := get_tree().get_nodes_in_group(group_name)
	var my_d: float = 1e9
	var found_self: bool = false
	for n in nodes:
		if n is Player3D and n == self:
			my_d = self.global_transform.origin.distance_to(ball.global_transform.origin)
			found_self = true
			break
	if not found_self:
		return 0
	var better_count: int = 0
	for n in nodes:
		if n is Player3D and n != self:
			var d: float = n.global_transform.origin.distance_to(ball.global_transform.origin)
			if d < my_d:
				better_count += 1
	return better_count + 1
func _rank_among_closest(players_in_cell: Array) -> int:
	var my_d: float = 1e9
	var found_self: bool = false
	for n in players_in_cell:
		var p: Player3D = n
		if p == self:
			my_d = p.global_transform.origin.distance_to(ball.global_transform.origin)
			found_self = true
			break
	if not found_self:
		return 0
	var better_count: int = 0
	for n in players_in_cell:
		var p2: Player3D = n
		if p2 != self:
			var d: float = p2.global_transform.origin.distance_to(ball.global_transform.origin)
			if d < my_d:
				better_count += 1
	return better_count + 1

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

# Attack mode and grid flexibility functions
func _check_attack_mode() -> void:
	if not ball or not _is_forward_player():
		return
	
	# MUCH more aggressive attack mode activation
	var opponent_goal_x: float = -field_half_width_x if is_team_a else field_half_width_x
	var ball_in_opponent_half: bool = (is_team_a and ball.global_transform.origin.x < 10.0) or (not is_team_a and ball.global_transform.origin.x > -10.0)  # EXPANDED zone
	var close_to_ball: bool = global_transform.origin.distance_to(ball.global_transform.origin) < 30.0  # INCREASED from 20.0
	var my_team_has_ball: bool = _my_team_has_possession()
	
	# Enter attack mode for forward players when conditions are met
	if ball_in_opponent_half and close_to_ball and my_team_has_ball:
		if not attack_mode:
			attack_mode = true
			attack_mode_timer = 0.0
			print("Forward player entering attack mode: ", role)

# CRITICAL: Much more flexible grid override for goal scoring
func _should_ignore_grid_for_goal() -> bool:
	if not ball:
		return false
	
	# Allow ALL players to break grid when ball is close to ANY goal
	var opponent_goal_x: float = -field_half_width_x if is_team_a else field_half_width_x
	var ball_distance_to_goal: float = abs(ball.global_transform.origin.x - opponent_goal_x)
	var player_distance_to_ball: float = global_transform.origin.distance_to(ball.global_transform.origin)
	
	# MUCH more lenient conditions for grid breaking
	if ball_distance_to_goal < 35.0 and player_distance_to_ball < 15.0:  # INCREASED ranges
		return true
	
	# Also allow grid breaking in attack mode for forward players
	if _is_forward_player() and attack_mode:
		return true
	
	# Allow grid breaking when very close to ball regardless of position
	if player_distance_to_ball < 5.0:
		return true
	
	return false

func _is_forward_player() -> bool:
	# Forward players who can break grid constraints
	return role == "striker" or role == "midfielder"

func _my_team_has_possession() -> bool:
	if not ball or not ball.has_method("get"):
		return false
	
	var last_touch_a: bool = bool(ball.get("last_touch_team_a"))
	return last_touch_a == is_team_a

# ==========================================
# ANIMATION AND APPEARANCE SYSTEM
# ==========================================

func setup_team_appearance() -> void:
	"""Setup team-specific jersey colors and materials"""
	if not has_node("PlayerModel"):
		return
		
	var player_model = $PlayerModel
	var jersey_material = StandardMaterial3D.new()
	
	# Set team colors - special handling for goalkeepers
	if role == "goalkeeper":
		# Goalkeepers get bright yellow/green for visibility
		jersey_material.albedo_color = Color(1.0, 0.9, 0.2, 1)  # Bright yellow
	elif is_team_a:
		jersey_material.albedo_color = Color(0.2, 0.4, 0.9, 1)  # Blue for Team A
	else:
		jersey_material.albedo_color = Color(0.9, 0.2, 0.2, 1)  # Red for Team B
	
	# Apply jersey material to torso and upper arms
	if player_model.has_node("Torso"):
		player_model.get_node("Torso").material_override = jersey_material
	
	if player_model.has_node("LeftArm/UpperArm"):
		player_model.get_node("LeftArm/UpperArm").material_override = jersey_material
		
	if player_model.has_node("RightArm/UpperArm"):
		player_model.get_node("RightArm/UpperArm").material_override = jersey_material

func update_animation() -> void:
	"""Update player animations based on current state"""
	if not animation_player or kick_animation_playing:
		return
		
	var new_animation = "idle"
	var movement_threshold = 0.5
	
	# Determine animation based on player state
	if velocity.length() > movement_threshold:
		new_animation = "running"
	else:
		new_animation = "idle"
	
	# Only change animation if it's different from current
	if new_animation != current_animation:
		current_animation = new_animation
		if animation_player.has_animation(current_animation):
			animation_player.play(current_animation, animation_blend_time)

func play_kick_animation() -> void:
	"""Play kicking animation when player kicks the ball"""
	if not animation_player:
		return
		
	kick_animation_playing = true
	current_animation = "kicking"
	
	if animation_player.has_animation("kicking"):
		animation_player.play("kicking")
		# Connect to animation finished signal to return to normal animations
		if not animation_player.animation_finished.is_connected(_on_kick_animation_finished):
			animation_player.animation_finished.connect(_on_kick_animation_finished)

func _on_kick_animation_finished(animation_name: String) -> void:
	"""Called when kick animation finishes"""
	if animation_name == "kicking":
		kick_animation_playing = false
		# Disconnect the signal to avoid multiple connections
		if animation_player.animation_finished.is_connected(_on_kick_animation_finished):
			animation_player.animation_finished.disconnect(_on_kick_animation_finished)
		# Return to appropriate animation based on current state
		update_animation()