extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var goal_x: float = -58.0 if player.is_team_a else 58.0
	var jitter: float = randf_range(-1.0, 1.0)
	# Stay slightly in front of goal line
	var keeper_line_x: float = goal_x + (2.0 if player.is_team_a else -2.0)
	var target := Vector3(keeper_line_x, 0, clamp(ball.global_transform.origin.z + jitter, -18.0, 18.0))
	var dir: Vector3 = (target - player.global_transform.origin).normalized()
	var distance_to_ball: float = player.global_transform.origin.distance_to(ball.global_transform.origin)
	if distance_to_ball < 2.0:
		# Punch ball to flanks
		var side := randf_range(-6.0, 6.0)
		var team_dir := 1.0 if player.is_team_a else -1.0
		return {"action": "kick", "force": 20.0, "direction": Vector3(team_dir * 10.0, 0, side)}
	return {"action": "move", "direction": dir}
