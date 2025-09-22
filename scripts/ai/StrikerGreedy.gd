extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
    if not player or not ball:
        return {"action": "idle"}
    # Greedy striker: beeline to ball, shoot with higher force when close
    var dir: Vector2 = (ball.global_position - player.global_position).normalized()
    if player.global_position.distance_to(ball.global_position) < 30.0:
        var target_x: float = 1260.0 if player.is_team_a else 20.0
        var shot := Vector2(target_x - ball.global_position.x, 0)
        return {"action": "kick", "force": 520.0, "direction": shot}
    return {"action": "move", "direction": dir}


