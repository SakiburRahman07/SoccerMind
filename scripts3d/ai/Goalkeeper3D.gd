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
	# Correct goal side: Team A defends +X, Team B defends -X
	var goal_x: float = 58.0 if player.is_team_a else -58.0
	# Keeper patrol line MUCH closer to goal line (very easy to beat)
	var keeper_line_x: float = goal_x - 0.2 if player.is_team_a else goal_x + 0.2
	# Box constraints (VERY narrow and shallow - easy to beat)
	var max_forward_from_goal: float = 1.0  # REDUCED from 2.0
	var min_back_from_goal: float = -0.5
	var penalty_half_width_z: float = 8.0  # REDUCED from 10.0
	# Only sweep if ball VERY near box
	var sweep_radius: float = 6.0  # REDUCED from 9.0
	# Desired target follows ball.z but respects constraints
	var jitter: float = randf_range(-1.0, 1.0)  # INCREASED jitter for more errors
	var target_x: float = clamp(keeper_line_x, goal_x + min_back_from_goal, goal_x + max_forward_from_goal)
	var target_z: float = clamp(ball.global_transform.origin.z + jitter, -penalty_half_width_z, penalty_half_width_z)
	var distance_ball_to_goal: float = ball.global_transform.origin.distance_to(Vector3(goal_x, 0.0, 0.0))
	if distance_ball_to_goal > sweep_radius:
		# Stay more central when ball is far
		target_z = clamp(target_z * 0.2, -6.0, 6.0)  # REDUCED range
	var target := Vector3(target_x, 0.0, target_z)
	# Hard clamp return if drifted out of area
	var px: float = player.global_transform.origin.x
	var pz: float = player.global_transform.origin.z
	var min_x: float = min(goal_x + min_back_from_goal, goal_x + max_forward_from_goal)
	var max_x: float = max(goal_x + min_back_from_goal, goal_x + max_forward_from_goal)
	var clamped_px: float = clamp(px, min_x, max_x)
	var clamped_pz: float = clamp(pz, -penalty_half_width_z, penalty_half_width_z)
	if px != clamped_px or pz != clamped_pz:
		var return_point: Vector3 = Vector3(clamped_px, 0.0, clamped_pz)
		return {"action": "move", "direction": (return_point - player.global_transform.origin).normalized()}
	# Normal shading toward target with slight home bias
	var desire: Vector3 = (target - player.global_transform.origin)
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.1  # REDUCED
	var dir: Vector3 = (desire + keep_shape).normalized()

	# MASSIVE hesitation: frequently pause or move wrong to allow easy goals
	if distance_ball_to_goal < 30.0:  # INCREASED range for more errors
		var chance := randf()
		# MASSIVELY increased idle chance for easy goals
		if chance < 0.4:  # INCREASED from 0.22 to 40% chance
			return {"action": "idle"}
		# MASSIVELY increased wrong movement
		elif chance < 0.7:  # INCREASED from 0.45 to 70% chance
			var wrong: Vector3 = Vector3(0, 0, (ball.global_transform.origin.z - player.global_transform.origin.z))
			wrong.z *= -1.2  # INCREASED wrong movement
			return {"action": "move", "direction": (dir + wrong.normalized() * 0.8)}
	
	# Clear if ball is very close inside box
	var close_to_ball: bool = player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.0
	if close_to_ball and abs(ball.global_transform.origin.z) <= penalty_half_width_z:
		var side := randf_range(-8.0, 8.0)  # INCREASED randomness
		# Clear away from own goal
		var up_dir := -1.0 if player.is_team_a else 1.0
		# VERY weak clearances to increase turnovers
		return {"action": "kick", "force": 8.0, "direction": Vector3(up_dir * 4.0, 0, side * 0.8)}  # REDUCED power
	
	return {"action": "move", "direction": dir}