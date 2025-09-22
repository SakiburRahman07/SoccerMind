extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
    if not player or not ball:
        return {"action": "idle"}
    # DFS flavor: commit toward a deeper forward waypoint before reconsidering
    var sign := 1.0 if player.is_team_a else -1.0
    var forward := Vector2(player.global_position.x + 120.0 * sign, ball.global_position.y)
    var target := forward.lerp(ball.global_position, 0.3)
    var dir: Vector2 = (target - player.global_position).normalized()
    if player.global_position.distance_to(ball.global_position) < 34.0:
        return {"action": "kick", "force": 420.0}
    return {"action": "move", "direction": dir}


