extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	# Chase the ball quickly (greedy towards ball)
	var dir: Vector2 = (ball.global_position - player.global_position).normalized()
	if player.global_position.distance_to(ball.global_position) < 34.0:
		return {"action": "kick", "force": 420.0}
	return {"action": "move", "direction": dir}


