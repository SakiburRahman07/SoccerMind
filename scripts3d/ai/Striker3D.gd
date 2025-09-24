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
	if dist < 2.8:
		# Fuzzy shoot/pass selection based on angle, distance, and pressure
		var forward_sign: float = -1.0 if player.is_team_a else 1.0
		var to_goal: Vector3 = Vector3(target_x, 0, clamp(ball.global_transform.origin.z, -30.0, 30.0)) - player.global_transform.origin
		var angle_cos: float = to_ball.normalized().dot(to_goal.normalized())
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var min_opp_ball: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(ball.global_transform.origin)
			if d < min_opp_ball:
				min_opp_ball = d
		var pressure: float = clamp(1.0 - min_opp_ball / 10.0, 0.0, 1.0)
		var near: float = clamp(1.0 - dist / 10.0, 0.0, 1.0)
		var aligned: float = clamp((angle_cos + 1.0) * 0.5, 0.0, 1.0)
		var shoot_w: float = aligned * (near * 0.6 + (1.0 - pressure) * 0.4)
		var pass_w: float = (1.0 - aligned) * (pressure * 0.6 + (1.0 - near) * 0.4)
		if shoot_w >= pass_w:
			# Aim away from goalkeeper position (far post logic)
			var keeper_z: float = 0.0
			var have_gk: bool = false
			for o in opps:
				if o is Player3D and o.role == "goalkeeper":
					keeper_z = o.global_transform.origin.z
					have_gk = true
					break
			var aim_z: float = player.global_transform.origin.z
			if have_gk:
				var away_sign: float = 1.0 if (player.global_transform.origin.z < keeper_z) else -1.0
				aim_z = clamp(keeper_z + away_sign * randf_range(5.0, 8.5), -30.0, 30.0)
			else:
				# No GK found: favor corners
				aim_z = clamp(player.global_transform.origin.z + randf_range(-6.0, 6.0), -30.0, 30.0)
			var shot_dir: Vector3 = Vector3(target_x, 0.0, aim_z) - ball.global_transform.origin
			# Add slight lift to reduce blocks
			shot_dir.y = 1.2
			var base_force: float = 20.0 + clamp(dist, 0.0, 7.0) * 1.4
			var force: float = clamp(base_force + (1.0 - pressure) * 6.0, 18.0, 30.0)
			return {"action": "kick", "force": force, "direction": shot_dir}
		else:
			# Use fuzzy teammate selection for a pass
			var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
			var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
			var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
			var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3(forward_sign * 6.0, 0, 0))
			var dir_pass: Vector3 = (target - ball.global_transform.origin)
			var distance: float = dir_pass.length()
			var force: float = fuzzy.decide_pass_force(distance, pressure)
			if pick.get("lob", false):
				dir_pass.y = 5.0
			return {"action": "kick", "force": force, "direction": dir_pass}
	return {"action": "move", "direction": dir}
