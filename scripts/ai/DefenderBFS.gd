extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
	if not player or not ball:
		return {"action": "idle"}
	# BFS flavor: waypoint between own goal and ball (flip applied)
	var goal_x: float = 1200.0 if player.is_team_a else 80.0
	var goal_pos: Vector2 = Vector2(goal_x, 360)
	var waypoint: Vector2 = goal_pos.lerp(ball.global_position, 0.45)
	var dir: Vector2 = (waypoint - player.global_position).normalized()
	if player.global_position.distance_to(ball.global_position) < 36.0:
		return {"action": "kick", "force": 380.0}
	return {"action": "move", "direction": dir}


