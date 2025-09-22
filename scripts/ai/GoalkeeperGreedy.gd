extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
    if not player or not ball:
        return {"action": "idle"}
    # Greedy: stay near goal line and move directly to line up with ball
    var goal_x: float = 80.0 if player.is_team_a else 1200.0
    var clamp_y := clamp(ball.global_position.y, 260.0, 460.0)
    var target := Vector2(goal_x, clamp_y)
    var dir: Vector2 = (target - player.global_position).normalized()
    if player.global_position.distance_to(ball.global_position) < 36.0:
        return {"action": "kick", "force": 360.0}
    return {"action": "move", "direction": dir}


