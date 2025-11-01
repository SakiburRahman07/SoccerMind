extends Node

var player: Node
var ball: CharacterBody3D

# A* pathfinding node structure
class AStarNode:
	var grid_pos: Vector2i
	var g_score: float  # Cost from start to this node
	var h_score: float  # Heuristic estimate to goal
	var f_score: float  # g_score + h_score
	var came_from: Vector2i  # Previous node in path
	
	func _init(pos: Vector2i, g: float, h: float, from: Vector2i = Vector2i(-999, -999)):
		grid_pos = pos
		g_score = g
		h_score = h
		f_score = g + h
		came_from = from

func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	
	var dist_to_ball: float = player.global_transform.origin.distance_to(ball.global_transform.origin)
	
	# If close enough to ball, decide to shoot or pass
	if dist_to_ball < 4.0:
		var target_x: float = -58.0 if player.is_team_a else 58.0
		var distance_to_goal: float = abs(ball.global_transform.origin.x - target_x)
		
		# Shooting decision
		if distance_to_goal < 25.0:
			var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
			var keeper_z: float = 0.0
			var have_gk: bool = false
			for o in opps:
				if o is Player3D and o.role == "goalkeeper":
					keeper_z = o.global_transform.origin.z
					have_gk = true
					break
			
			var aim_z: float = ball.global_transform.origin.z
			if have_gk:
				var away_sign: float = 1.0 if (ball.global_transform.origin.z < keeper_z) else -1.0
				aim_z = clamp(keeper_z + away_sign * randf_range(8.0, 12.0), -30.0, 30.0)
			else:
				aim_z = clamp(ball.global_transform.origin.z + randf_range(-8.0, 8.0), -30.0, 30.0)
			
			var shot_dir: Vector3 = Vector3(target_x, 0.0, aim_z) - ball.global_transform.origin
			shot_dir.y = 1.5
			return {"action": "kick", "force": 20.0, "direction": shot_dir}
		
		# Pass decision using fuzzy logic
		var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
		var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((-1.0 if player.is_team_a else 1.0) * 6.0, 0, 0))
		var dir_pass: Vector3 = (target - ball.global_transform.origin)
		var distance: float = dir_pass.length()
		var min_opp: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(target)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		var force: float = fuzzy.decide_pass_force(distance, pressure)
		if pick.get("lob", false):
			dir_pass.y = 5.0
		return {"action": "kick", "force": force, "direction": dir_pass}
	
	# Use A* to find optimal path to ball or strategic position
	var path_direction: Vector3 = _astar_pathfinding()
	return {"action": "move", "direction": path_direction}

func _astar_pathfinding() -> Vector3:
	# Get grid cell size from player
	var grid_size: float = 4.0
	if player.has("grid_cell_size"):
		grid_size = player.get("grid_cell_size")
	
	# Determine target: prefer ball, but consider strategic positions
	var target_world: Vector3
	var target_x: float = -58.0 if player.is_team_a else 58.0
	var ball_pos: Vector3 = ball.global_transform.origin
	
	# Calculate distance to goal for decision
	var distance_to_goal: float = abs(ball_pos.x - target_x)
	
	# If ball is close to goal, try to get in optimal shooting position
	if distance_to_goal < 20.0:
		# Find optimal shooting position: ahead of ball toward goal
		var optimal_z: float = clamp(ball_pos.z + randf_range(-8.0, 8.0), -30.0, 30.0)
		target_world = Vector3(ball_pos.x - (5.0 if player.is_team_a else -5.0), 0.0, optimal_z)
	else:
		# Otherwise, pathfind to ball
		target_world = ball_pos
	
	# Convert to grid coordinates
	var start_grid: Vector2i = _world_to_grid(player.global_transform.origin, grid_size)
	var goal_grid: Vector2i = _world_to_grid(target_world, grid_size)
	
	# If already at goal grid, move toward target directly
	if start_grid == goal_grid:
		var to_target: Vector3 = target_world - player.global_transform.origin
		to_target.y = 0.0
		return to_target.normalized() if to_target.length() > 0.01 else Vector3.ZERO
	
	# Run A* search
	var path: Array[Vector2i] = _a_star_search(start_grid, goal_grid, grid_size)
	
	if path.size() == 0:
		# A* failed, fallback to direct movement
		var to_target: Vector3 = target_world - player.global_transform.origin
		to_target.y = 0.0
		return to_target.normalized() if to_target.length() > 0.01 else Vector3.ZERO
	
	# Get next step in path (first element after start)
	if path.size() > 1:
		var next_grid: Vector2i = path[1]
		var next_world: Vector3 = _grid_to_world(next_grid, grid_size)
		var direction: Vector3 = next_world - player.global_transform.origin
		direction.y = 0.0
		return direction.normalized() if direction.length() > 0.01 else Vector3.ZERO
	else:
		# Path only contains start, move directly to goal
		var to_target: Vector3 = target_world - player.global_transform.origin
		to_target.y = 0.0
		return to_target.normalized() if to_target.length() > 0.01 else Vector3.ZERO

func _a_star_search(start: Vector2i, goal: Vector2i, grid_size: float) -> Array[Vector2i]:
	# A* pathfinding implementation
	var open_set: Array[AStarNode] = []
	var closed_set: Dictionary = {}  # grid_pos -> true
	var came_from: Dictionary = {}  # grid_pos -> Vector2i (previous position)
	var g_score: Dictionary = {}  # grid_pos -> float
	var f_score: Dictionary = {}  # grid_pos -> float
	
	# Initialize start node
	var start_node: AStarNode = AStarNode.new(start, 0.0, _heuristic(start, goal), Vector2i(-999, -999))
	open_set.append(start_node)
	g_score[start] = 0.0
	f_score[start] = _heuristic(start, goal)
	
	var max_iterations: int = 200  # Prevent infinite loops
	var iterations: int = 0
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Find node with lowest f_score in open_set
		var current_node: AStarNode = null
		var current_index: int = -1
		var lowest_f: float = INF
		
		for i in range(open_set.size()):
			var node: AStarNode = open_set[i]
			if node.f_score < lowest_f:
				lowest_f = node.f_score
				current_node = node
				current_index = i
		
		if current_node == null:
			break
		
		# Remove current from open_set
		open_set.remove_at(current_index)
		var current: Vector2i = current_node.grid_pos
		
		# Add to closed set
		closed_set[current] = true
		
		# Check if we reached the goal
		if current == goal:
			# Reconstruct path
			return _reconstruct_path(came_from, start, goal)
		
		# Explore neighbors (4-directional movement)
		var neighbors: Array[Vector2i] = [
			Vector2i(current.x + 1, current.y),  # Right
			Vector2i(current.x - 1, current.y),  # Left
			Vector2i(current.x, current.y + 1),  # Up
			Vector2i(current.x, current.y - 1)   # Down
		]
		
		for neighbor in neighbors:
			# Skip if in closed set
			if closed_set.has(neighbor):
				continue
			
			# Calculate cost to reach neighbor
			var tentative_g: float = g_score[current] + _get_move_cost(current, neighbor, grid_size)
			
			# Check if this path to neighbor is better
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h: float = _heuristic(neighbor, goal)
				f_score[neighbor] = tentative_g + h
				
				# Add to open set if not already there
				var in_open: bool = false
				for node in open_set:
					if node.grid_pos == neighbor:
						node.g_score = tentative_g
						node.h_score = h
						node.f_score = f_score[neighbor]
						node.came_from = current
						in_open = true
						break
				
				if not in_open:
					var neighbor_node: AStarNode = AStarNode.new(neighbor, tentative_g, h, current)
					open_set.append(neighbor_node)
	
	# No path found
	return []

func _reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = goal
	
	while current != start and came_from.has(current):
		path.insert(0, current)
		current = came_from[current]
	
	path.insert(0, start)
	return path

func _heuristic(pos: Vector2i, goal: Vector2i) -> float:
	# Manhattan distance heuristic (good for grid-based movement)
	return abs(pos.x - goal.x) + abs(pos.y - goal.y)

func _get_move_cost(from: Vector2i, to: Vector2i, grid_size: float) -> float:
	# Base cost for moving to adjacent cell
	var base_cost: float = 1.0
	
	# Check for opponents in the target cell (higher cost)
	var to_world: Vector3 = _grid_to_world(to, grid_size)
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	
	var opponent_penalty: float = 0.0
	for opp in opps:
		if not opp is Player3D:
			continue
		var opp_pos: Vector3 = opp.global_transform.origin
		var dist: float = Vector3(opp_pos.x, 0.0, opp_pos.z).distance_to(Vector3(to_world.x, 0.0, to_world.z))
		if dist < grid_size * 0.7:  # Opponent nearby
			opponent_penalty += 2.0
	
	# Check field bounds (penalize moving too far outside)
	var field_half_width: float = 60.0
	var field_half_height: float = 35.0
	if abs(to_world.x) > field_half_width or abs(to_world.z) > field_half_height:
		opponent_penalty += 5.0
	
	return base_cost + opponent_penalty

func _world_to_grid(pos: Vector3, grid_size: float) -> Vector2i:
	return Vector2i(round(pos.x / grid_size), round(pos.z / grid_size))

func _grid_to_world(grid: Vector2i, grid_size: float) -> Vector3:
	return Vector3(float(grid.x) * grid_size, 0.0, float(grid.y) * grid_size)

