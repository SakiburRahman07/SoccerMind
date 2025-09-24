extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	# Simple heuristic: move towards ball; if near opponent goal line, kick hard
	var target_x: float = 1180.0 if player.is_team_a else 100.0
	var dir: Vector2 = (ball.global_position - player.global_position).normalized()
	if player.global_position.distance_to(ball.global_position) < 42.0:
		var toward_goal: Vector2 = Vector2(target_x, player.global_position.y) - player.global_position
		return {"action": "kick", "force": 600.0, "direction": toward_goal.normalized()}
	return {"action": "move", "direction": dir}
