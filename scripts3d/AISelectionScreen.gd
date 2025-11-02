extends Control

signal match_started

# UI node references - these will be set in _ready if nodes exist
var team_a_container: VBoxContainer
var team_b_container: VBoxContainer
var start_match_button: Button
var reset_default_button: Button
var random_ai_button: Button
var all_classic_button: Button
var all_advanced_button: Button

# Store references to all option buttons for easy access
var team_a_dropdowns: Array[OptionButton] = []
var team_b_dropdowns: Array[OptionButton] = []

# Player role labels for display
var role_labels: Array[String] = [
	"Goalkeeper",
	"Defender (Left)",
	"Defender (Right)",
	"Midfielder (Left)",
	"Midfielder (Right)",
	"Striker"
]

func _ready() -> void:
	# Get node references
	team_a_container = get_node_or_null("ScrollContainer/VBox/TeamASection")
	team_b_container = get_node_or_null("ScrollContainer/VBox/TeamBSection")
	start_match_button = get_node_or_null("ButtonContainer/StartMatchButton")
	reset_default_button = get_node_or_null("ButtonContainer/ResetDefaultButton")
	random_ai_button = get_node_or_null("ButtonContainer/RandomAIButton")
	all_classic_button = get_node_or_null("ButtonContainer/AllClassicButton")
	all_advanced_button = get_node_or_null("ButtonContainer/AllAdvancedButton")
	
	# Verify we have the containers
	if not team_a_container or not team_b_container:
		push_error("Team containers not found in AISelectionScreen scene!")
		return
	
	_populate_dropdowns()
	_load_current_configuration()
	_connect_signals()
	_validate_all_selections()

func _populate_dropdowns() -> void:
	"""Create and populate dropdown menus for all players"""
	# Team A section
	var team_a_grid = team_a_container.get_node_or_null("PlayerGrid")
	if team_a_grid:
		team_a_grid.queue_free()
	
	team_a_grid = GridContainer.new()
	team_a_grid.name = "PlayerGrid"
	team_a_grid.columns = 2
	team_a_grid.add_theme_constant_override("h_separation", 20)
	team_a_grid.add_theme_constant_override("v_separation", 10)
	team_a_container.add_child(team_a_grid)
	
	# Team B section
	var team_b_grid = team_b_container.get_node_or_null("PlayerGrid")
	if team_b_grid:
		team_b_grid.queue_free()
	
	team_b_grid = GridContainer.new()
	team_b_grid.name = "PlayerGrid"
	team_b_grid.columns = 2
	team_b_grid.add_theme_constant_override("h_separation", 20)
	team_b_grid.add_theme_constant_override("v_separation", 10)
	team_b_container.add_child(team_b_grid)
	
	# Create dropdowns for Team A
	team_a_dropdowns.clear()
	for i in range(6):
		var label = Label.new()
		label.text = "Player %d: %s" % [i + 1, role_labels[i]]
		label.custom_minimum_size = Vector2(200, 30)
		team_a_grid.add_child(label)
		
		var dropdown = OptionButton.new()
		dropdown.custom_minimum_size = Vector2(300, 30)
		dropdown.name = "TeamA_Player%d" % i
		_populate_dropdown_for_role(dropdown, i)
		# Connect signal - item_selected passes item_index as parameter
		# We bind team_a=true and player_index=i, and item_index comes from signal
		dropdown.item_selected.connect(func(item_index: int): _on_dropdown_changed(true, i, item_index))
		team_a_grid.add_child(dropdown)
		team_a_dropdowns.append(dropdown)
	
	# Create dropdowns for Team B
	team_b_dropdowns.clear()
	for i in range(6):
		var label = Label.new()
		label.text = "Player %d: %s" % [i + 1, role_labels[i]]
		label.custom_minimum_size = Vector2(200, 30)
		team_b_grid.add_child(label)
		
		var dropdown = OptionButton.new()
		dropdown.custom_minimum_size = Vector2(300, 30)
		dropdown.name = "TeamB_Player%d" % i
		_populate_dropdown_for_role(dropdown, i)
		# Connect signal - item_selected passes item_index as parameter
		# We bind team_a=false and player_index=i, and item_index comes from signal
		dropdown.item_selected.connect(func(item_index: int): _on_dropdown_changed(false, i, item_index))
		team_b_grid.add_child(dropdown)
		team_b_dropdowns.append(dropdown)

func _populate_dropdown_for_role(dropdown: OptionButton, player_index: int) -> void:
	"""Populate dropdown with AI options based on player role"""
	if not dropdown:
		push_error("Dropdown is null in _populate_dropdown_for_role")
		return
	
	if not AIConfigManager:
		push_error("AIConfigManager not available")
		return
	
	var roles = ["goalkeeper", "defender", "defender", "midfielder", "midfielder", "striker"]
	if player_index < 0 or player_index >= roles.size():
		push_error("Invalid player_index: %d" % player_index)
		return
	
	var role = roles[player_index]
	var ai_list = AIConfigManager.get_ai_by_role(role)
	
	if ai_list.is_empty():
		push_error("No AI algorithms found for role: %s" % role)
		return
	
	dropdown.clear()
	for ai in ai_list:
		if not ai.has("path") or not ai.has("name"):
			push_error("AI dictionary missing required fields: path or name")
			continue
		
		var display_name = "%s" % ai.name
		var ai_path = ai.path as String
		if ai_path == null or ai_path == "":
			push_error("AI path is null or empty for AI: %s" % ai.name)
			continue
		
		# Get the index before adding (this will be the index of the new item)
		var item_index = dropdown.get_item_count()
		
		# Add item (returns void in Godot 4)
		dropdown.add_item(display_name)
		
		# Store the path in metadata immediately after adding item
		dropdown.set_item_metadata(item_index, ai_path)
		dropdown.set_item_tooltip(item_index, ai.get("description", ""))
		
		# Verify metadata was set correctly
		var verify_path = dropdown.get_item_metadata(item_index) as String
		if verify_path == null or verify_path == "":
			push_error("Failed to set metadata for AI: %s at item_index: %d. Expected: %s" % [ai.name, item_index, ai_path])
			# Try setting again
			dropdown.set_item_metadata(item_index, ai_path)
			verify_path = dropdown.get_item_metadata(item_index) as String
			if verify_path == null or verify_path == "":
				push_error("Second attempt also failed to set metadata")

func _load_current_configuration() -> void:
	"""Load current configuration from AIConfigManager into dropdowns"""
	for i in range(6):
		var ai_path_a = AIConfigManager.get_ai_path_for_player(true, i)
		var ai_path_b = AIConfigManager.get_ai_path_for_player(false, i)
		
		_set_dropdown_selection(team_a_dropdowns[i], ai_path_a)
		_set_dropdown_selection(team_b_dropdowns[i], ai_path_b)

func _set_dropdown_selection(dropdown: OptionButton, ai_path: String) -> void:
	"""Set dropdown selection based on AI path"""
	for item_index in range(dropdown.get_item_count()):
		var stored_path = dropdown.get_item_metadata(item_index)
		if stored_path == ai_path:
			dropdown.selected = item_index
			return
	# If not found, select first item as fallback
	if dropdown.get_item_count() > 0:
		dropdown.selected = 0

func _connect_signals() -> void:
	"""Connect all button signals"""
	if start_match_button:
		start_match_button.pressed.connect(_on_start_match_pressed)
	if reset_default_button:
		reset_default_button.pressed.connect(_on_reset_default_pressed)
	if random_ai_button:
		random_ai_button.pressed.connect(_on_random_ai_pressed)
	if all_classic_button:
		all_classic_button.pressed.connect(_on_all_classic_pressed)
	if all_advanced_button:
		all_advanced_button.pressed.connect(_on_all_advanced_pressed)

func _on_dropdown_changed(team_a: bool, player_index: int, item_index: int) -> void:
	"""Handle dropdown selection change"""
	if player_index < 0 or player_index >= 6:
		push_error("Invalid player_index in _on_dropdown_changed: %d" % player_index)
		return
	
	var dropdown: OptionButton
	if team_a:
		if player_index >= team_a_dropdowns.size():
			push_error("Team A dropdown index out of range: %d" % player_index)
			return
		dropdown = team_a_dropdowns[player_index]
	else:
		if player_index >= team_b_dropdowns.size():
			push_error("Team B dropdown index out of range: %d" % player_index)
			return
		dropdown = team_b_dropdowns[player_index]
	
	if not dropdown:
		push_error("Dropdown is null for player_index: %d" % player_index)
		return
	
	if item_index < 0 or item_index >= dropdown.get_item_count():
		push_error("Invalid item_index: %d (dropdown has %d items)" % [item_index, dropdown.get_item_count()])
		return
	
	var ai_path = dropdown.get_item_metadata(item_index)
	if ai_path == null or ai_path == "":
		push_error("AI path metadata is null or empty for item_index %d" % item_index)
		# Try to get fallback from AIConfigManager
		var roles = ["goalkeeper", "defender", "defender", "midfielder", "midfielder", "striker"]
		var role = roles[player_index] if player_index < roles.size() else "midfielder"
		var ai_list = AIConfigManager.get_ai_by_role(role)
		if ai_list.size() > 0 and item_index < ai_list.size():
			ai_path = ai_list[item_index].path
		else:
			ai_path = AIConfigManager.get_ai_path_for_player(team_a, player_index)
	
	if ai_path == null or ai_path == "":
		push_error("Failed to get valid AI path for player %d" % player_index)
		return
	
	AIConfigManager.set_ai_for_player(team_a, player_index, ai_path)
	_validate_all_selections()

func _validate_all_selections() -> void:
	"""Ensure all positions have valid AI selections"""
	var all_valid = true
	for dropdown in team_a_dropdowns + team_b_dropdowns:
		if dropdown.get_item_count() == 0:
			all_valid = false
			break
	
	if start_match_button:
		start_match_button.disabled = not all_valid

func _on_start_match_pressed() -> void:
	"""Save configuration and start the match"""
	_save_to_config_manager()
	start_match_button.disabled = true  # Prevent double-clicking
	match_started.emit()

func _on_reset_default_pressed() -> void:
	"""Reset to default configuration"""
	AIConfigManager._load_default_configuration()
	_load_current_configuration()
	print("Reset to default AI configuration")

func _on_random_ai_pressed() -> void:
	"""Randomize all AI selections for testing"""
	AIConfigManager.get_random_config()
	_load_current_configuration()
	print("Randomized AI configuration")

func _on_all_classic_pressed() -> void:
	"""Apply classic AI configuration to both teams"""
	var classic_config = {
		"player_0": "res://scripts3d/ai/Goalkeeper3D.gd",
		"player_1": "res://scripts3d/ai/Defender3D.gd",
		"player_2": "res://scripts3d/ai/Defender3D.gd",
		"player_3": "res://scripts3d/ai/Midfielder3DAlphaBeta.gd",
		"player_4": "res://scripts3d/ai/Midfielder3DAlphaBeta.gd",
		"player_5": "res://scripts3d/ai/Striker3DAStar.gd"
	}
	
	for i in range(6):
		var key = "player_%d" % i
		AIConfigManager.set_ai_for_player(true, i, classic_config[key])
		AIConfigManager.set_ai_for_player(false, i, classic_config[key])
	
	_load_current_configuration()
	print("Applied classic AI configuration to both teams")

func _on_all_advanced_pressed() -> void:
	"""Apply advanced AI configuration to both teams"""
	var advanced_config = {
		"player_0": "res://scripts3d/ai/Goalkeeper3D.gd",
		"player_1": "res://scripts3d/ai/Defender3DDFS.gd",
		"player_2": "res://scripts3d/ai/Defender3DDFS.gd",
		"player_3": "res://scripts3d/ai/Midfielder3DBFS.gd",
		"player_4": "res://scripts3d/ai/Midfielder3DGreedy.gd",
		"player_5": "res://scripts3d/ai/Striker3DHillClimb.gd"
	}
	
	for i in range(6):
		var key = "player_%d" % i
		AIConfigManager.set_ai_for_player(true, i, advanced_config[key])
		AIConfigManager.set_ai_for_player(false, i, advanced_config[key])
	
	_load_current_configuration()
	print("Applied advanced AI configuration to both teams")

func _save_to_config_manager() -> void:
	"""Save current dropdown selections to AIConfigManager"""
	for i in range(6):
		# Team A
		var dropdown_a = team_a_dropdowns[i]
		var selected_index_a = dropdown_a.selected
		var ai_path_a = dropdown_a.get_item_metadata(selected_index_a)
		AIConfigManager.set_ai_for_player(true, i, ai_path_a)
		
		# Team B
		var dropdown_b = team_b_dropdowns[i]
		var selected_index_b = dropdown_b.selected
		var ai_path_b = dropdown_b.get_item_metadata(selected_index_b)
		AIConfigManager.set_ai_for_player(false, i, ai_path_b)
	
	print("AI configuration saved to AIConfigManager")
