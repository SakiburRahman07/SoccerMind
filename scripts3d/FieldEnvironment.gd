extends Node3D

@export var day_light_color: Color = Color(1, 1, 0.95)
@export var night_light_color: Color = Color(0.7, 0.8, 1.0)
@export var is_night: bool = false

@onready var dir_light: DirectionalLight3D = get_parent().get_node_or_null("DirectionalLight3D")
@onready var floor_mesh: MeshInstance3D = get_parent().get_node_or_null("Floor/MeshInstance3D")

func _ready() -> void:
	_apply_variant()

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
