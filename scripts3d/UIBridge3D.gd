extends Node

# Bridge script to connect GameManager with UIController without modifying game logic
# This script observes game state and updates UI accordingly

var game_manager: Node3D
var ui_controller: UIController3D
var ball: CharacterBody3D

# State tracking for UI updates
var last_score_a: int = 0
var last_score_b: int = 0
var last_restart_state: bool = false
var current_game_phase: String = "Kickoff"

func _ready() -> void:
	# Wait for scene to be fully loaded
	call_deferred("_initialize_bridge")
	# Add extra delay to ensure UI is ready
	await get_tree().process_frame
	await get_tree().process_frame

func _initialize_bridge() -> void:
	# Find game manager and UI controller
	var main_scene = get_tree().current_scene
	if main_scene.name == "Main3D":
		game_manager = main_scene
		
		# Find UI controller
		var canvas_layer = main_scene.get_node_or_null("CanvasLayer")
		if canvas_layer:
			ui_controller = canvas_layer.get_node_or_null("UIController")
		
		# Get ball reference
		var field = game_manager.get_node_or_null("Field3D")
		if field:
			ball = field.get_node_or_null("Ball")
		
		if ui_controller:
			print("UI Bridge initialized successfully")
		else:
			print("Warning: UI Controller not found")

func _process(_delta: float) -> void:
	if not game_manager or not ui_controller:
		return
	
	# Monitor score changes
	_check_score_updates()
	
	# Monitor game phase changes
	_check_game_phase_updates()
	
	# Update UI with current game state
	_update_ui_state()

func _check_score_updates() -> void:
	# Read score directly from game manager variables
	var current_score_a = game_manager.score_a
	var current_score_b = game_manager.score_b
	
	if current_score_a != last_score_a or current_score_b != last_score_b:
		ui_controller.update_score(current_score_a, current_score_b)
		last_score_a = current_score_a
		last_score_b = current_score_b
		print("UI Bridge: Updated scoreboard - A:%d B:%d" % [current_score_a, current_score_b])

func _check_game_phase_updates() -> void:
	if not game_manager:
		return
	
	var new_phase = "In Play"
	
	# Determine current game phase based on game manager state
	if game_manager.has_method("get"):
		var restart_in_progress = game_manager.get("_restart_in_progress")
		if restart_in_progress != null and restart_in_progress:
			new_phase = "Restart"
	elif "_restart_in_progress" in game_manager:
		if game_manager._restart_in_progress:
			new_phase = "Restart"
	
	# Check if ball is at center (kickoff position)
	if ball and ball.global_position.distance_to(Vector3(0, 1, 0)) < 1.0:
		new_phase = "Kickoff"
	
	if new_phase != current_game_phase:
		current_game_phase = new_phase
		ui_controller.update_game_phase(new_phase)

func _update_ui_state() -> void:
	# Update match stats (shots, passes) from game manager
	if game_manager and ui_controller:
		var sa := 0
		var sb := 0
		var pa := 0
		var pb := 0
		if "shots_a" in game_manager and "shots_b" in game_manager:
			sa = game_manager.shots_a
			sb = game_manager.shots_b
		if "passes_a" in game_manager and "passes_b" in game_manager:
			pa = game_manager.passes_a
			pb = game_manager.passes_b
		if ui_controller.has_method("update_stats_display"):
			ui_controller.update_stats_display(sa, sb, pa, pb)
