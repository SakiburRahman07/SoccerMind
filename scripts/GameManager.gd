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
const FIELD_BOUNDS_MIN := Vector2(32, 16)
const FIELD_BOUNDS_MAX := Vector2(1248, 704)

# Match and HUD state
var match_duration_seconds: float = 120.0
var time_left_seconds: float = 0.0
var is_match_over: bool = false
var kickoff_delay_seconds: float = 1.5
var is_in_kickoff_delay: bool = false

# Stalemate detection
var _stall_timer: float = 0.0
var stall_velocity_epsilon: float = 6.0
var stall_seconds_threshold: float = 2.0

# HUD nodes created at runtime (no scene edits needed)
var hud_layer: CanvasLayer
var score_label: Label
var timer_label: Label
var message_label: Label
var kickoff_timer: Timer

func _ready() -> void:
	_add_to_group("Game")
	_setup_hud()
	time_left_seconds = match_duration_seconds
	is_match_over = false
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

func _physics_process(_delta: float) -> void:
	# Restart play if ball goes out of bounds (e.g., to corners or outside field)
	if _is_out_of_bounds(ball.global_position) and not is_in_kickoff_delay and not is_match_over:
		_start_kickoff_delay()
	_detect_and_recover_from_stall(_delta)

func _process(delta: float) -> void:
	if is_match_over:
		return
	if not is_in_kickoff_delay:
		time_left_seconds = max(0.0, time_left_seconds - delta)
		_update_hud()
		if time_left_seconds <= 0.0:
			_end_match()
	# keep boundary drawing fresh
	queue_redraw()

func _is_out_of_bounds(p: Vector2) -> bool:
	return p.x < FIELD_BOUNDS_MIN.x or p.x > FIELD_BOUNDS_MAX.x or p.y < FIELD_BOUNDS_MIN.y or p.y > FIELD_BOUNDS_MAX.y

func _on_goal_entered(body: Node) -> void:
	if body != ball:
		return
	if goal_left and goal_left.get_overlapping_bodies().has(body):
		var goal_team: String = goal_left.get_meta("team")
		if goal_team == "A":
			score_b += 1
		else:
			score_a += 1
		_update_hud()
		print("Score A:", score_a, " B:", score_b)
		_start_kickoff_delay()
		return
	if goal_right and goal_right.get_overlapping_bodies().has(body):
		var goal_team_r: String = goal_right.get_meta("team")
		if goal_team_r == "A":
			score_b += 1
		else:
			score_a += 1
		_update_hud()
		print("Score A:", score_a, " B:", score_b)
		_start_kickoff_delay()
		return

# -----------------
# Drawing (boundary)
# -----------------
func _draw() -> void:
	var rect := Rect2(FIELD_BOUNDS_MIN, FIELD_BOUNDS_MAX - FIELD_BOUNDS_MIN)
	draw_rect(rect, Color(0.9, 0.9, 0.9, 0.8), false, 2.0)

# -----------------
# HUD and match flow
# -----------------
func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	score_label = Label.new()
	score_label.text = "A 0 - 0 B"
	score_label.position = Vector2(20, 20)
	score_label.size = Vector2(300, 32)
	hud_layer.add_child(score_label)

	timer_label = Label.new()
	timer_label.text = "02:00"
	timer_label.position = Vector2(600, 20)
	timer_label.size = Vector2(120, 32)
	hud_layer.add_child(timer_label)

	message_label = Label.new()
	message_label.text = "Kickoff"
	message_label.position = Vector2(560, 60)
	message_label.size = Vector2(200, 32)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(message_label)

	kickoff_timer = Timer.new()
	kickoff_timer.one_shot = true
	kickoff_timer.wait_time = kickoff_delay_seconds
	add_child(kickoff_timer)
	kickoff_timer.timeout.connect(_on_kickoff_timeout)

func _update_hud() -> void:
	score_label.text = "A %d - %d B" % [score_a, score_b]
	var m: int = int(time_left_seconds) / 60
	var s: int = int(time_left_seconds) % 60
	timer_label.text = "%02d:%02d" % [m, s]

func _start_kickoff_delay() -> void:
	if is_match_over:
		return
	is_in_kickoff_delay = true
	ball.velocity = Vector2.ZERO
	message_label.text = "Goal! Kickoff soon"
	kickoff_timer.start()

func _end_match() -> void:
	is_match_over = true
	ball.velocity = Vector2.ZERO
	message_label.text = "Full Time"

func _detect_and_recover_from_stall(delta: float) -> void:
	if is_match_over or is_in_kickoff_delay:
		_stall_timer = 0.0
		return
	var ball_still: bool = ball.velocity.length() <= stall_velocity_epsilon
	var players_still: bool = true
	for team in [team_a, team_b]:
		if not team:
			continue
		for child in team.get_children():
			if child is Player:
				if child.velocity.length() > stall_velocity_epsilon:
					players_still = false
					break
		if not players_still:
			break
	if ball_still and players_still:
		_stall_timer += delta
		if _stall_timer >= stall_seconds_threshold:
			message_label.text = "Stall - Kickoff"
			_start_kickoff_delay()
			_stall_timer = 0.0
	else:
		_stall_timer = 0.0

func _on_kickoff_timeout() -> void:
	is_in_kickoff_delay = false
	message_label.text = ""
	_reset_kickoff()
