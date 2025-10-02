extends Control

class_name MinimapRenderer3D

# Minimap rendering for the soccer field
var field_width: float = 120.0  # Field width in world units
var field_height: float = 70.0  # Field height in world units
var minimap_width: float = 140.0  # Minimap width in pixels
var minimap_height: float = 120.0  # Minimap height in pixels

# References
var ball: CharacterBody3D
var team_a: Node
var team_b: Node

# Colors
var field_color: Color = Color(0.1, 0.5, 0.16, 1.0)
var line_color: Color = Color.WHITE
var ball_color: Color = Color.ORANGE
var team_a_color: Color = Color.BLUE
var team_b_color: Color = Color.RED

func _ready() -> void:
	custom_minimum_size = Vector2(minimap_width, minimap_height)
	call_deferred("_initialize_references")

func _initialize_references() -> void:
	# Find game components
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.name == "Main3D":
		var field = main_scene.get_node_or_null("Field3D")
		if field:
			ball = field.get_node_or_null("Ball")
		
		team_a = main_scene.get_node_or_null("TeamA")
		team_b = main_scene.get_node_or_null("TeamB")

func _draw() -> void:
	var rect = get_rect()
	
	# Draw field background
	draw_rect(Rect2(Vector2.ZERO, rect.size), field_color)
	
	# Draw field lines
	_draw_field_lines(rect)
	
	# Draw players
	_draw_players(rect)
	
	# Draw ball
	_draw_ball(rect)

func _draw_field_lines(rect: Rect2) -> void:
	var line_width = 1.0
	
	# Field border
	draw_rect(Rect2(Vector2.ZERO, rect.size), line_color, false, line_width)
	
	# Center line
	var center_x = rect.size.x / 2.0
	draw_line(Vector2(center_x, 0), Vector2(center_x, rect.size.y), line_color, line_width)
	
	# Center circle
	var center = rect.size / 2.0
	var circle_radius = (18.0 / field_width) * rect.size.x  # 18m radius in world
	draw_arc(center, circle_radius, 0, TAU, 32, line_color, line_width)
	
	# Goal areas (simplified)
	var goal_area_width = (16.0 / field_width) * rect.size.x
	var goal_area_height = (40.0 / field_height) * rect.size.y
	var goal_y = (rect.size.y - goal_area_height) / 2.0
	
	# Left goal area
	draw_rect(Rect2(0, goal_y, goal_area_width, goal_area_height), line_color, false, line_width)
	
	# Right goal area
	draw_rect(Rect2(rect.size.x - goal_area_width, goal_y, goal_area_width, goal_area_height), line_color, false, line_width)

func _draw_players(rect: Rect2) -> void:
	var player_radius = 3.0
	
	# Draw Team A players
	if team_a:
		for child in team_a.get_children():
			if child is Player3D:
				var world_pos = child.global_position
				var minimap_pos = _world_to_minimap(world_pos, rect)
				draw_circle(minimap_pos, player_radius, team_a_color)
	
	# Draw Team B players
	if team_b:
		for child in team_b.get_children():
			if child is Player3D:
				var world_pos = child.global_position
				var minimap_pos = _world_to_minimap(world_pos, rect)
				draw_circle(minimap_pos, player_radius, team_b_color)

func _draw_ball(rect: Rect2) -> void:
	if not ball:
		return
	
	var world_pos = ball.global_position
	var minimap_pos = _world_to_minimap(world_pos, rect)
	var ball_radius = 2.5
	
	# Draw ball with outline
	draw_circle(minimap_pos, ball_radius + 1, Color.BLACK)
	draw_circle(minimap_pos, ball_radius, ball_color)

func _world_to_minimap(world_pos: Vector3, rect: Rect2) -> Vector2:
	# Convert world coordinates to minimap coordinates
	# World field: X from -60 to 60, Z from -35 to 35
	# Minimap: X from 0 to rect.width, Y from 0 to rect.height
	
	var normalized_x = (world_pos.x + field_width / 2.0) / field_width
	var normalized_z = (world_pos.z + field_height / 2.0) / field_height
	
	return Vector2(
		normalized_x * rect.size.x,
		normalized_z * rect.size.y
	)

func _process(_delta: float) -> void:
	# Redraw minimap every frame to show real-time positions
	queue_redraw()
