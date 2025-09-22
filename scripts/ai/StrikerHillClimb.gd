extends Node

var player: Node
var ball: CharacterBody2D

func decide() -> Dictionary:
    if not player or not ball:
        return {"action": "idle"}
    var to_ball: Vector2 = ball.global_position - player.global_position
    if to_ball.length() < 34.0:
        return _pick_shot()
    var sign := 1.0 if player.is_team_a else -1.0
    var lane: Vector2 = Vector2(sign, clamp((ball.global_position.y - player.global_position.y) * 0.02, -1.0, 1.0))
    return {"action": "move", "direction": lane}

func _pick_shot() -> Dictionary:
    var target_x: float = 1260.0 if player.is_team_a else 20.0
    var best_dir: Vector2 = Vector2(target_x - ball.global_position.x, 0)
    var best_score: float = -INF
    for i in 12:
        var y_off: float = randf_range(-80.0, 80.0)
        var dir: Vector2 = Vector2(target_x - ball.global_position.x, y_off)
        var score: float = _shot_score(dir)
        if score > best_score:
            best_score = score
            best_dir = dir
    return {"action": "kick", "force": 420.0, "direction": best_dir}

func _shot_score(dir: Vector2) -> float:
    var adv: float = abs(dir.x)
    var angle_penalty: float = abs(dir.y) * 0.2
    return adv * 0.8 - angle_penalty


