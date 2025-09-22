extends Node2D

@onready var field: Node2D = $Field
@onready var ball: CharacterBody2D = $Field/Ball
@onready var goal_left: Area2D = $Field/GoalLeft
@onready var goal_right: Area2D = $Field/GoalRight

var team_a: Node = null
var team_b: Node = null

var score_a: int = 0
var score_b: int = 0

const TEAM_SIZE := 5

func _ready() -> void:
	_setup_goals()
	_spawn_teams()
	_reset_kickoff()

func _setup_goals() -> void:
	goal_left.set_meta("team", "B")
	goal_right.set_meta("team", "A")
	goal_left.body_entered.connect(func(b): _on_goal_entered(b))
	goal_right.body_entered.connect(func(b): _on_goal_entered(b))

func _spawn_teams() -> void:
	var team_scene: PackedScene = load("res://scenes/Team.tscn")
	team_a = team_scene.instantiate()
	team_b = team_scene.instantiate()
	team_a.name = "TeamA"
	team_b.name = "TeamB"
	add_child(team_a)
	add_child(team_b)
	team_a.call_deferred("configure_team", true, ball)
	team_b.call_deferred("configure_team", false, ball)

func _reset_kickoff() -> void:
	ball.global_position = Vector2(640, 360)
	ball.velocity = Vector2.ZERO
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
