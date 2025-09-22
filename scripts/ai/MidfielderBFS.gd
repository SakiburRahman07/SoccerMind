extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	# Move towards ball but prefer center lanes (naive BFS flavor)
	var target := Vector2(ball.global_position.x, clamp(ball.global_position.y, 220.0, 500.0))
	var dir: Vector2 = (target - player.global_position).normalized()
	if player.global_position.distance_to(ball.global_position) < 34.0:
		return {"action": "kick", "force": 420.0}
	return {"action": "move", "direction": dir}


