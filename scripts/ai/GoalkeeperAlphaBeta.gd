extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	var goal_x: float = 80.0 if player.is_team_a else 1200.0
	var target := Vector2(goal_x, clamp(ball.global_position.y, 160.0, 560.0))
	var dir: Vector2 = (target - player.global_position).normalized()
	var distance_to_ball: float = player.global_position.distance_to(ball.global_position)
	if distance_to_ball < 30.0:
		return {"action": "kick", "force": 450.0}
	return {"action": "move", "direction": dir}
