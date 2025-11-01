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
	# Move toward a lane that leads to better shot angle
	var team_dir: float = 1.0 if player.is_team_a else -1.0
	var lane: Vector3 = Vector3(team_dir, 0, clamp((ball.global_transform.origin.z - player.global_transform.origin.z) * 0.2, -1.0, 1.0))
	return {"action": "move", "direction": lane}

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
