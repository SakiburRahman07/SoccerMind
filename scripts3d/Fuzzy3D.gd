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
