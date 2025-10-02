extends Label3D

class_name PlayerNameTag3D

# 3D name tag that floats above players
var player: Player3D
var offset_height: float = 2.5

func _ready() -> void:
	# Set up the label appearance
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 24
	outline_size = 2
	outline_color = Color.BLACK
	
	# Position above player
	position.y = offset_height

func setup_for_player(target_player: Player3D) -> void:
	player = target_player
	
	if player:
		# Set text based on player role and team
		var team_letter = "A" if player.is_team_a else "B"
		var role_short = _get_role_abbreviation(player.role)
		text = "%s-%s" % [team_letter, role_short]
		
		# Set color based on team
		modulate = Color.CYAN if player.is_team_a else Color.ORANGE
		
		# Add to player as child
		player.add_child(self)

func _get_role_abbreviation(role: String) -> String:
	match role.to_lower():
		"goalkeeper":
			return "GK"
		"defender":
			return "DEF"
		"midfielder":
			return "MID"
		"striker":
			return "STR"
		_:
			return "PLR"

func _process(_delta: float) -> void:
	if player:
		# Always face the camera
		var camera = get_viewport().get_camera_3d()
		if camera:
			look_at(camera.global_position, Vector3.UP)
