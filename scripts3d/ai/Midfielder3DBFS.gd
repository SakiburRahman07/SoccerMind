extends Node

var player: Node
var ball: CharacterBody3D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var target := Vector3(ball.global_transform.origin.x, 0, clamp(ball.global_transform.origin.z, -20.0, 20.0))
	var dir: Vector3 = (target - player.global_transform.origin).normalized()
	if player.global_transform.origin.distance_to(ball.global_transform.origin) < 2.0:
		return {"action": "kick", "force": 20.0}
	return {"action": "move", "direction": dir}


