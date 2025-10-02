extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	# Home bias
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	
	# FIXED: Correct goal assignment for realistic football
	# Team A attacks left goal (-X), so Team A goalkeeper defends right goal (+X)
	# Team B attacks right goal (+X), so Team B goalkeeper defends left goal (-X)
	var goal_x: float = 58.0 if player.is_team_a else -58.0
	
	# REALISTIC goalkeeper behavior: stay close to own goal
	var keeper_line_x: float = goal_x - 3.0 if player.is_team_a else goal_x + 3.0
	
	# Penalty box constraints - goalkeeper should stay in penalty area
	var max_forward_from_goal: float = 6.0  # Can come out a bit to collect balls
	var min_back_from_goal: float = -1.0    # Can go slightly behind goal line
	var penalty_half_width_z: float = 12.0  # Penalty box width
	
	# Only come out when ball is very close
	var sweep_radius: float = 12.0
	
	# Minimal jitter for consistent positioning
	var jitter: float = randf_range(-0.1, 0.1)
	
	# Calculate target position based on ball position
	var target_x: float = clamp(keeper_line_x, goal_x + min_back_from_goal, goal_x + max_forward_from_goal)
	var target_z: float = clamp(ball.global_transform.origin.z + jitter, -penalty_half_width_z, penalty_half_width_z)
	
	var distance_ball_to_goal: float = ball.global_transform.origin.distance_to(Vector3(goal_x, 0.0, 0.0))
	
	# When ball is far, stay more central
	if distance_ball_to_goal > sweep_radius:
		target_z = clamp(target_z * 0.3, -8.0, 8.0)
	
	var target := Vector3(target_x, 0.0, target_z)
	
	# STRICT penalty area enforcement - goalkeeper must stay in penalty area
	var px: float = player.global_transform.origin.x
	var pz: float = player.global_transform.origin.z
	var min_x: float = min(goal_x + min_back_from_goal, goal_x + max_forward_from_goal)
	var max_x: float = max(goal_x + min_back_from_goal, goal_x + max_forward_from_goal)
	var clamped_px: float = clamp(px, min_x, max_x)
	var clamped_pz: float = clamp(pz, -penalty_half_width_z, penalty_half_width_z)
	
	# Force return to penalty area if outside
	if px != clamped_px or pz != clamped_pz:
		var return_point: Vector3 = Vector3(clamped_px, 0.0, clamped_pz)
		return {"action": "move", "direction": (return_point - player.global_transform.origin).normalized()}
	
	# Normal positioning toward target
	var desire: Vector3 = (target - player.global_transform.origin)
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.2
	var dir: Vector3 = (desire + keep_shape).normalized()

	# Minimal errors for realistic goalkeeper behavior
	if distance_ball_to_goal < 10.0:
		var chance := randf()
		# Very small chance of minor errors
		if chance < 0.02:  # 2% chance of hesitation
			return {"action": "idle"}
		elif chance < 0.05:  # 3% chance of slight mispositioning
			var wrong: Vector3 = Vector3(0, 0, randf_range(-0.5, 0.5))
			return {"action": "move", "direction": (dir + wrong.normalized() * 0.05)}
	
	# Clear ball when it's very close and in penalty area
	var close_to_ball: bool = player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.5
	var ball_in_penalty: bool = abs(ball.global_transform.origin.z) <= penalty_half_width_z
	var ball_near_goal: bool = abs(ball.global_transform.origin.x - goal_x) < 8.0
	
	if close_to_ball and ball_in_penalty and ball_near_goal:
		# Clear ball away from goal toward sidelines
		var clear_direction: Vector3
		
		# Determine best clearance direction
		if abs(ball.global_transform.origin.z) > 6.0:
			# Ball near sideline - clear along sideline
			var side_sign: float = 1.0 if ball.global_transform.origin.z > 0 else -1.0
			clear_direction = Vector3(0, 2.0, side_sign * 8.0)
		else:
			# Ball central - clear to nearest sideline
			var side_sign: float = 1.0 if randf() > 0.5 else -1.0
			clear_direction = Vector3(0, 3.0, side_sign * 10.0)
		
		# Add forward component away from own goal
		var away_from_goal: float = -8.0 if player.is_team_a else 8.0
		clear_direction.x = away_from_goal
		
		return {"action": "kick", "force": 20.0, "direction": clear_direction}
	
	return {"action": "move", "direction": dir}