extends Node3D

@export var day_light_color: Color = Color(1, 1, 0.95)
@export var night_light_color: Color = Color(0.7, 0.8, 1.0)
@export var is_night: bool = false

@onready var dir_light: DirectionalLight3D = get_parent().get_node_or_null("DirectionalLight3D")
@onready var floor_mesh: MeshInstance3D = get_parent().get_node_or_null("Floor/MeshInstance3D")

var dbox_lines: Array[MeshInstance3D] = []

func _ready() -> void:
	_apply_variant()
	_draw_dbox_markings()

func _draw_dbox_markings() -> void:
	# D-box parameters
	var penalty_depth: float = 12.0
	var penalty_width: float = 12.0
	var goal_x_teamA: float = 58.0
	var goal_x_teamB: float = -58.0
	var line_thickness: float = 0.15
	var line_height: float = 0.05
	
	# Create white material for D-box lines
	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color.WHITE
	white_mat.emission_enabled = true
	white_mat.emission = Color.WHITE
	white_mat.emission_energy_multiplier = 0.3
	
	# Team A D-box (right side, goal at +58)
	_create_dbox_rectangle(goal_x_teamA - penalty_depth, goal_x_teamA, -penalty_width, penalty_width, 
		line_thickness, line_height, white_mat, "TeamA_DBox")
	
	# Team B D-box (left side, goal at -58)
	_create_dbox_rectangle(goal_x_teamB, goal_x_teamB + penalty_depth, -penalty_width, penalty_width, 
		line_thickness, line_height, white_mat, "TeamB_DBox")

func _create_dbox_rectangle(min_x: float, max_x: float, min_z: float, max_z: float, 
	thickness: float, height: float, material: StandardMaterial3D, name_prefix: String) -> void:
	
	# Create 4 lines for the rectangle
	# Left vertical line (at min_x)
	_create_line(Vector3(min_x, height, min_z), Vector3(min_x, height, max_z), thickness, material, name_prefix + "_Left")
	
	# Right vertical line (at max_x)
	_create_line(Vector3(max_x, height, min_z), Vector3(max_x, height, max_z), thickness, material, name_prefix + "_Right")
	
	# Top horizontal line (at max_z)
	_create_line(Vector3(min_x, height, max_z), Vector3(max_x, height, max_z), thickness, material, name_prefix + "_Top")
	
	# Bottom horizontal line (at min_z)
	_create_line(Vector3(min_x, height, min_z), Vector3(max_x, height, min_z), thickness, material, name_prefix + "_Bottom")

func _create_line(from: Vector3, to: Vector3, thickness: float, material: StandardMaterial3D, line_name: String) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = line_name
	
	var line_dir := to - from
	var line_length := line_dir.length()
	var line_center := (from + to) / 2.0
	
	# Create a thin box mesh for the line
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(thickness if abs(line_dir.x) < 0.1 else line_length, 0.02, thickness if abs(line_dir.z) < 0.1 else line_length)
	box_mesh.material = material
	
	mesh_inst.mesh = box_mesh
	mesh_inst.position = line_center
	
	get_parent().add_child(mesh_inst)
	dbox_lines.append(mesh_inst)

func toggle_day_night() -> void:
	is_night = not is_night
	_apply_variant()

func _apply_variant() -> void:
	if dir_light:
		dir_light.light_color = night_light_color if is_night else day_light_color
		dir_light.shadow_enabled = true
	if floor_mesh and floor_mesh.mesh and floor_mesh.mesh is BoxMesh:
		var mat: StandardMaterial3D = floor_mesh.mesh.material
		if mat:
			if is_night:
				mat.albedo_color = Color(0.06, 0.25, 0.12)
				mat.roughness = 0.95
			else:
				mat.albedo_color = Color(0.1, 0.5, 0.16)
				mat.roughness = 0.9
