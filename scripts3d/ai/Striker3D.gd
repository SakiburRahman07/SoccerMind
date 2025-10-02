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
	# Team A should shoot toward -X, Team B toward +X (flip from before)
	var target_x: float = -58.0 if player.is_team_a else 58.0
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	var desire: Vector3 = to_ball
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.1  # REDUCED formation constraint
	var dir: Vector3 = (desire + keep_shape).normalized()
	var dist: float = to_ball.length()
	
	# MASSIVELY increased shooting range for guaranteed goals
	if dist < 12.0:  # INCREASED from 6.0
		# Check if we're in a good shooting position
		var distance_to_goal: float = abs(ball.global_transform.origin.x - target_x)
		
		# ALWAYS shoot if close to goal - no passing logic
		if distance_to_goal < 40.0:  # INCREASED range
			# Aim away from goalkeeper position (far post logic)
			var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
			var keeper_z: float = 0.0
			var have_gk: bool = false
			for o in opps:
				if o is Player3D and o.role == "goalkeeper":
					keeper_z = o.global_transform.origin.z
					have_gk = true
					break
			
			var aim_z: float = ball.global_transform.origin.z
			if have_gk:
				# Aim away from goalkeeper
				var away_sign: float = 1.0 if (ball.global_transform.origin.z < keeper_z) else -1.0
				aim_z = clamp(keeper_z + away_sign * randf_range(8.0, 12.0), -30.0, 30.0)
			else:
				# No GK found: aim for corners
				aim_z = clamp(ball.global_transform.origin.z + randf_range(-8.0, 8.0), -30.0, 30.0)
			
			var shot_dir: Vector3 = Vector3(target_x, 0.0, aim_z) - ball.global_transform.origin
			# Add significant lift to beat goalkeeper
			shot_dir.y = 3.0  # INCREASED lift
			
			# MAXIMUM shot power for guaranteed goals
			var force: float = 30.0  # MAXIMUM power
			print("STRIKER SHOOTING! Distance to goal: ", distance_to_goal, " Force: ", force)
			return {"action": "kick", "force": force, "direction": shot_dir}
		
		# Fallback: still try fuzzy passing if not in shooting position
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
		
		# HEAVILY biased toward shooting
		var shoot_w: float = 0.9  # Almost always shoot
		var pass_w: float = 0.1   # Rarely pass
		
		if shoot_w >= pass_w:
			# Shoot with maximum power
			var shot_dir2: Vector3 = to_goal
			shot_dir2.y = 2.5
			var force2: float = 28.0
			return {"action": "kick", "force": force2, "direction": shot_dir2}
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