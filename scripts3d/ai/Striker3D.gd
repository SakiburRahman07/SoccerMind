extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	var target_x: float = 58.0 if player.is_team_a else -58.0
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	var desire: Vector3 = to_ball
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.2
	var dir: Vector3 = (desire + keep_shape).normalized()
	var dist: float = to_ball.length()
	if dist < 2.5:
		# Shoot power based on distance and nearby opponent pressure
		var z_offset: float = randf_range(-3.0, 3.0)
		var shot_dir: Vector3 = Vector3(target_x, 0, player.global_transform.origin.z + z_offset) - ball.global_transform.origin
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var min_opp: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(player.global_transform.origin)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		var base_force: float = 20.0 + clamp(dist, 0.0, 6.0) * 1.2
		var force: float = clamp(base_force + pressure * 6.0, 16.0, 28.0)
		return {"action": "kick", "force": force, "direction": shot_dir}
	return {"action": "move", "direction": dir}


