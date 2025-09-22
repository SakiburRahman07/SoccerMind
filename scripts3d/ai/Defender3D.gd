extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var goal_pos := Vector3(-58.0 if player.is_team_a else 58.0, 0, 0)
	var intercept := goal_pos.lerp(ball.global_transform.origin, 0.25)
	var desire: Vector3 = (intercept - player.global_transform.origin)
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.5
	var dir: Vector3 = (desire + keep_shape).normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.5:
		# Clear randomly toward sides
		var clear_z := randf_range(-6.0, 6.0)
		var team_dir := -1.0 if player.is_team_a else 1.0
		return {"action": "kick", "force": 16.0, "direction": Vector3(team_dir * 10.0, 0, clear_z)}
	return {"action": "move", "direction": dir}
