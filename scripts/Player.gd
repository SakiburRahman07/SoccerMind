extends CharacterBody2D

class_name Player

@export var is_team_a: bool = true
@export var role: String = "midfielder" # goalkeeper, defender, midfielder, striker

var ball: CharacterBody2D
var speed: float = 200.0

var ai: Node = null

const FIELD_BOUNDS_MIN := Vector2(32, 16)
const FIELD_BOUNDS_MAX := Vector2(1248, 704)

# Stuck detection and recovery
var _last_position: Vector2 = Vector2.ZERO
var _still_time: float = 0.0
var _force_seek_timer: float = 0.0

func setup(_ball: CharacterBody2D, _ai: Node) -> void:
	ball = _ball
	ai = _ai
	ai.set("player", self)
	ai.set("ball", ball)
	add_child(ai)

func _physics_process(delta: float) -> void:
	# If recovering from a stuck state, temporarily ignore AI and seek the ball
	if _force_seek_timer > 0.0 and ball:
		var seek_dir: Vector2 = (ball.global_position - global_position).normalized()
		velocity = seek_dir * speed
		move_and_slide()
		_force_seek_timer = max(0.0, _force_seek_timer - delta)
		# Clamp within bounds and exit early to avoid double move
		global_position.x = clamp(global_position.x, FIELD_BOUNDS_MIN.x, FIELD_BOUNDS_MAX.x)
		global_position.y = clamp(global_position.y, FIELD_BOUNDS_MIN.y, FIELD_BOUNDS_MAX.y)
		_update_stuck_timer(delta)
		return

	if ai:
		if ai.has_method("decide"):
			var decision: Dictionary = ai.decide()
			# Treat idle as minimal movement toward ball to avoid deadlocks
			if decision.get("action", "") == "idle" and ball:
				var idle_dir: Vector2 = (ball.global_position - global_position).normalized()
				velocity = idle_dir * (speed * 0.5)
				move_and_slide()
			else:
				_apply_decision(decision, delta)
		else:
			# Safe fallback: drift toward ball so player never halts due to missing AI method
			if ball:
				var drift_dir: Vector2 = (ball.global_position - global_position).normalized()
				velocity = drift_dir * (speed * 0.6)
				move_and_slide()

	# Keep players inside the playable field
	global_position.x = clamp(global_position.x, FIELD_BOUNDS_MIN.x, FIELD_BOUNDS_MAX.x)
	global_position.y = clamp(global_position.y, FIELD_BOUNDS_MIN.y, FIELD_BOUNDS_MAX.y)

	_update_stuck_timer(delta)
	# If barely moving for a short while, consider stuck: reset AI and force seek ball
	if _still_time > 0.8:
		if ai and ai.has_method("reset"):
			ai.reset()
		_force_seek_timer = 1.5
		_still_time = 0.0

func _update_stuck_timer(delta: float) -> void:
	var moved: float = global_position.distance_to(_last_position)
	if moved < 1.0:
		_still_time += delta
	else:
		_still_time = 0.0
	_last_position = global_position

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
