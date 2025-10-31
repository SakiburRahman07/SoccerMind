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
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	var desire: Vector3 = to_ball
	var keep_shape: Vector3 = (home - player.global_transform.origin) * 0.4  # BALANCED formation constraint
	var dir: Vector3 = (desire + keep_shape).normalized()
	
	# BALANCED action range for midfielders
	if to_ball.length() < 2.5:  # REDUCED to balanced range
		# Check for shooting opportunity first
		var opponent_goal_x: float = -58.0 if player.is_team_a else 58.0
		var distance_to_goal: float = abs(ball.global_transform.origin.x - opponent_goal_x)
		
		# BALANCED shooting - only shoot from good positions
		if distance_to_goal < 20.0:  # REDUCED to reasonable shooting range
			var to_goal: Vector3 = Vector3(opponent_goal_x, 0, 0) - ball.global_transform.origin
			var angle_cos: float = to_ball.normalized().dot(to_goal.normalized())
			
			# BALANCED angle requirement - need good angle to goal
			if angle_cos > 0.6:  # INCREASED for better shot selection
				var shot_dir: Vector3 = to_goal
				shot_dir.y = 1.0  # REDUCED lift for more accuracy
				var force: float = 16.0  # REDUCED power for balance
				return {"action": "kick", "force": force, "direction": shot_dir}
		
		# Fuzzy passing to best teammate with fuzzy force selection
		var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
		var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
		var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
		var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
		var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((-1.0 if player.is_team_a else 1.0) * 8.0, 0, 0))
		var lob: bool = pick.get("lob", false)
		var dir_pass: Vector3 = (target - ball.global_transform.origin)
		# Estimate pressure near target by nearest opponent
		var min_opp: float = 9999.0
		for o in opps:
			var d: float = o.global_transform.origin.distance_to(target)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		var distance: float = dir_pass.length()
		var force: float = fuzzy.decide_pass_force(distance, pressure)
		if lob:
			dir_pass.y = 3.0  # REDUCED lob height for balance
		return {"action": "kick", "force": force, "direction": dir_pass}
	return {"action": "move", "direction": dir}
