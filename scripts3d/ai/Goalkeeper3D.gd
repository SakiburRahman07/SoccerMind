extends Node

var player: Node
var ball: CharacterBody3D

# Goalkeeper state management
enum GKState { POSITIONING, COLLECTING, CLEARING, DIVING }
var current_state: GKState = GKState.POSITIONING
var state_timer: float = 0.0
var has_possession: bool = false
var possession_timer: float = 0.0
var debug_print_timer: float = 0.0  # For periodic position debugging

func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	# Update state timer
	state_timer += 0.016  # Approximate delta
	debug_print_timer += 0.016
	
	# Home bias
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	
	# GOAL SETUP:
	# Team A: defends RIGHT goal (+58), attacks LEFT goal (-58)
	# Team B: defends LEFT goal (-58), attacks RIGHT goal (+58)
	var own_goal_x: float = 58.0 if player.is_team_a else -58.0
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	
	# Goalkeeper positioning line (should be TOWARD field center, not behind goal)
	# Team A (goal at +58): keeper at +55 (58 - 3) - toward center (left)
	# Team B (goal at -58): keeper at -55 (-58 + 3) - toward center (right)
	# BOTH should move TOWARD ZERO (field center), so:
	var keeper_line_x: float = own_goal_x - 3.0 if player.is_team_a else own_goal_x + 3.0
	
	# Penalty box constraints - goalkeeper should NEVER go behind the goal line!
	var max_forward_from_goal: float = 12.0  # Can come forward to edge of penalty box
	var min_back_from_goal: float = 0.5  # Stay 0.5 units IN FRONT of goal, never behind!
	var penalty_half_width_z: float = 12.0
	
	# Ball tracking
	var ball_pos: Vector3 = ball.global_transform.origin
	var ball_vel: Vector3 = ball.velocity if ball else Vector3.ZERO
	var gk_pos: Vector3 = player.global_transform.origin
	var distance_to_ball: float = gk_pos.distance_to(ball_pos)
	var distance_ball_to_goal: float = abs(ball_pos.x - own_goal_x)
	
	# Check if ball is heading toward our goal
	var ball_heading_to_goal: bool = _is_ball_heading_toward_goal(ball_pos, ball_vel, own_goal_x)
	
	# Calculate optimal positioning
	var target_x: float = keeper_line_x
	var target_z: float = clamp(ball_pos.z, -penalty_half_width_z, penalty_half_width_z)
	
	# When ball is far, stay more central
	if distance_ball_to_goal > 20.0:
		target_z = clamp(target_z * 0.3, -8.0, 8.0)
	
	var target: Vector3 = Vector3(target_x, 0.0, target_z)
	
	# STRICT penalty area enforcement - goalkeeper MUST stay in front of goal
	# Team A (goal at +58): allowed range is +55 to +46 (toward center/left)
	# Team B (goal at -58): allowed range is -55 to -46 (toward center/right)
	var px: float = gk_pos.x
	var pz: float = gk_pos.z
	
	# Calculate boundaries correctly for each team
	var min_x: float
	var max_x: float
	
	if player.is_team_a:
		# Team A: goal at +58, keeper should be between +46 (forward) and +57.5 (back limit)
		min_x = own_goal_x - max_forward_from_goal  # 58 - 12 = 46
		max_x = own_goal_x - min_back_from_goal     # 58 - 0.5 = 57.5
	else:
		# Team B: goal at -58, keeper should be between -57.5 (back limit) and -46 (forward)
		min_x = own_goal_x + min_back_from_goal     # -58 + 0.5 = -57.5
		max_x = own_goal_x + max_forward_from_goal  # -58 + 12 = -46
	
	var clamped_px: float = clamp(px, min_x, max_x)
	var clamped_pz: float = clamp(pz, -penalty_half_width_z, penalty_half_width_z)
	
	# Debug print every 3 seconds to verify positioning
	if debug_print_timer > 3.0:
		debug_print_timer = 0.0
		var team_name: String = "Team A" if player.is_team_a else "Team B"
		print("🧤 ", team_name, " GK Position: x=", snappedf(px, 0.1), " (allowed: ", snappedf(min_x, 0.1), " to ", snappedf(max_x, 0.1), "), z=", snappedf(pz, 0.1), " | Goal at x=", own_goal_x)
	
	# Force return to penalty area if outside
	if px != clamped_px or pz != clamped_pz:
		var return_point: Vector3 = Vector3(clamped_px, 0.0, clamped_pz)
		print("⚠️ GK OUT OF BOUNDS! Moving from (", snappedf(px, 0.1), ", ", snappedf(pz, 0.1), ") to (", snappedf(clamped_px, 0.1), ", ", snappedf(clamped_pz, 0.1), ")")
		return {"action": "move", "direction": (return_point - gk_pos).normalized()}
	
	# Check if we have possession (ball is very close and slow)
	var ball_very_close: bool = distance_to_ball < 1.5
	var ball_slow: bool = ball_vel.length() < 2.0
	
	if ball_very_close and ball_slow:
		has_possession = true
		possession_timer += 0.016
	else:
		has_possession = false
		possession_timer = 0.0
	
	# STATE MACHINE: Decide action based on situation
	
	# STATE 1: CLEARING - We have possession, time to distribute
	if has_possession and possession_timer > 0.5:
		return _decide_clearance(ball_pos, gk_pos, opponent_goal_x, own_goal_x)
	
	# STATE 2: COLLECTING - Ball is close and we should grab it
	var ball_in_penalty: bool = abs(ball_pos.z) <= penalty_half_width_z
	var ball_near_goal: bool = distance_ball_to_goal < 10.0
	var should_collect: bool = distance_to_ball < 3.0 and ball_in_penalty and ball_near_goal
	
	if should_collect:
		# Move directly to ball to collect it
		var to_ball: Vector3 = (ball_pos - gk_pos)
		to_ball.y = 0.0
		if to_ball.length() > 0.1:
			return {"action": "move", "direction": to_ball.normalized()}
		else:
			# We're on the ball, wait for possession to trigger clearing
			return {"action": "idle"}
	
	# STATE 3: DIVING/SAVING - Ball is heading toward goal, make a save!
	if ball_heading_to_goal and distance_ball_to_goal < 15.0 and distance_to_ball < 8.0:
		# Intercept the ball's path
		var intercept_point: Vector3 = _calculate_intercept_point(ball_pos, ball_vel, own_goal_x)
		var to_intercept: Vector3 = (intercept_point - gk_pos)
		to_intercept.y = 0.0
		
		if to_intercept.length() > 0.5:
			return {"action": "move", "direction": to_intercept.normalized()}
		else:
			# We're at intercept point, kick it away!
			return _decide_emergency_clearance(ball_pos, opponent_goal_x)
	
	# STATE 4: POSITIONING - Normal goalkeeper positioning
	var desire: Vector3 = (target - gk_pos)
	var keep_shape: Vector3 = (home - gk_pos) * 0.2
	var dir: Vector3 = (desire + keep_shape).normalized()
	
	return {"action": "move", "direction": dir}

# Helper: Check if ball is heading toward our goal
func _is_ball_heading_toward_goal(ball_pos: Vector3, ball_vel: Vector3, own_goal_x: float) -> bool:
	if ball_vel.length() < 1.0:
		return false
	
	# Check if velocity has component toward our goal
	var to_goal: Vector3 = Vector3(own_goal_x, 0.0, 0.0) - ball_pos
	var vel_horizontal: Vector3 = Vector3(ball_vel.x, 0.0, ball_vel.z)
	
	if vel_horizontal.length() < 0.1:
		return false
	
	var dot_product: float = to_goal.normalized().dot(vel_horizontal.normalized())
	return dot_product > 0.3  # Ball has significant component toward goal

# Helper: Calculate intercept point for saving
func _calculate_intercept_point(ball_pos: Vector3, ball_vel: Vector3, own_goal_x: float) -> Vector3:
	# Predict where ball will be
	var prediction_time: float = 0.5
	var predicted_pos: Vector3 = ball_pos + ball_vel * prediction_time
	
	# Clamp to goal line area
	predicted_pos.x = clamp(predicted_pos.x, own_goal_x - 2.0, own_goal_x + 2.0)
	predicted_pos.z = clamp(predicted_pos.z, -10.0, 10.0)
	predicted_pos.y = 0.0
	
	return predicted_pos

# Helper: Emergency clearance when ball is dangerous
func _decide_emergency_clearance(ball_pos: Vector3, opponent_goal_x: float) -> Dictionary:
	# High aerial clearance to safety - ALWAYS use high arc
	var forward_direction: float = opponent_goal_x - ball_pos.x
	var clear_direction: Vector3 = Vector3(forward_direction, 10.0, 0.0)
	
	# Add side variation to avoid center congestion
	var side_sign: float = 1.0 if ball_pos.z > 0 else -1.0
	clear_direction.z = side_sign * randf_range(10.0, 15.0)
	
	print("⚡ EMERGENCY CLEARANCE - HIGH AERIAL KICK!")
	return {"action": "kick", "force": 30.0, "direction": clear_direction}

# Helper: Intelligent clearance decision when we have possession
func _decide_clearance(ball_pos: Vector3, gk_pos: Vector3, opponent_goal_x: float, own_goal_x: float) -> Dictionary:
	# Assess pressure from opponents
	var opponents := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	var nearest_opponent_dist: float = 999.0
	var num_nearby_opponents: int = 0
	
	for opp in opponents:
		if opp is CharacterBody3D:
			var dist: float = opp.global_transform.origin.distance_to(gk_pos)
			if dist < nearest_opponent_dist:
				nearest_opponent_dist = dist
			if dist < 15.0:
				num_nearby_opponents += 1
	
	# High pressure: Long clearance
	var under_pressure: bool = nearest_opponent_dist < 8.0 or num_nearby_opponents >= 2
	
	if under_pressure:
		return _long_punt_clearance(ball_pos, opponent_goal_x)
	else:
		# Low pressure: Look for safe pass to teammate
		var teammates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var best_teammate = _find_safe_pass_target(gk_pos, ball_pos, teammates, opponents)
		
		if best_teammate:
			return _pass_to_teammate(ball_pos, best_teammate)
		else:
			# No safe pass, do medium punt
			return _medium_punt_clearance(ball_pos, opponent_goal_x)

# Helper: Long high punt upfield
func _long_punt_clearance(ball_pos: Vector3, opponent_goal_x: float) -> Dictionary:
	var team_name: String = "Team A" if player.is_team_a else "Team B"
	print("🥅 ", team_name, " GK: LONG PUNT CLEARANCE")
	print("   Target: opponent goal at x=", opponent_goal_x)
	
	# Calculate direction toward opponent half - MUST be at least to midfield
	var forward_distance: float = opponent_goal_x - ball_pos.x
	var punt_direction: Vector3 = Vector3(forward_distance, 0.0, 0.0)
	
	# ALWAYS use very high lift for long punt - minimum y=12
	punt_direction.y = 12.0
	
	# Add sideline variation to avoid center congestion
	var side_variation: float = randf_range(-8.0, 8.0)
	punt_direction.z = side_variation
	
	print("   Direction: ", punt_direction.normalized())
	print("   Force: 32.0 (LONG PUNT - HIGH ARC)")
	
	return {"action": "kick", "force": 32.0, "direction": punt_direction}

# Helper: Medium punt to midfield - ALWAYS HIGH
func _medium_punt_clearance(ball_pos: Vector3, opponent_goal_x: float) -> Dictionary:
	var team_name: String = "Team A" if player.is_team_a else "Team B"
	print("🥅 ", team_name, " GK: MEDIUM PUNT CLEARANCE")
	
	# Target at least midfield (50% toward opponent goal)
	var midfield_target: float = ball_pos.x + (opponent_goal_x - ball_pos.x) * 0.5
	
	# Ensure we're kicking toward midfield or beyond
	var min_forward_distance: float = abs(opponent_goal_x - ball_pos.x) * 0.4  # At least 40% to opponent half
	var forward_distance: float = max(midfield_target - ball_pos.x, min_forward_distance)
	
	var punt_direction: Vector3 = Vector3(forward_distance, 10.0, randf_range(-10.0, 10.0))
	
	print("   Force: 26.0 (MEDIUM PUNT - HIGH ARC)")
	return {"action": "kick", "force": 26.0, "direction": punt_direction}

# Helper: Pass to safe teammate - MODIFIED to use lofted passes
func _pass_to_teammate(ball_pos: Vector3, teammate: Node) -> Dictionary:
	var team_name: String = "Team A" if player.is_team_a else "Team B"
	print("🥅 ", team_name, " GK: LOFTED PASS to ", teammate.name)
	
	var target_pos: Vector3 = teammate.global_transform.origin
	var pass_direction: Vector3 = target_pos - ball_pos
	var distance: float = pass_direction.length()
	
	# ALWAYS use lofted passes - no ground passes from goalkeeper
	# Short distance: medium loft
	if distance < 15.0:
		pass_direction.y = 6.0  # Medium loft
		print("   Short lofted pass (y=6.0)")
		return {"action": "kick", "force": 14.0, "direction": pass_direction}
	# Medium distance: high loft
	elif distance < 30.0:
		pass_direction.y = 8.0  # High loft
		print("   Medium lofted pass (y=8.0)")
		return {"action": "kick", "force": 20.0, "direction": pass_direction}
	# Long distance: very high loft
	else:
		pass_direction.y = 10.0  # Very high loft
		print("   Long lofted pass (y=10.0)")
		return {"action": "kick", "force": 26.0, "direction": pass_direction}

# Helper: Find safe teammate to pass to
func _find_safe_pass_target(gk_pos: Vector3, ball_pos: Vector3, teammates: Array, opponents: Array):
	var best_teammate = null
	var best_score: float = -999.0
	
	for mate in teammates:
		if mate == player or not (mate is CharacterBody3D):
			continue
		
		var mate_pos: Vector3 = mate.global_transform.origin
		var dist_to_mate: float = gk_pos.distance_to(mate_pos)
		
		# Don't pass too far or too close
		if dist_to_mate < 8.0 or dist_to_mate > 35.0:
			continue
		
		# Check if mate is marked by opponents
		var nearest_opp_dist: float = 999.0
		for opp in opponents:
			if opp is CharacterBody3D:
				var opp_dist: float = mate_pos.distance_to(opp.global_transform.origin)
				if opp_dist < nearest_opp_dist:
					nearest_opp_dist = opp_dist
		
		# Score based on: distance (prefer medium), openness (prefer unmarked)
		var score: float = nearest_opp_dist - (dist_to_mate * 0.2)
		
		if score > best_score and nearest_opp_dist > 5.0:  # Must be reasonably open
			best_score = score
			best_teammate = mate
	
	return best_teammate