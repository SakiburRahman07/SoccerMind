extends Node3D

@onready var player_scene: PackedScene = load("res://scenes3d/Player3D.tscn")

var players: Array[CharacterBody3D] = []
var is_team_a: bool = true
var ball: CharacterBody3D

# 3x3 grid over field for player assignment
const GRID_COLS := 3
const GRID_ROWS := 3
@export var field_half_width_x: float = 60.0
@export var field_half_height_z: float = 35.0
var grid_cells: Array[Dictionary] = [] # each: {min_x,max_x,min_z,max_z,center:Vector3}

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
		var ai := _make_ai_for_role(roles[i], i)
		add_child(p)
		p.global_transform.origin = positions[i]
		if p.has_method("set_home_position"):
			p.set_home_position(positions[i])
		p.setup(ball, ai)
		# tag by group for fuzzy pass
		p.add_to_group("team_a" if is_team_a else "team_b")
		# Set kit colors: Outfield (A: blue, B: red). Goalkeeper: high-visibility yellow/green
		var target_color := Color(0.2, 0.5, 1.0) if is_team_a else Color(1.0, 0.3, 0.3)
		if roles[i] == "goalkeeper":
			# Common GK kits are bright for visibility (inspired by football uniforms)
			target_color = Color(1.0, 0.9, 0.2)
		for mesh_part in p.get_children():
			if mesh_part is MeshInstance3D:
				var mesh: MeshInstance3D = mesh_part
				if mesh.mesh:
					# Try active override, then surface material (ArrayMesh), then PrimitiveMesh material
					var existing := mesh.get_active_material(0)
					if existing == null:
						existing = mesh.mesh.surface_get_material(0)
					if existing == null and mesh.mesh.has_method("get") and mesh.mesh.has_property("material"):
						existing = mesh.mesh.material
					# Duplicate if we found one; otherwise create a fresh StandardMaterial3D
					var mat: Material = null
					if existing != null:
						mat = existing.duplicate()
					else:
						mat = StandardMaterial3D.new()
					# Apply kit color and set override
					if mat is StandardMaterial3D:
						mat.albedo_color = target_color
					mesh.set_surface_override_material(0, mat)
		# Assign per-player grid bounds and adjust initial placement to grid centers
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
			# Keep GK near goal and center player near middle from the start
			if roles[i] != "goalkeeper" and not _is_center_player(i):
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
	# Reserve center cell (row 1, col 1) for designated center player, GK stays near goal
	if role == "goalkeeper":
		# left goal for Team B, right goal for Team A → map to near-goal column
		return (1 * GRID_COLS) + (2 if is_team_a else 0)
	if _is_center_player(index):
		return (1 * GRID_COLS) + 1
	# Distribute others across remaining cells in row-major order skipping center column if GK used it
	var order: Array = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var idx := r * GRID_COLS + c
			# skip GK column on own half front row? keep simple: include all
			order.append(idx)
	# Simple round-robin based on player index
	return order[(index + (1 if is_team_a else 0)) % order.size()]

func _is_center_player(index: int) -> bool:
	# Choose one midfielder as the center player: the first midfielder in list
	return index == 6 # based on formation ordering above

func _formation_roles() -> Array:
	# 4-4-2 with GK
	return [
		"goalkeeper",
		"defender","defender","defender","defender",
		"midfielder","midfielder","midfielder","midfielder",
		"striker","striker"
	]

func _formation_positions() -> Array:
	# Flip halves: Team A now starts on +X, Team B on -X
	var team_dir := -1.0 if is_team_a else 1.0
	var base_x := -45.0 * team_dir
	# GK
	var positions: Array = [ Vector3(base_x, 0, 0) ]
	# Back four
	positions.append(Vector3(base_x + 10.0 * team_dir, 0, -16))
	positions.append(Vector3(base_x + 10.0 * team_dir, 0, -5))
	positions.append(Vector3(base_x + 10.0 * team_dir, 0, 5))
	positions.append(Vector3(base_x + 10.0 * team_dir, 0, 16))
	# Mid four
	positions.append(Vector3(base_x + 28.0 * team_dir, 0, -16))
	positions.append(Vector3(base_x + 28.0 * team_dir, 0, -5))
	positions.append(Vector3(base_x + 28.0 * team_dir, 0, 5))
	positions.append(Vector3(base_x + 28.0 * team_dir, 0, 16))
	# Two strikers
	positions.append(Vector3(base_x + 45.0 * team_dir, 0, -6))
	positions.append(Vector3(base_x + 45.0 * team_dir, 0, 6))
	return positions

func _make_ai_for_role(role: String, index: int) -> Node:
	match role:
		"goalkeeper":
			return load("res://scripts3d/ai/Goalkeeper3D.gd").new()
		"defender":
			# Mix classic and DFS defenders
			return load("res://scripts3d/ai/Defender3DDFS.gd" if (index % 2 == 1) else "res://scripts3d/ai/Defender3D.gd").new()
		"midfielder":
			# Rotate between Greedy, BFS, and AlphaBeta
			var pool := [
				"res://scripts3d/ai/Midfielder3DGreedy.gd",
				"res://scripts3d/ai/Midfielder3DBFS.gd",
				"res://scripts3d/ai/Midfielder3DAlphaBeta.gd"
			]
			return load(pool[index % pool.size()]).new()
		"striker":
			# Alternate between baseline and hill-climbing striker
			return load("res://scripts3d/ai/Striker3DHillClimb.gd" if (index % 2 == 1) else "res://scripts3d/ai/Striker3D.gd").new()
		_:
			return load("res://scripts3d/ai/Midfielder3DGreedy.gd").new()

func reset_positions(_kickoff_left: bool) -> void:
	var positions := _formation_positions()
	for i in players.size():
		var p: CharacterBody3D = players[i]
		p.global_transform.origin = positions[i]
		# Re-apply grid center positioning for non-GK, non-center
		if p.has_method("set_grid_bounds") and grid_cells.size() == GRID_COLS * GRID_ROWS:
			if p.role != "goalkeeper" and not _is_center_player(i):
				var cell: Dictionary = grid_cells[_grid_index_for_player(p.role, i)]
				var side_offset_x := -2.0 if is_team_a else 2.0
				var center: Vector3 = cell["center"]
				p.global_transform.origin = Vector3(center.x + side_offset_x, 0.0, center.z)
