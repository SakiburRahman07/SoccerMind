extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	# Get references
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	var ball_pos: Vector3 = ball.global_transform.origin
	var gk_pos: Vector3 = player.global_transform.origin
	var distance_to_ball: float = gk_pos.distance_to(ball_pos)
	
	# Define D-box (penalty area) boundaries
	# Team A defends goal at +58, Team B defends goal at -58
	var own_goal_x: float = 58.0 if player.is_team_a else -58.0
	var penalty_depth: float = 12.0  # How far from goal the keeper can go
	var penalty_width: float = 12.0  # Half-width of penalty box
	
	# Calculate D-box boundaries
	var min_x: float
	var max_x: float
	if player.is_team_a:
		# Team A: goal at +58, keeper stays between +46 and +58
		min_x = own_goal_x - penalty_depth  # 46
		max_x = own_goal_x  # 58
	else:
		# Team B: goal at -58, keeper stays between -58 and -46
		min_x = own_goal_x  # -58
		max_x = own_goal_x + penalty_depth  # -46
	
	# HARD BOUNDARY CHECK: If goalkeeper is outside D-box, force them back in
	var current_x: float = gk_pos.x
	var current_z: float = gk_pos.z
	var is_outside_x: bool = current_x < min_x or current_x > max_x
	var is_outside_z: bool = current_z < -penalty_width or current_z > penalty_width
	
	if is_outside_x or is_outside_z:
		# Force goalkeeper back into D-box
		var safe_x: float = clamp(current_x, min_x, max_x)
		var safe_z: float = clamp(current_z, -penalty_width, penalty_width)
		var safe_pos: Vector3 = Vector3(safe_x, 0.0, safe_z)
		var back_to_box: Vector3 = (safe_pos - gk_pos).normalized()
		return {"action": "move", "direction": back_to_box}
	
	# Clamp target position (ball) to D-box boundaries
	var target_pos: Vector3 = ball_pos
	target_pos.x = clamp(target_pos.x, min_x, max_x)
	target_pos.z = clamp(target_pos.z, -penalty_width, penalty_width)
	target_pos.y = 0.0
	
	var distance_to_target: float = gk_pos.distance_to(target_pos)
	
	# If close to ball (within D-box), kick it toward midfield
	if distance_to_ball < 2.0:
		var kick_direction: Vector3 = Vector3(0.0, 8.0, 0.0)  # Kick toward midfield (x=0) with high arc
		return {"action": "kick", "force": 25.0, "direction": kick_direction}
	
	# Move toward target position (ball position clamped to D-box)
	if distance_to_target > 0.5:
		var to_target: Vector3 = (target_pos - gk_pos).normalized()
		return {"action": "move", "direction": to_target}
	
	return {"action": "idle"}
