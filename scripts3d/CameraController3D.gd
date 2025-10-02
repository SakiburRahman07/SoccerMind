extends Node3D

class_name CameraController3D

# Enhanced camera controller for better game viewing
@export var follow_ball: bool = true
@export var smooth_follow: bool = true
@export var follow_speed: float = 2.0
@export var zoom_speed: float = 1.0

var camera: Camera3D
var ball: CharacterBody3D
var default_position: Vector3
var default_rotation: Vector3
var current_camera_mode: int = 0

# Camera modes
enum CameraMode {
	OVERVIEW,      # High overview of entire field
	FOLLOW_BALL,   # Follow ball with smooth movement
	SIDELINE,      # Sideline broadcast view
	GOAL_VIEW,     # Behind goal view
	PLAYER_VIEW    # Close to players view
}

var camera_positions: Array[Vector3] = [
	Vector3(0, 80, 100),   # Overview
	Vector3(0, 60, 80),    # Follow ball
	Vector3(80, 40, 0),    # Sideline
	Vector3(0, 20, 70),    # Goal view
	Vector3(0, 15, 30)     # Player view
]

var camera_rotations: Array[Vector3] = [
	Vector3(-50, 0, 0),    # Overview
	Vector3(-45, 0, 0),    # Follow ball
	Vector3(-30, -90, 0),  # Sideline
	Vector3(-15, 0, 0),    # Goal view
	Vector3(-20, 0, 0)     # Player view
]

func _ready() -> void:
	call_deferred("_initialize_camera")

func _initialize_camera() -> void:
	# Find camera in the field
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.name == "Main3D":
		var field = main_scene.get_node_or_null("Field3D")
		if field:
			camera = field.get_node_or_null("Camera3D")
			ball = field.get_node_or_null("Ball")
	
	if camera:
		default_position = camera.position
		default_rotation = camera.rotation_degrees
		print("Camera controller initialized")

func _process(delta: float) -> void:
	if not camera or not ball:
		return
	
	match current_camera_mode:
		CameraMode.FOLLOW_BALL:
			_update_follow_ball_camera(delta)
		CameraMode.OVERVIEW:
			_update_overview_camera(delta)
		CameraMode.SIDELINE:
			_update_sideline_camera(delta)
		CameraMode.GOAL_VIEW:
			_update_goal_view_camera(delta)
		CameraMode.PLAYER_VIEW:
			_update_player_view_camera(delta)

func _update_follow_ball_camera(delta: float) -> void:
	if not smooth_follow:
		return
	
	# Smoothly follow ball position
	var ball_pos = ball.global_position
	var target_pos = Vector3(ball_pos.x * 0.3, camera_positions[CameraMode.FOLLOW_BALL].y, 
							camera_positions[CameraMode.FOLLOW_BALL].z + ball_pos.z * 0.2)
	
	camera.position = camera.position.lerp(target_pos, follow_speed * delta)

func _update_overview_camera(delta: float) -> void:
	# Static overview position
	var target_pos = camera_positions[CameraMode.OVERVIEW]
	camera.position = camera.position.lerp(target_pos, follow_speed * delta)
	camera.rotation_degrees = camera.rotation_degrees.lerp(camera_rotations[CameraMode.OVERVIEW], follow_speed * delta)

func _update_sideline_camera(delta: float) -> void:
	# Sideline view that follows ball along the sideline
	var ball_pos = ball.global_position
	var target_pos = Vector3(camera_positions[CameraMode.SIDELINE].x, 
							camera_positions[CameraMode.SIDELINE].y,
							ball_pos.z * 0.8)
	
	camera.position = camera.position.lerp(target_pos, follow_speed * delta)
	
	# Look towards the ball
	var look_target = ball_pos + Vector3(0, 2, 0)
	camera.look_at(look_target, Vector3.UP)

func _update_goal_view_camera(delta: float) -> void:
	# Behind goal view
	var ball_pos = ball.global_position
	var goal_side = 1.0 if ball_pos.x > 0 else -1.0
	var target_pos = Vector3(goal_side * 65, camera_positions[CameraMode.GOAL_VIEW].y, 
							camera_positions[CameraMode.GOAL_VIEW].z)
	
	camera.position = camera.position.lerp(target_pos, follow_speed * delta)
	camera.look_at(ball_pos + Vector3(0, 2, 0), Vector3.UP)

func _update_player_view_camera(delta: float) -> void:
	# Close player view
	var ball_pos = ball.global_position
	var target_pos = Vector3(ball_pos.x, camera_positions[CameraMode.PLAYER_VIEW].y, 
							ball_pos.z + camera_positions[CameraMode.PLAYER_VIEW].z)
	
	camera.position = camera.position.lerp(target_pos, follow_speed * delta)

func switch_camera_mode() -> void:
	current_camera_mode = (current_camera_mode + 1) % CameraMode.size()
	print("Camera mode switched to: ", CameraMode.keys()[current_camera_mode])

func set_camera_mode(mode: CameraMode) -> void:
	current_camera_mode = mode
	
	# Immediately set position and rotation for non-dynamic modes
	if mode != CameraMode.FOLLOW_BALL and mode != CameraMode.SIDELINE and mode != CameraMode.GOAL_VIEW and mode != CameraMode.PLAYER_VIEW:
		camera.position = camera_positions[mode]
		camera.rotation_degrees = camera_rotations[mode]

func zoom_in() -> void:
	if camera:
		camera.fov = max(camera.fov - 5, 30)

func zoom_out() -> void:
	if camera:
		camera.fov = min(camera.fov + 5, 120)

func reset_camera() -> void:
	if camera:
		camera.position = default_position
		camera.rotation_degrees = default_rotation
		camera.fov = 65.0
		current_camera_mode = CameraMode.FOLLOW_BALL

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_C:
				switch_camera_mode()
			KEY_EQUAL, KEY_PLUS:
				zoom_in()
			KEY_MINUS:
				zoom_out()
			KEY_HOME:
				reset_camera()
