extends Node

var player: Node
var ball: CharacterBody3D

# True Hill-Climbing: Start with initial solution, iteratively move to better neighbors
func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	if to_ball.length() < 2.0:
		return _pick_shot_hill_climbing()
	
	# Use hill climbing for pathfinding to the ball
	var move_dir: Vector3 = _find_path_hill_climbing()
	return {"action": "move", "direction": move_dir}

# Hill Climbing for Pathfinding - Find optimal movement direction
func _find_path_hill_climbing() -> Vector3:
	var target_pos: Vector3 = ball.global_transform.origin
	var player_pos: Vector3 = player.global_transform.origin
	
	# Get opponents for obstacle avoidance
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	
	# Step 1: Initialize with direct path to ball
	var current_dir: Vector3 = (target_pos - player_pos).normalized()
	current_dir.y = 0.0  # Keep movement on ground plane
	var current_score: float = _path_score(current_dir, player_pos, target_pos, opps)
	
	# Hill Climbing parameters
	const MAX_ITERATIONS: int = 15
	const STEP_SIZE_INITIAL: float = 0.3  # Angular step size in radians
	var step_size: float = STEP_SIZE_INITIAL
	var improved: bool = true
	var iteration: int = 0
	
	# Step 2: Hill Climbing Loop
	while improved and iteration < MAX_ITERATIONS:
		improved = false
		iteration += 1
		
		# Step 3: Generate neighboring directions
		var neighbors: Array = _generate_path_neighbors(current_dir, step_size)
		
		# Step 4: Evaluate neighbors and find best one
		var best_neighbor: Vector3 = current_dir
		var best_neighbor_score: float = current_score
		
		for neighbor in neighbors:
			var score: float = _path_score(neighbor, player_pos, target_pos, opps)
			if score > best_neighbor_score:
				best_neighbor_score = score
				best_neighbor = neighbor
				improved = true
		
		# Step 5: Move to better neighbor
		if improved:
			current_dir = best_neighbor
			current_score = best_neighbor_score
		else:
			# Fine-tune with smaller steps
			step_size *= 0.5
			if step_size > 0.05:
				improved = true
	
	return current_dir

# Generate neighboring movement directions
func _generate_path_neighbors(current: Vector3, step_size: float) -> Array:
	var neighbors: Array = []
	
	# Convert current direction to angle
	var current_angle: float = atan2(current.z, current.x)
	
	# Generate 8 neighbors by rotating the direction
	for angle_offset in [-step_size * 2, -step_size, -step_size * 0.5, 0.0, step_size * 0.5, step_size, step_size * 2]:
		if angle_offset == 0.0:
			continue
		
		var new_angle: float = current_angle + angle_offset
		var neighbor: Vector3 = Vector3(cos(new_angle), 0.0, sin(new_angle)).normalized()
		neighbors.append(neighbor)
	
	return neighbors

# Score a movement direction (higher is better)
func _path_score(direction: Vector3, from_pos: Vector3, target_pos: Vector3, opps: Array) -> float:
	# Factor 1: Progress toward target (most important)
	var to_target: Vector3 = (target_pos - from_pos).normalized()
	to_target.y = 0.0
	var alignment: float = direction.dot(to_target)  # -1 to 1
	var progress_score: float = (alignment + 1.0) * 0.5  # Normalize to 0-1
	
	# Factor 2: Avoid opponents (obstacle avoidance)
	var next_pos: Vector3 = from_pos + direction * 3.0  # Look ahead 3 units
	var avoidance_score: float = 1.0
	
	for opp in opps:
		var opp_pos: Vector3 = opp.global_transform.origin
		var dist_to_opp: float = next_pos.distance_to(opp_pos)
		
		# Penalize paths that go too close to opponents
		if dist_to_opp < 5.0:
			var penalty: float = (5.0 - dist_to_opp) / 5.0  # 0 to 1
			avoidance_score -= penalty * 0.3
	
	avoidance_score = clamp(avoidance_score, 0.0, 1.0)
	
	# Factor 3: Avoid going backwards or sideways too much
	var team_dir: float = 1.0 if player.is_team_a else -1.0
	var forward_component: float = direction.x * team_dir
	var forward_score: float = clamp((forward_component + 1.0) * 0.5, 0.0, 1.0)
	
	# Weighted combination
	var total_score: float = progress_score * 0.6 + avoidance_score * 0.3 + forward_score * 0.1
	
	return total_score

# True Hill Climbing Algorithm
func _pick_shot_hill_climbing() -> Dictionary:
	var target_x: float = -58.0 if player.is_team_a else 58.0
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	
	# Step 1: Initialize with a reasonable starting solution (straight shot)
	var current_dir: Vector3 = Vector3(target_x - ball.global_transform.origin.x, 1.0, 0.0)
	var current_score: float = _shot_score(current_dir, opps)
	
	# Hill Climbing parameters
	const MAX_ITERATIONS: int = 20  # Maximum climbing iterations
	const STEP_SIZE_INITIAL: float = 3.0  # Initial step size for neighbor generation
	var step_size: float = STEP_SIZE_INITIAL
	var improved: bool = true
	var iteration: int = 0
	
	# Step 2: Hill Climbing Loop - Keep climbing until no improvement
	while improved and iteration < MAX_ITERATIONS:
		improved = false
		iteration += 1
		
		# Step 3: Generate neighbors around current solution
		var neighbors: Array = _generate_neighbors(current_dir, step_size)
		
		# Step 4: Evaluate all neighbors and find the best one
		var best_neighbor: Vector3 = current_dir
		var best_neighbor_score: float = current_score
		
		for neighbor in neighbors:
			var score: float = _shot_score(neighbor, opps)
			if score > best_neighbor_score:
				best_neighbor_score = score
				best_neighbor = neighbor
				improved = true  # Found better neighbor
		
		# Step 5: Move to better neighbor (climb uphill)
		if improved:
			current_dir = best_neighbor
			current_score = best_neighbor_score
		else:
			# No improvement - reduce step size and try again (fine-tuning)
			step_size *= 0.5
			if step_size > 0.3:  # Try smaller steps
				improved = true  # Continue with smaller steps
	
	# Calculate force based on shot characteristics
	var forwardness: float = clamp(abs(current_dir.x) / 60.0, 0.0, 1.0)
	var min_opp: float = 9999.0
	for o in opps:
		var d: float = o.global_transform.origin.distance_to(player.global_transform.origin)
		if d < min_opp:
			min_opp = d
	var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
	var force: float = clamp(22.0 + forwardness * 4.0 + pressure * 4.0, 18.0, 30.0)
	
	return {"action": "kick", "force": force, "direction": current_dir}

# Generate neighboring solutions (nearby shot directions)
func _generate_neighbors(current: Vector3, step_size: float) -> Array:
	var neighbors: Array = []
	
	# Explore 8 neighbors around current direction (like compass directions)
	# Vary y (height) and z (horizontal angle)
	for y_delta in [-step_size, 0.0, step_size]:
		for z_delta in [-step_size, 0.0, step_size]:
			if y_delta == 0.0 and z_delta == 0.0:
				continue  # Skip current position
			
			var neighbor: Vector3 = Vector3(
				current.x,  # Keep x direction (toward goal)
				clamp(current.y + y_delta, 0.0, 8.0),  # Adjust height
				clamp(current.z + z_delta, -12.0, 12.0)  # Adjust horizontal angle
			)
			neighbors.append(neighbor)
	
	return neighbors

func _shot_score(dir: Vector3, opps: Array) -> float:
	# Penalize shots near the goalkeeper; encourage corners/open space
	var adv: float = abs(dir.x)
	var lob_bonus: float = max(0.0, dir.y) * 0.25
	var pressure: float = 0.0
	var gk_penalty: float = 0.0
	var keeper_z: float = 0.0
	var have_gk: bool = false
	for o in opps:
		var to_o: Vector3 = o.global_transform.origin - ball.global_transform.origin
		pressure += clamp(1.0 - to_o.length() / 12.0, 0.0, 1.0)
		if o.has_method("get") and o.get("role") == "goalkeeper":
			keeper_z = o.global_transform.origin.z
			have_gk = true
	pressure = pressure / max(1, opps.size())
	if have_gk:
		var end_z: float = (ball.global_transform.origin + dir.normalized() * 8.0).z
		gk_penalty = clamp(1.0 - abs(end_z - keeper_z) / 10.0, 0.0, 1.0) * 0.6
	return adv * 0.8 + lob_bonus - pressure * 0.4 - gk_penalty
