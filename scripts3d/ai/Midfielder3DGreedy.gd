extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	var desire: Vector3 = to_ball
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.3
	var dir: Vector3 = (desire + keep_shape).normalized()
	if to_ball.length() < 2.5:
		# Fuzzy passing to best teammate
		var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
		var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((1.0 if player.is_team_a else -1.0) * 8.0, 0, 0))
		var lob: bool = pick.get("lob", false)
		var dir_pass: Vector3 = (target - ball.global_transform.origin)
		if lob:
			dir_pass.y = 6.0
		return {"action": "kick", "force": 20.0, "direction": dir_pass}
	return {"action": "move", "direction": dir}
