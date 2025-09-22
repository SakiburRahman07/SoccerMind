extends Node3D

@onready var player_scene: PackedScene = load("res://scenes3d/Player3D.tscn")

var players: Array = []
var is_team_a: bool = true
var ball: CharacterBody3D

func configure_team(_is_team_a: bool, _ball: CharacterBody3D) -> void:
	is_team_a = _is_team_a
	ball = _ball
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
		var ai := _make_ai_for_role(roles[i])
		add_child(p)
		p.global_transform.origin = positions[i]
		if p.has_method("set_home_position"):
			p.set_home_position(positions[i])
		p.setup(ball, ai)
		# tag by group for fuzzy pass
		p.add_to_group("team_a" if is_team_a else "team_b")
		# Set team colors (A: blue, B: red) on all mesh parts
		var target_color := Color(0.2, 0.5, 1.0) if is_team_a else Color(1.0, 0.3, 0.3)
		for mesh_part in p.get_children():
			if mesh_part is MeshInstance3D:
				var mesh: MeshInstance3D = mesh_part
				if mesh.mesh:
					var existing := mesh.get_active_material(0)
					if existing == null:
						existing = mesh.mesh.surface_get_material(0)
					if existing:
						var mat = existing.duplicate()
						mat.albedo_color = target_color
						mesh.set_surface_override_material(0, mat)
		players.append(p)

func _formation_roles() -> Array:
	# 4-4-2 with GK
	return [
		"goalkeeper",
		"defender","defender","defender","defender",
		"midfielder","midfielder","midfielder","midfielder",
		"striker","striker"
	]

func _formation_positions() -> Array:
	var sign := 1.0 if is_team_a else -1.0
	var base_x := -45.0 * sign
	# GK
	var positions: Array = [ Vector3(base_x, 0, 0) ]
	# Back four
	positions.append(Vector3(base_x + 10.0 * sign, 0, -16))
	positions.append(Vector3(base_x + 10.0 * sign, 0, -5))
	positions.append(Vector3(base_x + 10.0 * sign, 0, 5))
	positions.append(Vector3(base_x + 10.0 * sign, 0, 16))
	# Mid four
	positions.append(Vector3(base_x + 28.0 * sign, 0, -16))
	positions.append(Vector3(base_x + 28.0 * sign, 0, -5))
	positions.append(Vector3(base_x + 28.0 * sign, 0, 5))
	positions.append(Vector3(base_x + 28.0 * sign, 0, 16))
	# Two strikers
	positions.append(Vector3(base_x + 45.0 * sign, 0, -6))
	positions.append(Vector3(base_x + 45.0 * sign, 0, 6))
	return positions

func _make_ai_for_role(role: String) -> Node:
	match role:
		"goalkeeper":
			return load("res://scripts3d/ai/Goalkeeper3D.gd").new()
		"defender":
			return load("res://scripts3d/ai/Defender3D.gd").new()
		"midfielder":
			if players.size() == 2:
				return load("res://scripts3d/ai/Midfielder3DBFS.gd").new()
			else:
				return load("res://scripts3d/ai/Midfielder3DGreedy.gd").new()
		"striker":
			return load("res://scripts3d/ai/Striker3D.gd").new()
		_:
			return load("res://scripts3d/ai/Midfielder3DGreedy.gd").new()

func reset_positions(_kickoff_left: bool) -> void:
	var positions := _formation_positions()
	for i in players.size():
		players[i].global_transform.origin = positions[i]
