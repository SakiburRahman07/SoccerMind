extends Node3D

var field: Node3D = null
var ball: CharacterBody3D = null
var goal_left: Area3D = null
var goal_right: Area3D = null

var team_a: Node = null
var team_b: Node = null

var score_a: int = 0
var score_b: int = 0

func _ready() -> void:
	field = get_node_or_null("Field3D") as Node3D
	if field == null:
		push_warning("Field3D not found under Main3D")
		return
	ball = field.get_node_or_null("Ball") as CharacterBody3D
	goal_left = field.get_node_or_null("GoalLeft") as Area3D
	goal_right = field.get_node_or_null("GoalRight") as Area3D
	_setup_goals()
	_spawn_teams()
	_reset_kickoff()

func _setup_goals() -> void:
	if goal_left:
		goal_left.set_meta("team", "B")
		goal_left.body_entered.connect(func(b): _on_goal_entered(b))
	else:
		push_warning("GoalLeft not found in Field3D")
	if goal_right:
		goal_right.set_meta("team", "A")
		goal_right.body_entered.connect(func(b): _on_goal_entered(b))
	else:
		push_warning("GoalRight not found in Field3D")

func _spawn_teams() -> void:
	var team_scene: PackedScene = load("res://scenes3d/Team3D.tscn")
	team_a = team_scene.instantiate()
	team_b = team_scene.instantiate()
	team_a.name = "TeamA"
	team_b.name = "TeamB"
	add_child(team_a)
	add_child(team_b)
	team_a.call_deferred("configure_team", true, ball)
	team_b.call_deferred("configure_team", false, ball)

func _reset_kickoff() -> void:
	ball.global_transform.origin = Vector3(0, 1, 0)
	ball.velocity = Vector3.ZERO
	if team_a and team_b:
		team_a.call_deferred("reset_positions", true)
		team_b.call_deferred("reset_positions", false)

func _on_goal_entered(body: Node) -> void:
	if body != ball:
		return
	if goal_left and goal_left.get_overlapping_bodies().has(body):
		var goal_team: String = goal_left.get_meta("team")
		if goal_team == "A":
			score_b += 1
		else:
			score_a += 1
		_reset_kickoff()
		print("Score A:", score_a, " B:", score_b)
		return
	if goal_right and goal_right.get_overlapping_bodies().has(body):
		var goal_team_r: String = goal_right.get_meta("team")
		if goal_team_r == "A":
			score_b += 1
		else:
			score_a += 1
		_reset_kickoff()
		print("Score A:", score_a, " B:", score_b)
		return
