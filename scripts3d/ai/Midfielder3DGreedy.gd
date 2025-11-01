extends Node

var player: Node
var ball: CharacterBody3D

# Simple Greedy Algorithm: Evaluate all immediate options and pick the best one
func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	
	# If far from ball, move toward it
	if to_ball.length() >= 2.5:
		var desire: Vector3 = to_ball
		var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.4
		var dir: Vector3 = (desire + keep_shape).normalized()
		return {"action": "move", "direction": dir}
	
	# GREEDY: When close to ball, evaluate all options and pick best immediate reward
	var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	
	# Generate all possible actions with scores
	var all_options: Array = []
	
	# Option 1: Shoot
	var shoot_option: Dictionary = _evaluate_shooting(opps)
	if shoot_option.has("action"):
		all_options.append(shoot_option)
	
	# Option 2: Pass to best teammate
	var pass_option: Dictionary = _evaluate_passing(mates, opps)
	if pass_option.has("action"):
		all_options.append(pass_option)
	
	# Option 3: Dribble forward
	var dribble_option: Dictionary = _evaluate_dribbling(opps)
	if dribble_option.has("action"):
		all_options.append(dribble_option)
	
	# GREEDY SELECTION: Pick option with highest immediate score
	var best_option: Dictionary = {"action": "idle", "score": -INF}
	for option in all_options:
		if option.get("score", -INF) > best_option.get("score", -INF):
			best_option = option
	
	# Return the action (remove score before returning)
	var action: Dictionary = {}
	for key in best_option.keys():
		if key != "score":
			action[key] = best_option[key]
	
	return action

# Evaluate shooting option with immediate score
func _evaluate_shooting(opps: Array) -> Dictionary:
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var ball_pos: Vector3 = ball.global_transform.origin
	var distance_to_goal: float = abs(ball_pos.x - opponent_goal_x)
	
	# Only consider shooting if reasonably close
	if distance_to_goal > 25.0:
		return {}  # Not a valid option
	
	var to_goal: Vector3 = Vector3(opponent_goal_x, 0, 0) - ball_pos
	var to_ball: Vector3 = ball_pos - player.global_transform.origin
	var angle_cos: float = to_ball.normalized().dot(to_goal.normalized())
	
	# Must have decent angle
	if angle_cos < 0.4:
		return {}  # Not a valid option
	
	# Create shoot action
	var shot_dir: Vector3 = to_goal
	shot_dir.y = 1.0
	var force: float = 17.0
	
	# Calculate immediate score (greedy evaluation)
	var score: float = 0.0
	
	# 1. Closer to goal = higher score
	score += (30.0 - distance_to_goal) * 2.0  # Up to 60 points
	
	# 2. Better angle = higher score
	score += angle_cos * 30.0  # Up to 30 points
	
	# 3. Space from opponents
	var closest_opp: float = 999.0
	for opp in opps:
		var dist: float = opp.global_transform.origin.distance_to(ball_pos)
		if dist < closest_opp:
			closest_opp = dist
	
	if closest_opp > 4.0:
		score += 20.0  # Clear shot bonus
	elif closest_opp < 2.0:
		score -= 30.0  # Blocked shot penalty
	
	return {"action": "kick", "force": force, "direction": shot_dir, "score": score}

# Evaluate passing option with immediate score
func _evaluate_passing(mates: Array, opps: Array) -> Dictionary:
	var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
	var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
	var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((-1.0 if player.is_team_a else 1.0) * 8.0, 0, 0))
	var lob: bool = pick.get("lob", false)
	var dir_pass: Vector3 = (target - ball.global_transform.origin)
	
	# Calculate pressure at target
	var min_opp: float = 9999.0
	for o in opps:
		var d: float = o.global_transform.origin.distance_to(target)
		if d < min_opp:
			min_opp = d
	var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
	
	var distance: float = dir_pass.length()
	var force: float = fuzzy.decide_pass_force(distance, pressure)
	
	if lob:
		dir_pass.y = 3.0
	
	# Calculate immediate score (greedy evaluation)
	var score: float = 0.0
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var ball_pos: Vector3 = ball.global_transform.origin
	
	# 1. Forward progress (pass toward goal)
	var ball_dist_to_goal: float = abs(ball_pos.x - opponent_goal_x)
	var target_dist_to_goal: float = abs(target.x - opponent_goal_x)
	var progress: float = ball_dist_to_goal - target_dist_to_goal
	score += progress * 3.0  # Reward forward passes
	
	# 2. Safety (low pressure is good)
	score += (1.0 - pressure) * 25.0  # Up to 25 points for safe passes
	
	# 3. Reasonable distance
	if distance > 5.0 and distance < 25.0:
		score += 15.0  # Good passing distance
	
	# 4. Assist potential
	if target_dist_to_goal < 20.0 and pressure < 0.4:
		score += 30.0  # Great assist opportunity
	
	return {"action": "kick", "force": force, "direction": dir_pass, "score": score}

# Evaluate dribbling option with immediate score
func _evaluate_dribbling(opps: Array) -> Dictionary:
	var team_dir: float = 1.0 if player.is_team_a else -1.0
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var player_pos: Vector3 = player.global_transform.origin
	
	# Dribble forward
	var dribble_dir: Vector3 = Vector3(team_dir, 0, 0).normalized()
	
	# Calculate immediate score (greedy evaluation)
	var score: float = 0.0
	
	# 1. Forward progress
	var current_dist: float = abs(player_pos.x - opponent_goal_x)
	var simulated_pos: Vector3 = player_pos + dribble_dir * 2.5
	var new_dist: float = abs(simulated_pos.x - opponent_goal_x)
	var progress: float = current_dist - new_dist
	score += progress * 8.0  # Reward forward movement
	
	# 2. Space from opponents
	var min_opp_dist: float = 999.0
	for opp in opps:
		var dist: float = simulated_pos.distance_to(opp.global_transform.origin)
		if dist < min_opp_dist:
			min_opp_dist = dist
	
	score += min_opp_dist * 4.0  # More space = better
	
	if min_opp_dist < 2.0:
		score -= 50.0  # Will collide with opponent
	
	# 3. Open space bonus
	if min_opp_dist > 5.0:
		score += 20.0  # Clear path ahead
	
	return {"action": "move", "direction": dribble_dir, "score": score}
