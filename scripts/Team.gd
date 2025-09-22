extends Node2D

@onready var player_scene: PackedScene = load("res://scenes/Player.tscn")

var players: Array = []
var is_team_a: bool = true
var ball: CharacterBody2D

func configure_team(_is_team_a: bool, _ball: CharacterBody2D) -> void:
	is_team_a = _is_team_a
	ball = _ball
	_spawn_players()

func _spawn_players() -> void:
	for child in players:
		child.queue_free()
	players.clear()
	var roles := ["goalkeeper", "defender", "midfielder", "midfielder", "striker"]
	var positions := _default_positions()
	var ai_paths := _random_ai_selection(roles.size())
	for i in roles.size():
		var p: CharacterBody2D = player_scene.instantiate()
		p.is_team_a = is_team_a
		p.role = roles[i]
		p.global_position = positions[i]
		var ai := load(ai_paths[i]).new()
		add_child(p)
		p.setup(ball, ai)
		players.append(p)

func _default_positions() -> Array:
	var _offset_x: int = -200 if is_team_a else 200
	var side: Vector2 = Vector2(400, 360) if is_team_a else Vector2(880, 360)
	return [
		side + Vector2(-300, 0),
		side + Vector2(-200, 0),
		side + Vector2(-100, -80),
		side + Vector2(-100, 80),
		side + Vector2(0, 0)
	]

func _make_ai_for_role(role: String) -> Node:
	match role:
		"goalkeeper":
			return load("res://scripts/ai/GoalkeeperAlphaBeta.gd").new()
		"defender":
			return load("res://scripts/ai/DefenderDFS.gd").new()
		"midfielder":
			if players.size() == 2:
				return load("res://scripts/ai/MidfielderBFS.gd").new()
			else:
				return load("res://scripts/ai/MidfielderGreedy.gd").new()
		"striker":
			return load("res://scripts/ai/StrikerAStar.gd").new()
		_:
			return load("res://scripts/ai/MidfielderGreedy.gd").new()

func _random_ai_selection(count: int) -> Array:
	# Pool of 11 distinct AI algorithms
	var pool := [
		"res://scripts/ai/GoalkeeperAlphaBeta.gd",
		"res://scripts/ai/GoalkeeperGreedy.gd",
		"res://scripts/ai/DefenderDFS.gd",
		"res://scripts/ai/DefenderBFS.gd",
		"res://scripts/ai/MidfielderBFS.gd",
		"res://scripts/ai/MidfielderDFS.gd",
		"res://scripts/ai/MidfielderGreedy.gd",
		"res://scripts/ai/StrikerAStar.gd",
		"res://scripts/ai/StrikerGreedy.gd",
		"res://scripts/ai/StrikerHillClimb.gd"
	]
	pool.shuffle()
	if count <= pool.size():
		return pool.slice(0, count)
	# If ever more than pool size, wrap around
	var result: Array = []
	while result.size() < count:
		for path in pool:
			result.append(path)
			if result.size() >= count:
				break
	return result

func reset_positions(_kickoff_left: bool) -> void:
	var positions := _default_positions()
	for i in players.size():
		players[i].global_position = positions[i]
