extends Control

class_name UIController3D

# References to game components
var game_manager: Node3D
var ball: CharacterBody3D
var team_a: Node
var team_b: Node

# UI Components
@onready var enhanced_hud: Control = $EnhancedHUD
@onready var scoreboard: Control = $EnhancedHUD/Scoreboard
@onready var team_a_score: Label = $EnhancedHUD/Scoreboard/TeamAScore
@onready var team_b_score: Label = $EnhancedHUD/Scoreboard/TeamBScore
@onready var match_timer: Label = $EnhancedHUD/Scoreboard/MatchTimer
@onready var game_phase: Label = $EnhancedHUD/GamePhase
@onready var possession_bar: ProgressBar = $EnhancedHUD/PossessionBar
@onready var ball_speed: Label = $EnhancedHUD/BallSpeed

@onready var stats_panel: Control = $StatsPanel
@onready var player_info: Control = $StatsPanel/PlayerInfo
@onready var performance_metrics: Control = $StatsPanel/PerformanceMetrics

@onready var control_panel: Control = $ControlPanel
@onready var pause_button: Button = $ControlPanel/PauseButton
@onready var speed_slider: HSlider = $ControlPanel/SpeedSlider
@onready var camera_controls: Control = $ControlPanel/CameraControls
@onready var camera_button: Button = $ControlPanel/CameraControls/CameraButton
@onready var zoom_in_button: Button = $ControlPanel/CameraControls/ZoomInButton
@onready var zoom_out_button: Button = $ControlPanel/CameraControls/ZoomOutButton
@onready var help_panel: Control = $HelpPanel
@onready var help_button: Button = $HelpButton
@onready var close_help_button: Button = $HelpPanel/CloseHelpButton

@onready var minimap: Control = $Minimap
@onready var minimap_field: Control = $Minimap/MinimapField

# Game state tracking
var match_time: float = 0.0
var is_paused: bool = false
var game_speed: float = 1.0
var possession_team_a: float = 0.0
var possession_team_b: float = 0.0
var possession_timer: float = 0.0
var last_ball_toucher_team_a: bool = true

# Statistics tracking
var team_a_stats: Dictionary = {
	"goals": 0,
	"shots": 0,
	"passes": 0,
	"possession_time": 0.0,
	"distance_covered": 0.0
}

var team_b_stats: Dictionary = {
	"goals": 0,
	"shots": 0,
	"passes": 0,
	"possession_time": 0.0,
	"distance_covered": 0.0
}

var player_stats: Dictionary = {}

func _ready() -> void:
	# Initialize UI components
	_setup_ui_components()
	_connect_signals()
	
	# Find game components
	var main_scene = get_tree().current_scene
	if main_scene.name == "Main3D":
		game_manager = main_scene
		_initialize_game_references()

func _initialize_game_references() -> void:
	if not game_manager:
		return
		
	# Get field and ball references
	var field = game_manager.get_node_or_null("Field3D")
	if field:
		ball = field.get_node_or_null("Ball")
	
	# Get team references
	team_a = game_manager.get_node_or_null("TeamA")
	team_b = game_manager.get_node_or_null("TeamB")
	
	# Initialize player stats
	_initialize_player_stats()

func _initialize_player_stats() -> void:
	for team in [team_a, team_b]:
		if team:
			for child in team.get_children():
				if child is Player3D:
					var player_id = child.get_instance_id()
					player_stats[player_id] = {
						"name": child.role,
						"team": "A" if child.is_team_a else "B",
						"distance_covered": 0.0,
						"last_position": child.global_position,
						"touches": 0,
						"passes": 0
					}

func _setup_ui_components() -> void:
	# Set initial values
	if match_timer:
		match_timer.text = "00:00"
	if game_phase:
		game_phase.text = "Kickoff"
	if possession_bar:
		possession_bar.value = 50.0
	if ball_speed:
		ball_speed.text = "Ball Speed: 0.0 m/s"

func _connect_signals() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	if speed_slider:
		speed_slider.value_changed.connect(_on_speed_changed)
	if camera_button:
		camera_button.pressed.connect(_on_camera_switch)
	if zoom_in_button:
		zoom_in_button.pressed.connect(_on_zoom_in)
	if zoom_out_button:
		zoom_out_button.pressed.connect(_on_zoom_out)
	if help_button:
		help_button.pressed.connect(_on_help_toggle)
	if close_help_button:
		close_help_button.pressed.connect(_on_help_toggle)

func _process(delta: float) -> void:
	if is_paused:
		return
		
	# Update match timer
	match_time += delta * game_speed
	_update_match_timer()
	
	# Update game statistics
	_update_possession_tracking(delta)
	_update_ball_speed()
	_update_player_statistics(delta)
	_update_performance_metrics()
	
	# Update minimap
	_update_minimap()

func _update_match_timer() -> void:
	if not match_timer:
		return
		
	var minutes = int(match_time / 60.0)
	var seconds = int(match_time) % 60
	match_timer.text = "%02d:%02d" % [minutes, seconds]

func _update_possession_tracking(delta: float) -> void:
	if not ball or not possession_bar:
		return
	
	# Determine which team has possession based on nearest player
	var nearest_player = _get_nearest_player_to_ball()
	if nearest_player and nearest_player is Player3D:
		var is_team_a = nearest_player.is_team_a
		
		if is_team_a:
			possession_team_a += delta * game_speed
		else:
			possession_team_b += delta * game_speed
		
		last_ball_toucher_team_a = is_team_a
	
	# Update possession bar
	var total_time = possession_team_a + possession_team_b
	if total_time > 0:
		var possession_percentage = (possession_team_a / total_time) * 100.0
		possession_bar.value = possession_percentage

func _update_ball_speed() -> void:
	if not ball or not ball_speed:
		return
		
	var speed = ball.velocity.length()
	ball_speed.text = "Ball Speed: %.1f m/s" % speed

func _update_player_statistics(delta: float) -> void:
	for team in [team_a, team_b]:
		if not team:
			continue
			
		for child in team.get_children():
			if child is Player3D:
				var player_id = child.get_instance_id()
				if player_id in player_stats:
					var stats = player_stats[player_id]
					var current_pos = child.global_position
					var distance = current_pos.distance_to(stats.last_position)
					stats.distance_covered += distance
					stats.last_position = current_pos

func _update_performance_metrics() -> void:
	if not performance_metrics:
		return
	
	# Update team statistics display
	var team_a_possession = 0.0
	var team_b_possession = 0.0
	var total_possession = possession_team_a + possession_team_b
	
	if total_possession > 0:
		team_a_possession = (possession_team_a / total_possession) * 100.0
		team_b_possession = (possession_team_b / total_possession) * 100.0
	
	# Update performance labels (will be created in the scene)
	var perf_label = performance_metrics.get_node_or_null("PerformanceLabel")
	if perf_label:
		perf_label.text = "Team A: %.1f%% | Team B: %.1f%%" % [team_a_possession, team_b_possession]

func _update_minimap() -> void:
	if not minimap_field or not ball:
		return
	
	# Update minimap positions (simplified representation)
	# This will be enhanced with actual minimap rendering

func _get_nearest_player_to_ball() -> Node:
	if not ball:
		return null
	
	var nearest_player = null
	var nearest_distance = INF
	
	for team in [team_a, team_b]:
		if not team:
			continue
			
		for child in team.get_children():
			if child is Player3D:
				var distance = child.global_position.distance_to(ball.global_position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_player = child
	
	return nearest_player

func _on_pause_pressed() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if pause_button:
		pause_button.text = "Resume" if is_paused else "Pause"

func _on_speed_changed(value: float) -> void:
	game_speed = value
	Engine.time_scale = game_speed

func _on_camera_switch() -> void:
	var camera_controller = get_tree().current_scene.get_node_or_null("CameraController")
	if camera_controller and camera_controller.has_method("switch_camera_mode"):
		camera_controller.switch_camera_mode()

func _on_zoom_in() -> void:
	var camera_controller = get_tree().current_scene.get_node_or_null("CameraController")
	if camera_controller and camera_controller.has_method("zoom_in"):
		camera_controller.zoom_in()

func _on_zoom_out() -> void:
	var camera_controller = get_tree().current_scene.get_node_or_null("CameraController")
	if camera_controller and camera_controller.has_method("zoom_out"):
		camera_controller.zoom_out()

func _on_help_toggle() -> void:
	if help_panel:
		help_panel.visible = !help_panel.visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				_on_help_toggle()
			KEY_S:
				toggle_stats_panel()
			KEY_M:
				toggle_minimap()
			KEY_SPACE:
				_on_pause_pressed()
			KEY_T:
				# Test score update
				_test_score_update()

# Public methods for game manager to call
func update_score(score_a: int, score_b: int) -> void:
	print("UIController: Updating score display - A:%d B:%d" % [score_a, score_b])
	
	if team_a_score:
		team_a_score.text = str(score_a)
		print("UIController: Set Team A score to: ", team_a_score.text)
	else:
		print("UIController: Warning - team_a_score label not found")
		
	if team_b_score:
		team_b_score.text = str(score_b)
		print("UIController: Set Team B score to: ", team_b_score.text)
	else:
		print("UIController: Warning - team_b_score label not found")
	
	# Update statistics
	team_a_stats.goals = score_a
	team_b_stats.goals = score_b

func update_game_phase(phase: String) -> void:
	if game_phase:
		game_phase.text = phase

func show_goal_celebration(team_name: String) -> void:
	# Create goal celebration effect
	var celebration = preload("res://scenes3d/GoalCelebration.tscn")
	if celebration:
		var instance = celebration.instantiate()
		add_child(instance)
		instance.play_celebration(team_name)

# Camera control methods
func switch_camera_angle() -> void:
	# Implement camera switching logic
	pass

func toggle_stats_panel() -> void:
	if stats_panel:
		stats_panel.visible = !stats_panel.visible

func toggle_minimap() -> void:
	if minimap:
		minimap.visible = !minimap.visible

func _test_score_update() -> void:
	# Test function to manually update score (press T)
	var test_a = randi() % 5
	var test_b = randi() % 5
	print("🧪 Testing score update: A:%d B:%d" % [test_a, test_b])
	update_score(test_a, test_b)
