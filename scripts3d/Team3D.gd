extends Node3D

@onready var player_scene: PackedScene = load("res://scenes3d/Player3D.tscn")

var players: Array[CharacterBody3D] = []
var is_team_a: bool = true
var ball: CharacterBody3D

# Simplified 2x3 grid for 6-player formation
const GRID_COLS := 2
const GRID_ROWS := 3
@export var field_half_width_x: float = 60.0
@export var field_half_height_z: float = 35.0
var grid_cells: Array[Dictionary] = [] # each: {min_x,max_x,min_z,max_z,center:Vector3}

# Choose one non-GK player to be a rover (free to move all over field)
const ROVER_INDEX_DEFAULT := 5 # striker will be the rover

func configure_team(_is_team_a: bool, _ball: CharacterBody3D) -> void:
	is_team_a = _is_team_a
	ball = _ball
	_compute_grid_cells()
	_spawn_players()

func _spawn_players() -> void:
	for child in players:
		child.queue_free()
	players.clear()
	var roles := _formation_roles()
	var positions := _formation_positions()
	for i in roles.size():
		var p: CharacterBody3D = player_scene.instantiate()
		p.is_team_a = is_team_a
		p.role = roles[i]
		# Give player a proper name for debugging
		var team_name = "A" if is_team_a else "B"
		p.name = "Player_%s_%s_%d" % [team_name, roles[i], i]
		var ai := _make_ai_for_role(roles[i], i)
		add_child(p)
		p.global_transform.origin = positions[i]
		if p.has_method("set_home_position"):
			p.set_home_position(positions[i])
		p.setup(ball, ai)
		# tag by group for fuzzy pass
		p.add_to_group("team_a" if is_team_a else "team_b")
		# Add to players array for tracking
		players.append(p)
		# Team appearance is now handled by Player3D.setup_team_appearance() 
		# which is called from Player3D.setup()
		# Assign per-player grid bounds and staging, except rover and GK
		if roles[i] == "goalkeeper":
			# Keep GK near own goal; no grid constraint
			pass
		elif _is_rover(i):
			# Rover: no grid bounds, start near own half center line
			if p.has_method("set_staging_target") and grid_cells.size() == GRID_COLS * GRID_ROWS:
				var rover_start_x := (-field_half_width_x * 0.6) if is_team_a else (field_half_width_x * 0.6)
				p.global_transform.origin = Vector3(rover_start_x, 0.0, 0.0)
				p.set_staging_target(Vector3(0.0, 0.0, 0.0))
		else:
			if p.has_method("set_grid_bounds") and grid_cells.size() == GRID_COLS * GRID_ROWS:
				var grid_index := _grid_index_for_player(roles[i], i)
				var cell: Dictionary = grid_cells[grid_index]
				p.set_grid_bounds(cell["min_x"], cell["max_x"], cell["min_z"], cell["max_z"], cell["center"])
				# Stage players at sidelines initially, then move to grid centers on kickoff
				var center: Vector3 = cell["center"]
				var stage_x := -field_half_width_x + 1.5 if is_team_a else field_half_width_x - 1.5
				var stage_pos := Vector3(stage_x, 0.0, center.z)
				if p.has_method("set_staging_target"):
					p.set_staging_target(Vector3(center.x + (-2.0 if is_team_a else 2.0), 0.0, center.z))
				p.global_transform.origin = stage_pos
		players.append(p)

func _compute_grid_cells() -> void:
	grid_cells.clear()
	var total_w := field_half_width_x * 2.0
	var total_h := field_half_height_z * 2.0
	var cell_w := total_w / float(GRID_COLS)
	var cell_h := total_h / float(GRID_ROWS)
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var min_x := -field_half_width_x + c * cell_w
			var max_x := min_x + cell_w
			var min_z := -field_half_height_z + r * cell_h
			var max_z := min_z + cell_h
			var center := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
			grid_cells.append({
				"min_x": min_x,
				"max_x": max_x,
				"min_z": min_z,
				"max_z": max_z,
				"center": center,
			})

func _grid_index_for_player(role: String, index: int) -> int:
	# Simplified mapping for 6 players to 2x3 grid (6 cells)
	# Exclude GK (index 0) and rover (index 5)
	var mapping: Array[int] = [
		1, 2,  # defenders (back row)
		3, 4,  # midfielders (middle row) 
		5, 0   # striker + unused (front row)
	]
	# Convert player index to grid position
	if index == 0 or _is_rover(index):
		return 0  # GK and rover don't use grid
	var pos := index
	if index >= 6:
		pos = 5
	return (pos - 1) % (GRID_COLS * GRID_ROWS)

func _is_rover(index: int) -> bool:
	# Striker (index 5) is the rover
	return index == ROVER_INDEX_DEFAULT

func _formation_roles() -> Array:
	# 2-2-1 formation with GK (6 players total)
	return [
		"goalkeeper",
		"defender", "defender",
		"midfielder", "midfielder", 
		"striker"
	]

func _formation_positions() -> Array:
	# 6-player formation positions
	var team_dir := -1.0 if is_team_a else 1.0
	var base_x := -50.0 * team_dir
	var positions: Array = []
	
	# GK
	positions.append(Vector3(base_x, 0, 0))
	
	# Two defenders (back line)
	positions.append(Vector3(base_x + 15.0 * team_dir, 0, -12))
	positions.append(Vector3(base_x + 15.0 * team_dir, 0, 12))
	
	# Two midfielders (middle line)
	positions.append(Vector3(base_x + 35.0 * team_dir, 0, -12))
	positions.append(Vector3(base_x + 35.0 * team_dir, 0, 12))
	
	# One striker (front line)
	positions.append(Vector3(base_x + 50.0 * team_dir, 0, 0))
	
	return positions

func _make_ai_for_role(role: String, index: int) -> Node:
	# TEAM A: Classic/Simple AI (Less Advanced)
	# TEAM B: Advanced Search Algorithms (More Intelligent)
	
	if is_team_a:
		# ====== TEAM A: CLASSIC AI ======
		match role:
			"goalkeeper":
				return load("res://scripts3d/ai/Goalkeeper3D.gd").new()
			"defender":
				# Both defenders use classic fuzzy logic
				return load("res://scripts3d/ai/Defender3D.gd").new()
			"midfielder":
				# Both midfielders use Alpha-Beta (as "classic" baseline)
				return load("res://scripts3d/ai/Midfielder3DAlphaBeta.gd").new()
			"striker":
				# Striker uses classic AI
				return load("res://scripts3d/ai/Striker3DAStar.gd").new()
			_:
				return load("res://scripts3d/ai/Midfielder3DAlphaBeta.gd").new()
	else:
		# ====== TEAM B: ADVANCED AI ======
		match role:
			"goalkeeper":
				# Same goalkeeper for both teams
				return load("res://scripts3d/ai/Goalkeeper3D.gd").new()
			"defender":
				# Both defenders use DFS (Depth-First Search)
				return load("res://scripts3d/ai/Defender3DDFS.gd").new()
			"midfielder":
				# Index 3: Greedy Algorithm (quick decisions)
				# Index 4: BFS (Breadth-First Search)
				if index == 3:
					return load("res://scripts3d/ai/Midfielder3DGreedy.gd").new()
				else:  # index == 4
					return load("res://scripts3d/ai/Midfielder3DBFS.gd").new()
			"striker":
				# Hill Climbing (optimization-based)
				return load("res://scripts3d/ai/Striker3DHillClimb.gd").new()
			_:
				return load("res://scripts3d/ai/Midfielder3DBFS.gd").new()

func reset_positions(_kickoff_left: bool) -> void:
	var positions := _formation_positions()
	for i in players.size():
		var p: CharacterBody3D = players[i]
		# GK stays at formation spot near goal
		if p.role == "goalkeeper":
			p.global_transform.origin = positions[i]
			continue
		# Rover: reset to midfield in own half and no grid lock
		if _is_rover(i):
			var rover_x := (-field_half_width_x * 0.2) if is_team_a else (field_half_width_x * 0.2)
			p.global_transform.origin = Vector3(rover_x, 0.0, 0.0)
			continue
		# Grid players: move to their grid's center with slight side offset
		if p.has_method("set_grid_bounds") and grid_cells.size() == GRID_COLS * GRID_ROWS:
			var cell: Dictionary = grid_cells[_grid_index_for_player(p.role, i)]
			var side_offset_x := -2.0 if is_team_a else 2.0
			var center: Vector3 = cell["center"]
			p.global_transform.origin = Vector3(center.x + side_offset_x, 0.0, center.z)
