extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var goal_pos := Vector3(-58.0 if player.is_team_a else 58.0, 0, 0)
	var intercept := goal_pos.lerp(ball.global_transform.origin, 0.25)
	var dir: Vector3 = (intercept - player.global_transform.origin).normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.0:
		return {"action": "kick", "force": 18.0}
	return {"action": "move", "direction": dir}


