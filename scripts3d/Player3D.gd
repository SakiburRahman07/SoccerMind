extends CharacterBody3D

class_name Player3D

@export var is_team_a: bool = true
@export var role: String = "midfielder"

var ball: CharacterBody3D
var speed: float = 8.0
var ai: Node = null

func setup(_ball: CharacterBody3D, _ai: Node) -> void:
	ball = _ball
	ai = _ai
	ai.set("player", self)
	ai.set("ball", ball)
	add_child(ai)

func _physics_process(delta: float) -> void:
	if ai and ai.has_method("decide"):
		var d: Dictionary = ai.decide()
		_apply_decision(d)

func _apply_decision(decision: Dictionary) -> void:
	var action: String = decision.get("action", "move")
	if action == "move":
		var dir: Vector3 = decision.get("direction", Vector3.ZERO)
		velocity = dir.normalized() * speed
		move_and_slide()
	elif action == "kick":
		var to_ball: Vector3 = ball.global_transform.origin - global_transform.origin
		ball.kick(to_ball, decision.get("force", 15.0))
		velocity = Vector3.ZERO
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_and_slide()
