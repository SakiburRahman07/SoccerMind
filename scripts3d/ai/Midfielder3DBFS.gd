extends Node

var player: Node
var ball: CharacterBody3D

# BFS State: represents a possible action and resulting game state
class BFSState:
	var position: Vector3  # Ball position after action
	var action: Dictionary  # The action taken
	var score: float  # Heuristic score
	var depth: int  # Level in BFS tree
	
	func _init(pos: Vector3, act: Dictionary, scr: float, d: int):
		position = pos
		action = act
		score = scr
		depth = d

# True BFS: Explore actions level-by-level (breadth-first)
func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	
	# If not close to ball, move toward it with formation keeping
	if player.global_transform.origin.distance_to(ball.global_transform.origin) >= 2.5:
		var target: Vector3 = Vector3(ball.global_transform.origin.x, 0, clamp(ball.global_transform.origin.z, -20.0, 20.0))
		var desire: Vector3 = (target - player.global_transform.origin)
		var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.4
		var dir: Vector3 = (desire + keep_shape).normalized()
		return {"action": "move", "direction": dir}
	
	# Use BFS to find best action when close to ball
	var best_action: Dictionary = _bfs_search()
	return best_action

# BFS Search: Explore all actions level by level
func _bfs_search() -> Dictionary:
	var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	
	# BFS uses a QUEUE (FIFO - First In First Out)
	var queue: Array = []
	var visited: Dictionary = {}
	var best_state: BFSState = null
	var best_score: float = -INF
	
	# Performance limits
	const MAX_ITERATIONS: int = 60
	const MAX_DEPTH: int = 2
	var iterations: int = 0
	
	# Generate initial states (level 0)
	_generate_initial_states(queue, mates, opps)
	
	# BFS traversal - process queue from front (FIFO)
	while queue.size() > 0 and iterations < MAX_ITERATIONS:
		iterations += 1
		
		# Dequeue from FRONT (this is what makes it BFS!)
		var state: BFSState = queue.pop_front()
		
		var state_key: String = _get_state_key(state.position)
		if visited.has(state_key):
			continue
		visited[state_key] = true
		
		# Evaluate this state
		var score: float = _evaluate_action(state, mates, opps)
		state.score = score
		
		if score > best_score:
			best_score = score
			best_state = state
		
		# Expand state if within depth limit
		if state.depth < MAX_DEPTH:
			_expand_state(state, queue, mates, opps)
	
	# Return best action found
	if best_state:
		return best_state.action
	
	# Fallback: simple pass
	var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
	var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
	var pass_target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((-1.0 if player.is_team_a else 1.0) * 6.0, 0, 0))
	var dir_pass: Vector3 = (pass_target - ball.global_transform.origin)
	return {"action": "kick", "force": 12.0, "direction": dir_pass}

# Generate initial action states (level 0 of BFS tree)
func _generate_initial_states(queue: Array, mates: Array, opps: Array) -> void:
	var ball_pos: Vector3 = ball.global_transform.origin
	
	# 1. Shooting actions (if in range)
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var distance_to_goal: float = abs(ball_pos.x - opponent_goal_x)
	
	if distance_to_goal < 30.0:
		var to_goal: Vector3 = Vector3(opponent_goal_x, 0, 0) - ball_pos
		var angle_cos: float = (to_goal.normalized().dot(Vector3(1.0 if not player.is_team_a else -1.0, 0, 0)))
		if angle_cos > 0.3:
			# Try different shot angles
			for angle_offset in [-0.2, 0.0, 0.2]:
				var shot_dir: Vector3 = to_goal.rotated(Vector3.UP, angle_offset)
				shot_dir.y = 1.2
				var shot_action: Dictionary = {"action": "kick", "force": 18.0, "direction": shot_dir}
				var shot_pos: Vector3 = _simulate_ball_movement(ball_pos, shot_dir, 18.0)
				queue.push_back(BFSState.new(shot_pos, shot_action, 0.0, 0))
	
	# 2. Pass actions to teammates
	var pass_count: int = 0
	for mate in mates:
		if mate == player:
			continue
		if pass_count >= 3:  # Limit for performance
			break
		
		var pass_target: Vector3 = mate.global_transform.origin
		var dir_pass: Vector3 = pass_target - ball_pos
		
		# Calculate pressure and force
		var min_opp: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(pass_target)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var force: float = fuzzy.decide_pass_force(dir_pass.length(), pressure)
		
		var pass_action: Dictionary = {"action": "kick", "force": force, "direction": dir_pass}
		var pass_pos: Vector3 = _simulate_ball_movement(ball_pos, dir_pass, force)
		queue.push_back(BFSState.new(pass_pos, pass_action, 0.0, 0))
		pass_count += 1
	
	# 3. Dribble actions
	var team_dir: float = 1.0 if player.is_team_a else -1.0
	for z_angle in [-0.4, 0.0, 0.4]:
		var dribble_dir: Vector3 = Vector3(team_dir, 0, z_angle).normalized()
		var dribble_action: Dictionary = {"action": "move", "direction": dribble_dir}
		var dribble_pos: Vector3 = player.global_transform.origin + dribble_dir * 2.0
		queue.push_back(BFSState.new(dribble_pos, dribble_action, 0.0, 0))

# Expand a state into next level states (BFS expansion)
func _expand_state(state: BFSState, queue: Array, mates: Array, opps: Array) -> void:
	var next_depth: int = state.depth + 1
	var current_pos: Vector3 = state.position
	
	# From this position, what are follow-up actions?
	match state.action.get("action", ""):
		"kick":
			# After a pass/shot, consider receiving player's options
			# Simplified: add a few follow-up passes
			for mate in mates:
				if mate == player:
					continue
				var next_pass_target: Vector3 = mate.global_transform.origin
				var next_dir: Vector3 = next_pass_target - current_pos
				if next_dir.length() > 5.0 and next_dir.length() < 25.0:  # Reasonable distance
					var next_action: Dictionary = {"action": "kick", "force": 12.0, "direction": next_dir}
					var next_pos: Vector3 = _simulate_ball_movement(current_pos, next_dir, 12.0)
					queue.push_back(BFSState.new(next_pos, next_action, 0.0, next_depth))
					break  # Only one follow-up per state for performance
		
		"move":
			# After dribbling, consider pass or shot
			var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
			var dist_to_goal: float = abs(current_pos.x - opponent_goal_x)
			
			if dist_to_goal < 25.0:
				# Try shooting
				var to_goal: Vector3 = Vector3(opponent_goal_x, 0, 0) - current_pos
				to_goal.y = 1.0
				var shoot_action: Dictionary = {"action": "kick", "force": 16.0, "direction": to_goal}
				var shoot_pos: Vector3 = _simulate_ball_movement(current_pos, to_goal, 16.0)
				queue.push_back(BFSState.new(shoot_pos, shoot_action, 0.0, next_depth))
			else:
				# Try passing
				for mate in mates:
					if mate == player:
						continue
					var pass_dir: Vector3 = mate.global_transform.origin - current_pos
					if pass_dir.length() < 20.0:
						var pass_action: Dictionary = {"action": "kick", "force": 10.0, "direction": pass_dir}
						var pass_pos: Vector3 = _simulate_ball_movement(current_pos, pass_dir, 10.0)
						queue.push_back(BFSState.new(pass_pos, pass_action, 0.0, next_depth))
						break

# Evaluate the quality of an action
func _evaluate_action(state: BFSState, mates: Array, opps: Array) -> float:
	var score: float = 0.0
	var pos: Vector3 = state.position
	
	# 1. Field advancement (progress toward opponent goal)
	var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
	var our_goal_x: float = 58.0 if player.is_team_a else -58.0
	var progress: float = (abs(pos.x - our_goal_x) / 116.0)  # 0-1 normalized
	score += progress * 40.0
	
	# 2. Distance to opponent goal (closer is better)
	var dist_to_goal: float = abs(pos.x - opponent_goal_x)
	score -= dist_to_goal * 0.4
	
	# 3. Shooting bonus
	if state.action.get("action", "") == "kick" and dist_to_goal < 20.0:
		var direction: Vector3 = state.action.get("direction", Vector3.ZERO)
		if direction.y > 0.5:  # Has lift (shot)
			score += 25.0
	
	# 4. Safety from opponents
	var min_opp_dist: float = 9999.0
	for opp in opps:
		var d: float = pos.distance_to(opp.global_transform.origin)
		if d < min_opp_dist:
			min_opp_dist = d
	score += min_opp_dist * 1.5  # More space is better
	
	# 5. Teammate support
	var close_mates: int = 0
	for mate in mates:
		if mate != player:
			var d: float = pos.distance_to(mate.global_transform.origin)
			if d < 15.0:
				close_mates += 1
	score += close_mates * 3.0
	
	# 6. Avoid sidelines
	var z_penalty: float = max(0.0, abs(pos.z) - 18.0)
	score -= z_penalty * 2.0
	
	# 7. Depth bonus (reward planning ahead)
	score += state.depth * 2.0
	
	return score

# Simulate where ball ends up after action
func _simulate_ball_movement(current_pos: Vector3, direction: Vector3, force: float) -> Vector3:
	var normalized_dir: Vector3 = direction.normalized()
	var distance: float = force * 0.6  # Simplified physics
	var new_pos: Vector3 = current_pos + normalized_dir * distance
	
	# Clamp to field boundaries
	new_pos.x = clamp(new_pos.x, -58.0, 58.0)
	new_pos.z = clamp(new_pos.z, -30.0, 30.0)
	new_pos.y = 0.0
	
	return new_pos

# Generate state key for visited tracking
func _get_state_key(pos: Vector3) -> String:
	return "%d_%d_%d" % [int(pos.x), int(pos.y), int(pos.z)]
