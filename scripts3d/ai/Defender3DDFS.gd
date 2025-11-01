extends Node

var player: Node
var ball: CharacterBody3D

# DFS State Space: Different defensive zones/positions to explore
class DefensiveState:
	var position: Vector3
	var action_type: String  # "intercept", "mark", "cover", "pressure"
	var priority: float
	var depth: int
	
	func _init(pos: Vector3, act: String, pri: float, d: int = 0):
		position = pos
		action_type = act
		priority = pri
		depth = d

# True DFS: Explore decision tree depth-first (optimized for real-time)
func decide() -> Dictionary:
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	var goal_pos := Vector3(-58.0 if player.is_team_a else 58.0, 0, 0)
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	
	# Build decision tree using DFS with strict limits
	var stack: Array = []
	var visited: Dictionary = {}
	var best_state: DefensiveState = null
	var best_score: float = -INF
	
	# Performance limits
	const MAX_ITERATIONS: int = 50  # Limit total states explored
	const MAX_DEPTH: int = 2  # Limit tree depth
	var iterations: int = 0
	
	# Initialize root states (different strategic options)
	_generate_initial_states(stack, goal_pos)
	
	# DFS traversal with performance safeguards
	while not stack.is_empty() and iterations < MAX_ITERATIONS:
		iterations += 1
		var state: DefensiveState = stack.pop_back()
		var state_key: String = _get_state_key(state.position)
		
		if visited.has(state_key):
			continue
		visited[state_key] = true
		
		# Evaluate this state
		var score: float = _evaluate_defensive_state(state, goal_pos, opps)
		
		if score > best_score:
			best_score = score
			best_state = state
		
		# Generate child states only if within depth limit
		if state.depth < MAX_DEPTH:
			_expand_state(state, stack, goal_pos, opps)
	
	# Execute best found state
	if best_state:
		return _execute_state(best_state)
	
	# Fallback
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	return {"action": "move", "direction": (home - player.global_transform.origin).normalized()}

# Generate initial defensive options (root nodes)
func _generate_initial_states(stack: Array, goal_pos: Vector3) -> void:
	var ball_pos := ball.global_transform.origin
	var to_ball := ball_pos - goal_pos
	to_ball.y = 0.0
	
	# Option 1: Direct ball interception
	var intercept_pos := goal_pos + to_ball * 0.5
	stack.push_back(DefensiveState.new(intercept_pos, "intercept", 1.0, 0))
	
	# Option 2: Mark dangerous opponent (only closest one for performance)
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	var closest_opp = null
	var closest_dist: float = 999.0
	for opp in opps:
		var dist: float = opp.global_transform.origin.distance_to(ball_pos)
		if dist < 10.0 and dist < closest_dist:
			closest_opp = opp
			closest_dist = dist
	
	if closest_opp:
		stack.push_back(DefensiveState.new(closest_opp.global_transform.origin, "mark", 0.8, 0))
	
	# Option 3: Cover defensive zone
	var cover_pos := goal_pos + to_ball.normalized() * 15.0
	stack.push_back(DefensiveState.new(cover_pos, "cover", 0.6, 0))
	
	# Option 4: Aggressive pressure
	stack.push_back(DefensiveState.new(ball_pos, "pressure", 0.9, 0))

# Expand a state into child states (DFS branching) - Optimized for performance
func _expand_state(state: DefensiveState, stack: Array, goal_pos: Vector3, opps: Array) -> void:
	var next_depth: int = state.depth + 1
	
	match state.action_type:
		"intercept":
			# Branch: fewer intercept angles for performance
			var base := state.position
			for angle in [-0.3, 0.3]:  # Reduced from 3 to 2 branches
				var offset := Vector3(cos(angle) * 2.0, 0, sin(angle) * 2.0)
				stack.push_back(DefensiveState.new(base + offset, "intercept", state.priority * 0.9, next_depth))
		
		"mark":
			# Branch: single optimal marking distance
			var dir := (ball.global_transform.origin - state.position).normalized()
			stack.push_back(DefensiveState.new(state.position + dir * 2.0, "mark", state.priority * 0.85, next_depth))
		
		"cover":
			# Branch: reduced passing lanes
			for z_offset in [-3.0, 3.0]:  # Reduced from 3 to 2 branches
				var pos := state.position + Vector3(0, 0, z_offset)
				stack.push_back(DefensiveState.new(pos, "cover", state.priority * 0.8, next_depth))
		
		"pressure":
			# Branch: single aggressive approach
			var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
			stack.push_back(DefensiveState.new(
				player.global_transform.origin + to_ball * 0.7,
				"pressure",
				state.priority * 0.95,
				next_depth
			))

# Evaluate how good a defensive state is
func _evaluate_defensive_state(state: DefensiveState, goal_pos: Vector3, opps: Array) -> float:
	var score := state.priority * 100.0
	var pos := state.position
	
	# Distance to ball (closer is better for pressure/intercept)
	var dist_to_ball := pos.distance_to(ball.global_transform.origin)
	score -= dist_to_ball * 2.0
	
	# Distance to goal (stay between ball and goal)
	var ball_to_goal := ball.global_transform.origin.distance_to(goal_pos)
	var state_to_goal := pos.distance_to(goal_pos)
	if state_to_goal < ball_to_goal:
		score += 20.0  # Good defensive position
	
	# Opponent proximity
	for opp in opps:
		var dist_to_opp := pos.distance_to(opp.global_transform.origin)
		if dist_to_opp < 3.0:
			score += 15.0  # Close marking bonus
	
	# Formation keeping
	var home: Vector3 = player.home_position if player.has_method("set_home_position") else player.global_transform.origin
	var dist_from_home := pos.distance_to(home)
	score -= dist_from_home * 0.5
	
	return score

# Execute the chosen defensive state
func _execute_state(state: DefensiveState) -> Dictionary:
	var to_target: Vector3 = state.position - player.global_transform.origin
	
	# If close to ball, kick it away
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 1.8:
		var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
		var pass_target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((-1.0 if player.is_team_a else 1.0) * 5.0, 0, 0))
		
		var dir_pass: Vector3 = (pass_target - ball.global_transform.origin)
		var min_opp: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(pass_target)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		
		if pressure < 0.7:
			var distance: float = dir_pass.length()
			var force_pass: float = fuzzy.decide_pass_force(distance, pressure)
			return {"action": "kick", "force": force_pass, "direction": dir_pass}
		
		# Clear ball
		var team_dir := -1.0 if player.is_team_a else 1.0
		return {"action": "kick", "force": 18.0, "direction": Vector3(team_dir * 10.0, 0, randf_range(-6.0, 6.0))}
	
	# Move toward target
	return {"action": "move", "direction": to_target.normalized()}

func _get_state_key(pos: Vector3) -> String:
	return "%d_%d_%d" % [int(pos.x), int(pos.y), int(pos.z)]
