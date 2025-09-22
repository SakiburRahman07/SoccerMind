extends Node

var player: Node
var ball: CharacterBody3D

# Simple DFS-style exploration of a few candidate intercept points along a ray from goal to ball.
func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var home: Vector3 = player.home_position if player and player.has_method("set_home_position") else player.global_transform.origin
	var goal_pos := Vector3(-58.0 if player.is_team_a else 58.0, 0, 0)
	var ray: Vector3 = (ball.global_transform.origin - goal_pos)
	ray.y = 0.0
	var samples := [0.2, 0.35, 0.5, 0.65, 0.8]
	var best_target: Vector3 = ball.global_transform.origin
	var best_score: float = -INF
	# Depth-first over samples; stop early if we find a strong intercept close to player
	for t in samples:
		var candidate: Vector3 = goal_pos + ray * t
		var dist_player: float = player.global_transform.origin.distance_to(candidate)
		var dist_ball: float = ball.global_transform.origin.distance_to(candidate)
		var shape_bias: float = 0.2 * player.global_transform.origin.distance_to(home)
		var score: float = -dist_player - shape_bias - 0.3 * dist_ball
		if score > best_score:
			best_score = score
			best_target = candidate
		if dist_player < 3.0:
			break
	var to_target: Vector3 = (best_target - player.global_transform.origin)
	var dir: Vector3 = to_target.normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.5:
		# Clear toward flanks
		var clear_z := randf_range(-6.0, 6.0)
		var team_dir := -1.0 if player.is_team_a else 1.0
		return {"action": "kick", "force": 16.0, "direction": Vector3(team_dir * 10.0, 0, clear_z)}
	return {"action": "move", "direction": dir}
