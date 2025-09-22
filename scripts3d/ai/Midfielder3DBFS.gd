extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var target := Vector3(ball.global_transform.origin.x, 0, clamp(ball.global_transform.origin.z, -20.0, 20.0))
	var desire: Vector3 = (target - player.global_transform.origin)
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.4
	var dir: Vector3 = (desire + keep_shape).normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.0:
		# Safer pass using fuzzy selection, less forward
		var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
		var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((1.0 if player.is_team_a else -1.0) * 6.0, 0, 0))
		var lob: bool = pick.get("lob", false)
		var dir_pass: Vector3 = (target - ball.global_transform.origin)
		if lob:
			dir_pass.y = 5.0
		return {"action": "kick", "force": 18.0, "direction": dir_pass}
	return {"action": "move", "direction": dir}


