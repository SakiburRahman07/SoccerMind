extends CharacterBody2D

class_name Player

@export var is_team_a: bool = true
@export var role: String = "midfielder" # goalkeeper, defender, midfielder, striker

var ball: CharacterBody2D
var speed: float = 200.0

var ai: Node = null

func setup(_ball: CharacterBody2D, _ai: Node) -> void:
	ball = _ball
	ai = _ai
	ai.set("player", self)
	ai.set("ball", ball)
	add_child(ai)

func _physics_process(delta: float) -> void:
	if ai and ai.has_method("decide"):
		var decision: Dictionary = ai.decide()
		_apply_decision(decision, delta)

func _apply_decision(decision: Dictionary, _delta: float) -> void:
	var action: String = decision.get("action", "move")
	if action == "move":
		var dir: Vector2 = decision.get("direction", Vector2.ZERO)
		velocity = dir.normalized() * speed
		move_and_slide()
	elif action == "kick":
		var dir_k: Vector2 = decision.get("direction", (ball.global_position - global_position))
		ball.kick(dir_k, decision.get("force", 300.0))
		velocity = Vector2.ZERO
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()
