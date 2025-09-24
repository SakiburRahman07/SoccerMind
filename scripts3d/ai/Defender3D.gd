extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	# Own goal position (to defend): Team A own goal at +58, Team B at -58
	var goal_pos := Vector3(58.0 if player.is_team_a else -58.0, 0, 0)
	var intercept := goal_pos.lerp(ball.global_transform.origin, 0.25)
	var desire: Vector3 = (intercept - player.global_transform.origin)
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.5
	var dir: Vector3 = (desire + keep_shape).normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.5:
		# Decide between a safer pass to a nearby teammate or a clearance, with fuzzy force
		var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
		var pass_target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((-1.0 if player.is_team_a else 1.0) * 6.0, 0, randf_range(-4.0, 4.0)))
		var dir_pass: Vector3 = (pass_target - ball.global_transform.origin)
		# Compute pressure around target; if too high, fallback to clearance
		var min_opp: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(pass_target)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		if pressure < 0.7:
			var distance: float = dir_pass.length()
			var force_pass: float = fuzzy.decide_pass_force(distance, pressure)
			return {"action": "kick", "force": force_pass, "direction": dir_pass}
		# Clearance toward flanks
		var clear_z := randf_range(-6.0, 6.0)
		var team_dir := -1.0 if player.is_team_a else 1.0
		var clear_x := team_dir * 12.0
		return {"action": "kick", "force": 18.0, "direction": Vector3(clear_x, 0, clear_z)}
	return {"action": "move", "direction": dir}
