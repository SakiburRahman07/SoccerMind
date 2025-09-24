extends Node

func decide_pass_force(distance: float, pressure: float) -> float:
	var near: float = clamp(1.0 - distance / 20.0, 0.0, 1.0)
	var far_val: float = 1.0 - near
	var low_pressure: float = clamp(1.0 - pressure, 0.0, 1.0)
	var high_pressure: float = 1.0 - low_pressure
	var slow_w: float = near * low_pressure
	var medium_w: float = near * high_pressure + far_val * low_pressure
	var fast_w: float = far_val * high_pressure
	var sum_w: float = slow_w + medium_w + fast_w + 0.0001
	return (slow_w * 8.0 + medium_w * 14.0 + fast_w * 24.0) / sum_w

func pick_teammate_and_style(player: Node, teammates: Array, opponents: Array, is_team_a: bool) -> Dictionary:
	# Choose a teammate ahead with low opponent pressure. Return {target: Vector3, lob: bool}
	var best_target: Vector3 = Vector3.ZERO
	var best_score: float = -INF
	for t in teammates:
		if t == player:
			continue
		var to_t: Vector3 = t.global_transform.origin - player.global_transform.origin
		# Team A attacks toward -X (left), Team B toward +X (right)
		var forward_sign: float = -1.0 if is_team_a else 1.0
		var ahead: bool = (to_t.x * forward_sign) > 0.0
		var dist: float = to_t.length()
		if dist < 1.0:
			continue
		# Pressure = distance to nearest opponent near the line between player and teammate (approx: just nearest to teammate)
		var min_opp: float = 9999.0
		for o in opponents:
			var d: float = o.global_transform.origin.distance_to(t.global_transform.origin)
			if d < min_opp:
				min_opp = d
		var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
		var forward_bonus: float = 0.5 if ahead else 0.0
		var spacing_bonus: float = clamp(dist / 15.0, 0.0, 1.0)
		var safety: float = 1.0 - pressure
		var score: float = safety * 0.6 + forward_bonus * 0.2 + spacing_bonus * 0.2
		if score > best_score:
			best_score = score
			best_target = t.global_transform.origin
	var use_lob: bool = best_score > 0.55 and randf() < 0.5
	return {"target": best_target, "lob": use_lob}

# Resolve kick direction/force when two nearby players want different shots
# Returns {direction: Vector3, force: float}
func resolve_kick_conflict(player_a: Node, player_b: Node, dir_a: Vector3, force_a: float, ball: CharacterBody3D, teammates: Array, opponents: Array, is_team_a: bool) -> Dictionary:
	var dir_b: Vector3 = player_b.get("last_kick_intent_dir") if player_b and player_b.has_method("get") else Vector3.ZERO
	var force_b: float = player_b.get("last_kick_intent_force") if player_b and player_b.has_method("get") else 0.0
	if dir_b == Vector3.ZERO:
		return {"direction": dir_a, "force": force_a}
	var ndir_a: Vector3 = dir_a.normalized()
	var ndir_b: Vector3 = dir_b.normalized()
	# Goal alignment
	var target_x: float = -58.0 if is_team_a else 58.0
	var to_goal: Vector3 = Vector3(target_x, 0.0, clamp(ball.global_transform.origin.z, -30.0, 30.0)) - ball.global_transform.origin
	var goal_align_a: float = clamp(ndir_a.dot(to_goal.normalized()), -1.0, 1.0)
	var goal_align_b: float = clamp(ndir_b.dot(to_goal.normalized()), -1.0, 1.0)
	# Opponent pressure along ray (approx): nearest opponent to ray end
	var end_a: Vector3 = ball.global_transform.origin + ndir_a * 8.0
	var end_b: Vector3 = ball.global_transform.origin + ndir_b * 8.0
	var min_opp_a: float = 9999.0
	var min_opp_b: float = 9999.0
	for o in opponents:
		var da: float = o.global_transform.origin.distance_to(end_a)
		var db: float = o.global_transform.origin.distance_to(end_b)
		if da < min_opp_a:
			min_opp_a = da
		if db < min_opp_b:
			min_opp_b = db
	var space_a: float = clamp(min_opp_a / 10.0, 0.0, 1.0)
	var space_b: float = clamp(min_opp_b / 10.0, 0.0, 1.0)
	# Teammate blocking risk along ray
	var block_a: float = 0.0
	var block_b: float = 0.0
	for t in teammates:
		if t == player_a or t == player_b:
			continue
		if _point_along_ray(ball.global_transform.origin, ndir_a, t.global_transform.origin, 2.0):
			block_a += 1.0
		if _point_along_ray(ball.global_transform.origin, ndir_b, t.global_transform.origin, 2.0):
			block_b += 1.0
	block_a = clamp(block_a, 0.0, 2.0)
	block_b = clamp(block_b, 0.0, 2.0)
	# Conflict angle: penalize strong opposition
	var conflict: float = clamp(1.0 - max(0.0, ndir_a.dot(ndir_b)), 0.0, 1.0)
	# Fuzzy weights
	var score_a: float = goal_align_a * 0.45 + space_a * 0.35 - block_a * 0.2 - conflict * 0.1
	var score_b: float = goal_align_b * 0.45 + space_b * 0.35 - block_b * 0.2 - conflict * 0.1
	# Choose or blend
	var chosen_dir: Vector3 = ndir_a
	var chosen_force: float = force_a
	if abs(score_a - score_b) < 0.1:
		# Blend toward the more goal-aligned
		var w_a: float = clamp((goal_align_a + 1.0) * 0.5, 0.0, 1.0)
		var w_b: float = clamp((goal_align_b + 1.0) * 0.5, 0.0, 1.0)
		chosen_dir = (ndir_a * w_a + ndir_b * w_b)
		if chosen_dir.length() < 0.001:
			chosen_dir = ndir_a
		chosen_dir = chosen_dir.normalized()
		chosen_force = max(force_a, force_b)
	elif score_b > score_a:
		chosen_dir = ndir_b
		chosen_force = force_b
	# Slightly increase force under pressure
	var pressure: float = 1.0 - max(space_a, space_b)
	chosen_force = clamp(chosen_force + pressure * 3.0, 8.0, 30.0)
	return {"direction": chosen_dir, "force": chosen_force}

func _point_along_ray(origin: Vector3, dir: Vector3, point: Vector3, radius: float) -> bool:
	var to_p: Vector3 = point - origin
	var proj: float = to_p.dot(dir)
	if proj < 0.0:
		return false
	var closest: Vector3 = origin + dir * proj
	return closest.distance_to(point) <= radius
