extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var goal_x: float = -58.0 if player.is_team_a else 58.0
	var target := Vector3(goal_x, 0, clamp(ball.global_transform.origin.z, -25.0, 25.0))
	var dir: Vector3 = (target - player.global_transform.origin).normalized()
	var distance_to_ball: float = player.global_transform.origin.distance_to(ball.global_transform.origin)
	if distance_to_ball < 2.0:
		return {"action": "kick", "force": 20.0}
	return {"action": "move", "direction": dir}


