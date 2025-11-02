extends Node

# AI configuration storage
var team_a_config: Dictionary = {}
var team_b_config: Dictionary = {}

# Available AI algorithms by role
var ai_registry: Dictionary = {
	"goalkeeper": [
		{"name": "Standard Goalkeeper", "path": "res://scripts3d/ai/Goalkeeper3D.gd", "description": "Reactive goalkeeper AI with defensive positioning"}
	],
	"defender": [
		{"name": "Fuzzy Logic Defender", "path": "res://scripts3d/ai/Defender3D.gd", "description": "Uses fuzzy logic for intelligent defensive positioning"},
		{"name": "DFS Defender", "path": "res://scripts3d/ai/Defender3DDFS.gd", "description": "Depth-First Search pathfinding for defensive maneuvers"}
	],
	"midfielder": [
		{"name": "Alpha-Beta Midfielder", "path": "res://scripts3d/ai/Midfielder3DAlphaBeta.gd", "description": "Minimax with alpha-beta pruning for strategic decisions"},
		{"name": "BFS Midfielder", "path": "res://scripts3d/ai/Midfielder3DBFS.gd", "description": "Breadth-First Search exploration for wide coverage"},
		{"name": "Greedy Midfielder", "path": "res://scripts3d/ai/Midfielder3DGreedy.gd", "description": "Quick greedy decision making for fast reactions"}
	],
	"striker": [
		{"name": "Classic Striker", "path": "res://scripts3d/ai/Striker3D.gd", "description": "Basic striker AI with goal-oriented behavior"},
		{"name": "A* Striker", "path": "res://scripts3d/ai/Striker3DAStar.gd", "description": "A* pathfinding algorithm for optimal goal pursuit"},
		{"name": "Hill Climbing Striker", "path": "res://scripts3d/ai/Striker3DHillClimb.gd", "description": "Optimization-based positioning using hill climbing"}
	]
}

func _ready() -> void:
	# Initialize with default configurations
	_load_default_configuration()

func get_default_config() -> Dictionary:
	"""Returns the current hardcoded default configuration"""
	return {
		"team_a": {
			"player_0": {"role": "goalkeeper", "path": "res://scripts3d/ai/Goalkeeper3D.gd"},
			"player_1": {"role": "defender", "path": "res://scripts3d/ai/Defender3D.gd"},
			"player_2": {"role": "defender", "path": "res://scripts3d/ai/Defender3D.gd"},
			"player_3": {"role": "midfielder", "path": "res://scripts3d/ai/Midfielder3DAlphaBeta.gd"},
			"player_4": {"role": "midfielder", "path": "res://scripts3d/ai/Midfielder3DAlphaBeta.gd"},
			"player_5": {"role": "striker", "path": "res://scripts3d/ai/Striker3DAStar.gd"}
		},
		"team_b": {
			"player_0": {"role": "goalkeeper", "path": "res://scripts3d/ai/Goalkeeper3D.gd"},
			"player_1": {"role": "defender", "path": "res://scripts3d/ai/Defender3DDFS.gd"},
			"player_2": {"role": "defender", "path": "res://scripts3d/ai/Defender3DDFS.gd"},
			"player_3": {"role": "midfielder", "path": "res://scripts3d/ai/Midfielder3DGreedy.gd"},
			"player_4": {"role": "midfielder", "path": "res://scripts3d/ai/Midfielder3DBFS.gd"},
			"player_5": {"role": "striker", "path": "res://scripts3d/ai/Striker3DHillClimb.gd"}
		}
	}

func _load_default_configuration() -> void:
	"""Load default hardcoded configuration into config dictionaries"""
	var default = get_default_config()
	team_a_config.clear()
	team_b_config.clear()
	
	for key in default.team_a:
		team_a_config[key] = default.team_a[key].path
	
	for key in default.team_b:
		team_b_config[key] = default.team_b[key].path

func get_ai_path_for_player(team_a: bool, player_index: int) -> String:
	"""Get the AI script path for a specific player"""
	var config_key = "player_%d" % player_index
	var config = team_a_config if team_a else team_b_config
	
	if config.has(config_key):
		return config[config_key]
	
	# Fallback to default
	var default = get_default_config()
	var team_key = "team_a" if team_a else "team_b"
	if default.has(team_key) and default[team_key].has(config_key):
		return default[team_key][config_key].path
	
	# Ultimate fallback
	return _get_fallback_ai_path(team_a, player_index)

func _get_fallback_ai_path(team_a: bool, player_index: int) -> String:
	"""Get fallback AI path based on role"""
	var roles = ["goalkeeper", "defender", "defender", "midfielder", "midfielder", "striker"]
	if player_index >= 0 and player_index < roles.size():
		var role = roles[player_index]
		var ai_list = ai_registry.get(role, [])
		if ai_list.size() > 0:
			return ai_list[0].path
	
	# Last resort
	return "res://scripts3d/ai/Midfielder3DAlphaBeta.gd"

func set_ai_for_player(team_a: bool, player_index: int, ai_path: String) -> void:
	"""Set AI script path for a specific player"""
	if ai_path == null or ai_path == "":
		push_error("set_ai_for_player: ai_path is null or empty for player %d (team_a: %s)" % [player_index, team_a])
		return
	
	if player_index < 0 or player_index >= 6:
		push_error("set_ai_for_player: Invalid player_index: %d (must be 0-5)" % player_index)
		return
	
	# Verify the path exists
	if not ResourceLoader.exists(ai_path):
		push_warning("set_ai_for_player: AI path does not exist: %s" % ai_path)
		# Don't return, still set it as it might be a valid path that just isn't loaded yet
	
	var config_key = "player_%d" % player_index
	var config = team_a_config if team_a else team_b_config
	config[config_key] = ai_path
	print("Set AI for %s player %d: %s" % [("Team A" if team_a else "Team B"), player_index, ai_path])

func save_config() -> void:
	"""Optional: Save configuration to user:// for persistence"""
	var config_file = ConfigFile.new()
	config_file.set_value("team_a", "config", team_a_config)
	config_file.set_value("team_b", "config", team_b_config)
	var error = config_file.save("user://ai_config.cfg")
	if error != OK:
		print("Failed to save AI configuration: ", error)
	else:
		print("AI configuration saved successfully")

func load_config() -> void:
	"""Optional: Load configuration from user://"""
	var config_file = ConfigFile.new()
	var error = config_file.load("user://ai_config.cfg")
	if error != OK:
		print("No saved AI configuration found, using defaults")
		_load_default_configuration()
		return
	
	if config_file.has_section("team_a") and config_file.has_section_key("team_a", "config"):
		team_a_config = config_file.get_value("team_a", "config", {})
	if config_file.has_section("team_b") and config_file.has_section_key("team_b", "config"):
		team_b_config = config_file.get_value("team_b", "config", {})
	
	# Ensure all players have configurations
	_validate_config()

func _validate_config() -> void:
	"""Ensure all player positions have valid AI paths"""
	for i in range(6):
		var key_a = "player_%d" % i
		var key_b = "player_%d" % i
		
		if not team_a_config.has(key_a) or team_a_config[key_a] == "":
			var fallback = _get_fallback_ai_path(true, i)
			team_a_config[key_a] = fallback
		
		if not team_b_config.has(key_b) or team_b_config[key_b] == "":
			var fallback = _get_fallback_ai_path(false, i)
			team_b_config[key_b] = fallback

func get_ai_by_role(role: String) -> Array:
	"""Get list of available AI algorithms for a role"""
	return ai_registry.get(role, [])

func get_random_config() -> Dictionary:
	"""Generate a random AI configuration for testing"""
	var random_config = {}
	for team in [true, false]:
		var team_config = {}
		for i in range(6):
			var roles = ["goalkeeper", "defender", "defender", "midfielder", "midfielder", "striker"]
			var role = roles[i]
			var ai_list = get_ai_by_role(role)
			if ai_list.size() > 0:
				var random_ai = ai_list[randi() % ai_list.size()]
				team_config["player_%d" % i] = random_ai.path
		if team:
			team_a_config = team_config
		else:
			team_b_config = team_config
	return random_config

