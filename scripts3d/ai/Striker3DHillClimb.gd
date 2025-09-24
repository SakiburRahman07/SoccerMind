extends Node

var player: Node
var ball: CharacterBody3D

# Hill-climbing to pick a shot vector that maximizes heuristic (goalward, low opponent pressure)
func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	if to_ball.length() < 2.5:
		return _pick_shot()
	# Move toward a lane that leads to better shot angle
	var team_dir := 1.0 if player.is_team_a else -1.0
	var lane: Vector3 = Vector3(team_dir, 0, clamp((ball.global_transform.origin.z - player.global_transform.origin.z) * 0.2, -1.0, 1.0))
	return {"action": "move", "direction": lane}

func _pick_shot() -> Dictionary:
	var target_x: float = 58.0 if player.is_team_a else -58.0
	var best_dir: Vector3 = Vector3(target_x - ball.global_transform.origin.x, 0, 0)
	var best_score: float = -INF
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	# Explore directions by jittering z and a bit of y for chip
	for i in 12:
		var z_off: float = randf_range(-6.0, 6.0)
		var y_off: float = randf_range(0.0, 6.0)
		var dir: Vector3 = Vector3(target_x - ball.global_transform.origin.x, y_off, z_off)
		var score: float = _shot_score(dir, opps)
		if score > best_score:
			best_score = score
			best_dir = dir
	# Scale force slightly with how forward the shot is and nearby pressure
	var forwardness: float = clamp(abs(best_dir.x) / 60.0, 0.0, 1.0)
	var min_opp: float = 9999.0
	for o in opps:
		var d: float = o.global_transform.origin.distance_to(player.global_transform.origin)
		if d < min_opp:
			min_opp = d
	var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
	var force: float = clamp(22.0 + forwardness * 4.0 + pressure * 4.0, 18.0, 30.0)
	return {"action": "kick", "force": force, "direction": best_dir}

func _shot_score(dir: Vector3, opps: Array) -> float:
	var adv: float = abs(dir.x)
	var lob_bonus: float = max(0.0, dir.y) * 0.3
	var pressure: float = 0.0
	for o in opps:
		var to_o: Vector3 = o.global_transform.origin - ball.global_transform.origin
		pressure += clamp(1.0 - to_o.length() / 12.0, 0.0, 1.0)
	pressure = pressure / max(1, opps.size())
	return adv * 0.8 + lob_bonus - pressure * 0.6
