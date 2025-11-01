extends Node

var player: Node
var ball: CharacterBody3D

# Shallow minimax with alpha-beta pruning over two actions: move vs pass
# Heuristic: field advancement, possession safety, team spacing
func decide() -> Dictionary:
	# Try to re-acquire references if lost
	if not player:
		player = get_parent()
	if not ball and player:
		ball = player.ball
	
	if not player or not ball:
		return {"action": "idle"}
	var mates := get_tree().get_nodes_in_group("team_a" if player.is_team_a else "team_b")
	var opps := get_tree().get_nodes_in_group("team_b" if player.is_team_a else "team_a")
	var to_ball: Vector3 = ball.global_transform.origin - player.global_transform.origin
	if to_ball.length() < 2.0:
		# Consider pass vs dribble
		var pass_move := _best_pass(mates, opps)
		var dribble_move := _dribble_forward()
		# Heuristic evaluation
		var pass_score: float = _eval_state(pass_move)
		var dribble_score: float = _eval_state(dribble_move)
		if pass_score >= dribble_score:
			return pass_move
		else:
			return dribble_move
	# Otherwise move toward advantageous lane
	return {"action": "move", "direction": _lane_seek()}

func _best_pass(mates: Array, opps: Array) -> Dictionary:
	var fuzzy: Node = load("res://scripts3d/Fuzzy3D.gd").new()
	var pick: Dictionary = fuzzy.pick_teammate_and_style(player, mates, opps, player.is_team_a)
	var target: Vector3 = pick.get("target", player.global_transform.origin + Vector3((1.0 if player.is_team_a else -1.0) * 7.0, 0, 0))
	var lob: bool = pick.get("lob", false)
	var dir_pass: Vector3 = (target - ball.global_transform.origin)
	var min_opp: float = 9999.0
	for o in opps:
		var d: float = o.global_transform.origin.distance_to(target)
		if d < min_opp:
			min_opp = d
	var pressure: float = clamp(1.0 - min_opp / 10.0, 0.0, 1.0)
	var distance: float = dir_pass.length()
	var force: float = fuzzy.decide_pass_force(distance, pressure)
	if lob:
		dir_pass.y = 5.5
	return {"action": "kick", "force": force, "direction": dir_pass}

func _dribble_forward() -> Dictionary:
	var team_dir := 1.0 if player.is_team_a else -1.0
	var forward: Vector3 = Vector3(team_dir * 1.0, 0, randf_range(-0.5, 0.5))
	return {"action": "move", "direction": forward}

func _lane_seek() -> Vector3:
	var target_x: float = 30.0 * (1.0 if player.is_team_a else -1.0)
	var aim: Vector3 = Vector3(target_x, 0, clamp(ball.global_transform.origin.z, -12.0, 12.0))
	return (aim - player.global_transform.origin).normalized()

func _eval_state(move: Dictionary) -> float:
	var score: float = 0.0
	if move.get("action", "") == "kick":
		# Favor kicks that advance and have vertical component (lob)
		var dir: Vector3 = move.get("direction", Vector3.ZERO)
		score += abs(dir.x) * 0.8
		score += max(0.0, dir.y) * 0.2
		score += 2.0
	else:
		# Favor moving toward ball x and centering on z
		var dirm: Vector3 = move.get("direction", Vector3.ZERO)
		score += abs(dirm.x) * 0.5
		score += (0.5 - abs(dirm.z) * 0.1)
	return score
