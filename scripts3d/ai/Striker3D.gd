extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var target_x: float = 58.0 if player.is_team_a else -58.0
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	var desire: Vector3 = to_ball
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.2
	var dir: Vector3 = (desire + keep_shape).normalized()
	var dist: float = to_ball.length()
	if dist < 2.0:
		# Shoot with slight randomness in Z to avoid deterministic cornering
		var z_offset: float = randf_range(-4.0, 4.0)
		var toward_goal: Vector3 = Vector3(target_x, 0, player.global_transform.origin.z + z_offset) - ball.global_transform.origin
		return {"action": "kick", "force": 25.0, "direction": toward_goal}
	return {"action": "move", "direction": dir}


