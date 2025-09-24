extends Node3D

var field: Node3D = null
var ball: CharacterBody3D = null
var goal_left: Area3D = null
var goal_right: Area3D = null

var team_a: Node = null
var team_b: Node = null
var score_label: Label = null

var score_a: int = 0
var score_b: int = 0
var last_scorer_team_a: bool = false
var touchline_x: float = 60.0
var goalline_z: float = 35.0

# Restart management
var _restart_in_progress: bool = false
var _restart_timer: Timer = null
var _frozen_players: Array = []
var _restart_taker: Node = null

# Stall detection
var _stall_timer: float = 0.0
var stall_velocity_epsilon: float = 0.2
var stall_seconds_threshold: float = 2.0

func _ready() -> void:
	field = get_node_or_null("Field3D") as Node3D
	if field == null:
		push_warning("Field3D not found under Main3D")
		return
	ball = field.get_node_or_null("Ball") as CharacterBody3D
	goal_left = field.get_node_or_null("GoalLeft") as Area3D
	goal_right = field.get_node_or_null("GoalRight") as Area3D
	score_label = get_node_or_null("CanvasLayer/Score") as Label
	_setup_goals()
	_spawn_teams()
	_reset_kickoff()
	set_process(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			var env := field.get_node_or_null("EnvironmentController")
			if env and env.has_method("toggle_day_night"):
				env.call("toggle_day_night")

func _process(delta: float) -> void:
	# Detect out-of-bounds for throw-in / corner / goal kick
	if ball == null:
		return
	var pos := ball.global_transform.origin
	if abs(pos.x) > touchline_x and not _restart_in_progress:
		_handle_throw_in(pos)
	elif abs(pos.z) > goalline_z and not _restart_in_progress:
		_handle_corner_or_goal_kick(pos)
	_detect_and_recover_from_stall(delta)

func _nearest_player(for_team_a: bool, near_pos: Vector3) -> Node:
	var group_name := "team_a" if for_team_a else "team_b"
	var players := get_tree().get_nodes_in_group(group_name)
	var best: Node = null
	var best_d: float = 1e9
	for p in players:
		var d: float = p.global_transform.origin.distance_to(near_pos)
		if d < best_d:
			best_d = d
			best = p
	return best

func _handle_throw_in(pos: Vector3) -> void:
	var _for_team_a: bool = not bool(ball.get("last_touch_team_a"))
	ball.global_transform.origin = Vector3(clamp(pos.x, -touchline_x, touchline_x), 1.0, clamp(pos.z, -goalline_z + 1.0, goalline_z - 1.0))
	ball.velocity = Vector3.ZERO
	var taker := _nearest_player(_for_team_a, ball.global_transform.origin)
	if taker:
		# Freeze other players briefly and schedule the throw
		_begin_restart(taker)
		var inward_x := -2.0 if ball.global_transform.origin.x > 0.0 else 2.0
		var throw_dir := Vector3(inward_x, 6.0, 0.0)
		_schedule_restart_kick(throw_dir, 10.0)
		# Record restart touch
		if ball.has_method("set") and taker.has_method("get") and taker.has_method("set"):
			var is_a: bool = bool(taker.get("is_team_a"))
			ball.set("last_touch_team_a", is_a)

func _handle_corner_or_goal_kick(pos: Vector3) -> void:
	# Determine if corner or goal kick based on last touch team and which goal line exited
	var last_touch_a: bool = bool(ball.get("last_touch_team_a"))
	var exited_left_goal_line: bool = pos.z > 0.0 or pos.z < 0.0 # any goalline
	var is_left_side: bool = pos.x < 0.0
	# Attacking team is opposite of defending goal. If last touch was attacker, it's goal kick; else corner
	var defending_team_a_for_this_end: bool = false if pos.z > 0.0 else true # top end defended by Team B, bottom by Team A (approx)
	var last_touch_attacking: bool = (last_touch_a != defending_team_a_for_this_end)
	if last_touch_attacking:
		# Goal kick for defending team
		var taker_is_team_a: bool = defending_team_a_for_this_end
		var goal_kick_spot := Vector3(( -touchline_x + 6.0 ) if is_left_side else ( touchline_x - 6.0 ), 1.0, (goalline_z - 2.0) * (1.0 if pos.z < 0.0 else -1.0))
		ball.global_transform.origin = goal_kick_spot
		ball.velocity = Vector3.ZERO
		var taker := _nearest_player(taker_is_team_a, ball.global_transform.origin)
		if taker:
			_begin_restart(taker)
			# Drive upfield
			var up_dir_x := -8.0 if taker_is_team_a else 8.0
			var drive := Vector3(up_dir_x, 3.0, ( -5.0 if is_left_side else 5.0 ))
			_schedule_restart_kick(drive, 14.0)
			if ball.has_method("set"):
				ball.set("last_touch_team_a", taker_is_team_a)
	else:
		# Corner for attacking team at nearest corner arc
		var taker_is_team_a_c: bool = not defending_team_a_for_this_end
		var corner_pos := Vector3(-touchline_x + 1.0 if is_left_side else touchline_x - 1.0, 1.0, (goalline_z - 1.0) * (1.0 if pos.z < 0.0 else -1.0))
		ball.global_transform.origin = corner_pos
		ball.velocity = Vector3.ZERO
		var taker_c := _nearest_player(taker_is_team_a_c, ball.global_transform.origin)
		if taker_c:
			_begin_restart(taker_c)
			# Corner: lob toward box
			var into_box := Vector3(5.0 if is_left_side else -5.0, 7.0, ( -6.0 if pos.z < 0.0 else 6.0 ))
			_schedule_restart_kick(into_box, 12.0)
			if ball.has_method("set"):
				ball.set("last_touch_team_a", taker_is_team_a_c)

func _begin_restart(taker: Node) -> void:
	_restart_in_progress = true
	_restart_taker = taker
	_freeze_all_except(taker)
	if _restart_timer == null:
		_restart_timer = Timer.new()
		_restart_timer.one_shot = true
		add_child(_restart_timer)

func _schedule_restart_kick(dir: Vector3, force: float) -> void:
	# small delay to make restart readable
	_restart_timer.wait_time = 0.6
	_restart_timer.timeout.connect(func():
		ball.kick(dir, force)
		_unfreeze_all()
		_restart_in_progress = false
		_restart_taker = null
		, CONNECT_ONE_SHOT)
	_restart_timer.start()

func _freeze_all_except(taker: Node) -> void:
	_frozen_players.clear()
	for team in [team_a, team_b]:
		if not team:
			continue
		for child in team.get_children():
			if child is Player3D:
				if child == taker:
					continue
				_frozen_players.append(child)
				child.set_physics_process(false)

func _unfreeze_all() -> void:
	for p in _frozen_players:
		if is_instance_valid(p):
			p.set_physics_process(true)
	_frozen_players.clear()

func _setup_goals() -> void:
	# Flip: Team B defends left; Team A defends right
	if goal_left:
		goal_left.set_meta("team", "B")
		goal_left.body_entered.connect(func(b): _on_goal_entered(b))
	else:
		push_warning("GoalLeft not found in Field3D")
	if goal_right:
		goal_right.set_meta("team", "A")
		goal_right.body_entered.connect(func(b): _on_goal_entered(b))
	else:
		push_warning("GoalRight not found in Field3D")

func _spawn_teams() -> void:
	var team_scene: PackedScene = load("res://scenes3d/Team3D.tscn")
	team_a = team_scene.instantiate()
	team_b = team_scene.instantiate()
	team_a.name = "TeamA"
	team_b.name = "TeamB"
	add_child(team_a)
	add_child(team_b)
	team_a.call_deferred("configure_team", true, ball)
	team_b.call_deferred("configure_team", false, ball)

func _reset_kickoff() -> void:
	ball.global_transform.origin = Vector3(0, 1, 0)
	ball.velocity = Vector3.ZERO
	if team_a and team_b:
		team_a.call_deferred("reset_positions", true)
		team_b.call_deferred("reset_positions", false)
		# Kickoff: the team that conceded restarts
		var kickoff_team: Node = team_b if last_scorer_team_a else team_a
		# Two-touch kickoff: small ground pass between two central midfielders
		var team_dir := 1.0 if kickoff_team == team_a else -1.0
		var kickoff_target := Vector3(team_dir * 2.0, 0.0, 0.0)
		ball.kick(kickoff_target, 6.0)

func _on_goal_entered(body: Node) -> void:
	if body != ball:
		return
	if goal_left and goal_left.get_overlapping_bodies().has(body):
		var goal_team: String = goal_left.get_meta("team")
		if goal_team == "A":
			score_b += 1
			last_scorer_team_a = false
		else:
			score_a += 1
			last_scorer_team_a = true
		_reset_kickoff()
		print("Score A:", score_a, " B:", score_b)
		_update_score_ui()
		return
	if goal_right and goal_right.get_overlapping_bodies().has(body):
		var goal_team_r: String = goal_right.get_meta("team")
		if goal_team_r == "A":
			score_b += 1
			last_scorer_team_a = false
		else:
			score_a += 1
			last_scorer_team_a = true
		_reset_kickoff()
		print("Score A:", score_a, " B:", score_b)
		_update_score_ui()
		return

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "A %d - %d B" % [score_a, score_b]

func _detect_and_recover_from_stall(delta: float) -> void:
	var ball_still: bool = ball and ball.velocity.length() <= stall_velocity_epsilon
	var players_still: bool = true
	for team in [team_a, team_b]:
		if not team:
			continue
		for child in team.get_children():
			if child is Player3D:
				if child.velocity.length() > stall_velocity_epsilon:
					players_still = false
					break
		if not players_still:
			break
	if ball_still and players_still:
		_stall_timer += delta
		if _stall_timer >= stall_seconds_threshold:
			_reset_kickoff()
			_stall_timer = 0.0
	else:
		_stall_timer = 0.0
