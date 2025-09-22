extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var target_x: float = 58.0 if player.is_team_a else -58.0
	var dir: Vector3 = (ball.global_transform.origin - player.global_transform.origin).normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.0:
		var toward_goal: Vector3 = Vector3(target_x, 0, player.global_transform.origin.z) - player.global_transform.origin
		return {"action": "kick", "force": 24.0, "direction": toward_goal.normalized()}
	return {"action": "move", "direction": dir}


