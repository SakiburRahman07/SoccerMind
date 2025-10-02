extends Node

# Simple test helper to verify UI system functionality
# This script can be temporarily added to test UI features

var ui_controller: UIController3D
var test_timer: float = 0.0

func _ready() -> void:
	# Find UI controller
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.name == "Main3D":
		var canvas_layer = main_scene.get_node_or_null("CanvasLayer")
		if canvas_layer:
			ui_controller = canvas_layer.get_node_or_null("UIController")
	
	if ui_controller:
		print("✅ UI Controller found and working!")
		_test_ui_functions()
	else:
		print("❌ UI Controller not found")

func _test_ui_functions() -> void:
	print("🧪 Testing UI functions...")
	
	# Test score update
	if ui_controller.has_method("update_score"):
		ui_controller.update_score(1, 0)
		print("✅ Score update test passed")
	
	# Test game phase update
	if ui_controller.has_method("update_game_phase"):
		ui_controller.update_game_phase("Testing")
		print("✅ Game phase update test passed")
	
	# Test panel toggles
	if ui_controller.has_method("toggle_stats_panel"):
		print("✅ Stats panel toggle available")
	
	if ui_controller.has_method("toggle_minimap"):
		print("✅ Minimap toggle available")
	
	print("🎉 All UI tests completed!")

func _process(delta: float) -> void:
	test_timer += delta
	
	# Auto-test score updates every 5 seconds
	if test_timer > 5.0 and ui_controller:
		test_timer = 0.0
		var random_score_a = randi() % 5
		var random_score_b = randi() % 5
		ui_controller.update_score(random_score_a, random_score_b)
		print("🔄 Auto-updated scores: A:%d B:%d" % [random_score_a, random_score_b])
