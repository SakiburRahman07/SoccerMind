extends Node

var player: Node
var ball: CharacterBody3D

# Game state for alpha-beta search
class GameState:
	var ball_pos: Vector3
	var player_pos: Vector3
	var action: Dictionary
	var is_maximizing: bool
	
	func _init(b_pos: Vector3, p_pos: Vector3, act: Dictionary, maximizing: bool):
		ball_pos = b_pos
		player_pos = p_pos
		action = act
		is_maximizing = maximizing

# True Alpha-Beta pruning with minimax over action tree
# Explores: pass to different teammates, dribble directions, shoot
func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	
	if to_ball.length() < 2.0:
		# Use alpha-beta to find best action
		var best_action: Dictionary = _alpha_beta_search(mates, opps)
		return best_action
	
	# Otherwise move toward advantageous lane
	return {"action": "move", "direction": _lane_seek()}

# Alpha-Beta search entry point
func _alpha_beta_search(mates: Array, opps: Array) -> Dictionary:
	const MAX_DEPTH: int = 3  # Search depth
	var alpha: float = -INF
	var beta: float = INF
	
	# Generate all possible actions
	var possible_actions: Array = _generate_actions(mates, opps)
	
	var best_action: Dictionary = {"action": "idle"}
	var best_value: float = -INF
	
	# Maximize over our actions
	for action in possible_actions:
		var state: GameState = GameState.new(
			ball.global_transform.origin,
			player.global_transform.origin,
			action,
			true
		)
		
		# Simulate opponent response (minimize)
		var value: float = _minimax(state, MAX_DEPTH - 1, alpha, beta, false, mates, opps)
		
		if value > best_value:
			best_value = value
			best_action = action
		
		alpha = max(alpha, value)
		
		# Alpha-beta pruning: if we found something better than beta, prune
		if beta <= alpha:
			break  # Beta cutoff
	
	return best_action

# Minimax with Alpha-Beta pruning
func _minimax(state: GameState, depth: int, alpha: float, beta: float, is_maximizing: bool, mates: Array, opps: Array) -> float:
	# Terminal condition
	if depth == 0:
		return _eval_state_full(state, mates, opps)
	
	if is_maximizing:
		var max_eval: float = -INF
		var actions: Array = _generate_actions(mates, opps)
		
		for action in actions:
			var new_state: GameState = _simulate_action(state, action, true)
			var eval: float = _minimax(new_state, depth - 1, alpha, beta, false, mates, opps)
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			
			# Alpha-Beta pruning
			if beta <= alpha:
				break  # Beta cutoff - prune remaining branches
		
		return max_eval
	else:
		# Minimizing (opponent's turn)
		var min_eval: float = INF
		var opp_actions: Array = _generate_opponent_actions(opps)
		
		for action in opp_actions:
			var new_state: GameState = _simulate_action(state, action, false)
			var eval: float = _minimax(new_state, depth - 1, alpha, beta, true, mates, opps)
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			
			# Alpha-Beta pruning
			if beta <= alpha:
				break  # Alpha cutoff - prune remaining branches
		
		return min_eval

# Generate all possible actions for midfielder
func _generate_actions(mates: Array, opps: Array) -> Array:
	var actions: Array = []
	
	# 1. Pass actions to different teammates
	for mate in mates:
		if mate == player:
			continue
		var pass_action: Dictionary = _create_pass_action(mate, opps)
		actions.append(pass_action)
		
		# Limit to 3 best pass options for performance
		if actions.size() >= 3:
			break
	
	# 2. Dribble in different directions
	for angle in [-0.5, 0.0, 0.5]:
		var dribble_action: Dictionary = _create_dribble_action(angle)
		actions.append(dribble_action)
	
	# 3. Shoot if close to goal
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var distance_to_goal: float = abs(ball.global_transform.origin.x - opponent_goal_x)
	if distance_to_goal < 30.0:
		var shoot_action: Dictionary = _create_shoot_action()
		actions.append(shoot_action)
	
	return actions

# Generate opponent's possible responses
func _generate_opponent_actions(opps: Array) -> Array:
	var actions: Array = []
	
	# Simulate opponent trying to intercept or pressure
	for i in range(min(2, opps.size())):  # Limit for performance
		if i < opps.size():
			var opp = opps[i]
			var intercept: Dictionary = {
				"action": "opponent_move",
				"target": ball.global_transform.origin
			}
			actions.append(intercept)
	
	return actions

# Simulate an action and return new state
func _simulate_action(state: GameState, action: Dictionary, is_our_team: bool) -> GameState:
	var new_ball_pos: Vector3 = state.ball_pos
	var new_player_pos: Vector3 = state.player_pos
	
	match action.get("action", ""):
		"kick":
			# Simulate ball movement
			var direction: Vector3 = action.get("direction", Vector3.ZERO)
			var force: float = action.get("force", 10.0)
			new_ball_pos = state.ball_pos + direction.normalized() * (force * 0.5)
		"move":
			# Simulate player movement
			var direction: Vector3 = action.get("direction", Vector3.ZERO)
			new_player_pos = state.player_pos + direction.normalized() * 2.0
		"opponent_move":
			# Opponent doesn't change our state directly
			pass
	
	return GameState.new(new_ball_pos, new_player_pos, action, is_our_team)

# Create pass action to specific teammate
func _create_pass_action(mate: Node, opps: Array) -> Dictionary:
	var target: Vector3 = mate.global_transform.origin
	var dir_pass: Vector3 = target - ball.global_transform.origin
	
	# Calculate pressure
	var min_opp: float = 9999.0
	for o in opps:
		var d: float = o.global_transform.origin.distance_to(target)
		if d < min_opp:
			min_opp = d
	var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
	
	var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
	var distance: float = dir_pass.length()
	var force: float = fuzzy.decide_pass_force(distance, pressure)
	
	return {"action": "kick", "force": force, "direction": dir_pass, "target_pos": target}

# Create dribble action
func _create_dribble_action(angle: float) -> Dictionary:
	var team_dir: float = 1.0 if player.is_team_a else -1.0
	var forward: Vector3 = Vector3(team_dir * 1.0, 0, angle)
	return {"action": "move", "direction": forward.normalized()}

# Create shoot action
func _create_shoot_action() -> Dictionary:
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var to_goal: Vector3 = Vector3(opponent_goal_x, 0, 0) - ball.global_transform.origin
	to_goal.y = 1.2
	return {"action": "kick", "force": 18.0, "direction": to_goal}

# Evaluate game state (heuristic function)
func _eval_state_full(state: GameState, mates: Array, opps: Array) -> float:
	var score: float = 0.0
	var ball_pos: Vector3 = state.ball_pos
	
	# 1. Field advancement (closer to opponent goal is better)
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var our_goal_x: float = 58.0 if player.is_team_a else -58.0
	var progress: float = abs(ball_pos.x - our_goal_x) / 116.0  # Normalized 0-1
	score += progress * 30.0
	
	# 2. Distance to opponent goal
	var dist_to_opp_goal: float = abs(ball_pos.x - opponent_goal_x)
	score -= dist_to_opp_goal * 0.3
	
	# 3. Opponent pressure (lower is better)
	var min_opp_dist: float = 9999.0
	for opp in opps:
		var d: float = ball_pos.distance_to(opp.global_transform.origin)
		if d < min_opp_dist:
			min_opp_dist = d
	score += min_opp_dist * 2.0  # More space from opponents is good
	
	# 4. Teammate support (closer teammates are better)
	var avg_mate_dist: float = 0.0
	var mate_count: int = 0
	for mate in mates:
		if mate != player:
			avg_mate_dist += ball_pos.distance_to(mate.global_transform.origin)
			mate_count += 1
	if mate_count > 0:
		avg_mate_dist /= mate_count
		score += (30.0 - avg_mate_dist) * 0.5  # Closer support is better
	
	# 5. Bonus for shooting opportunities
	if dist_to_opp_goal < 20.0:
		score += 15.0
	
	# 6. Penalty for being near sidelines
	var z_penalty: float = max(0.0, abs(ball_pos.z) - 15.0)
	score -= z_penalty * 0.5
	
	return score

	return score

func _lane_seek() -> Vector3:
	var target_x: float = 30.0 * (1.0 if player.is_team_a else -1.0)
	var aim: Vector3 = Vector3(target_x, 0, clamp(ball.global_transform.origin.z, -12.0, 12.0))
	return (aim - player.global_transform.origin).normalized()
