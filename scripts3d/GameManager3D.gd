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

# Game health monitoring
var health_check_timer: float = 0.0
var health_check_interval: float = 10.0  # Check every 10 seconds

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
		elif event.keycode == KEY_R:
			# Manual restart for testing
			print("Manual restart triggered")
			_reset_kickoff()

func _process(delta: float) -> void:
	if ball == null:
		return
	
	var pos := ball.global_transform.origin
	
	# CRITICAL FIX: Check for goals FIRST before out-of-bounds
	# Goals are at X = ±58, so check if ball crossed goal line
	if not _restart_in_progress:
		if _check_for_goal(pos):
			return  # Goal scored, don't check out of bounds
	
	# Then check out-of-bounds for throw-in / corner / goal kick
	# INCREASED touchline to 65 to give more space for goals
	if abs(pos.x) > 65.0 and not _restart_in_progress:
		_handle_throw_in(pos)
	elif abs(pos.z) > goalline_z and not _restart_in_progress:
		_handle_corner_or_goal_kick(pos)
	_detect_and_recover_from_stall(delta)
	_perform_health_check(delta)

# NEW: Manual goal checking function
func _check_for_goal(pos: Vector3) -> bool:
	# Check if ball is in goal area (X beyond ±58 and Z within goal width)
	var goal_width: float = 12.0  # Goal is 12 units wide (from Goal3D.tscn)
	
	# Left goal (X < -58)
	if pos.x < -58.0 and abs(pos.z) < goal_width / 2.0:
		print("⚽ GOAL! Ball entered left goal at position: ", pos)
		print("⚽ Team B scores! (attacking left goal)")
		# Team B scores (attacking left goal)
		score_b += 1
		last_scorer_team_a = false
		print("⚽ Updated scores - A:", score_a, " B:", score_b)
		_update_score_ui()
		_reset_kickoff()
		return true
	
	# Right goal (X > 58)
	if pos.x > 58.0 and abs(pos.z) < goal_width / 2.0:
		print("⚽ GOAL! Ball entered right goal at position: ", pos)
		print("⚽ Team A scores! (attacking right goal)")
		# Team A scores (attacking right goal)
		score_a += 1
		last_scorer_team_a = true
		print("⚽ Updated scores - A:", score_a, " B:", score_b)
		_update_score_ui()
		_reset_kickoff()
		return true
	
	return false

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
	else:
		# Safety: no taker found → ensure nobody remains frozen
		_unfreeze_all()

func _handle_corner_or_goal_kick(pos: Vector3) -> void:
	# Determine if corner or goal kick based on last touch team and which goal line exited
	var last_touch_a: bool = bool(ball.get("last_touch_team_a"))
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
			# Safety: ensure game resumes even if no taker was found
			_unfreeze_all()
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
			var lob_dir := Vector3((-1.0 if is_left_side else 1.0) * 12.0, 8.0, (-1.0 if pos.z < 0.0 else 1.0) * 8.0)
			_schedule_restart_kick(lob_dir, 16.0)
			if ball.has_method("set"):
				ball.set("last_touch_team_a", taker_is_team_a_c)
		else:
			# Safety: ensure game resumes even if no taker was found
			_unfreeze_all()

func _begin_restart(taker: Node) -> void:
	_restart_in_progress = true
	_restart_taker = taker
	# Freeze all players except the taker
	for team in [team_a, team_b]:
		if not team:
			continue
		for child in team.get_children():
			if child is Player3D and child != taker:
				_frozen_players.append(child)
				child.set_physics_process(false)

func _schedule_restart_kick(direction: Vector3, force: float) -> void:
	# Create a timer for the restart kick
	if _restart_timer:
		_restart_timer.queue_free()
	_restart_timer = Timer.new()
	_restart_timer.wait_time = 1.0
	_restart_timer.one_shot = true
	_restart_timer.timeout.connect(_execute_restart_kick.bind(direction, force))
	add_child(_restart_timer)
	_restart_timer.start()

func _execute_restart_kick(direction: Vector3, force: float) -> void:
	if ball and _restart_taker:
		ball.kick(direction, force)
	_unfreeze_all()
	_restart_in_progress = false
	_restart_taker = null
	if _restart_timer:
		_restart_timer.queue_free()
		_restart_timer = null

func _unfreeze_all() -> void:
	# Robust unfreezing - ensure ALL players are unfrozen, not just the tracked ones
	for team in [team_a, team_b]:
		if not team:
			continue
		for child in team.get_children():
			if child is Player3D:
				child.set_physics_process(true)
	_frozen_players.clear()
	
	# Emergency unfreezing: get all players in groups too
	var all_players_a = get_tree().get_nodes_in_group("team_a")
	var all_players_b = get_tree().get_nodes_in_group("team_b")
	for p in all_players_a + all_players_b:
		if p is Player3D:
			p.set_physics_process(true)

func _setup_goals() -> void:
	# Enhanced goal setup with better detection
	if goal_left:
		goal_left.set_meta("team", "B")
		# Connect both body_entered and body_exited for better detection
		if not goal_left.body_entered.is_connected(_on_goal_entered):
			goal_left.body_entered.connect(_on_goal_entered)
		print("GoalLeft setup complete at position: ", goal_left.global_position)
	else:
		push_warning("GoalLeft not found in Field3D")
	if goal_right:
		goal_right.set_meta("team", "A")
		if not goal_right.body_entered.is_connected(_on_goal_entered):
			goal_right.body_entered.connect(_on_goal_entered)
		print("GoalRight setup complete at position: ", goal_right.global_position)
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
		# Re-configure teams to ensure ball references are maintained
		team_a.call_deferred("configure_team", true, ball)
		team_b.call_deferred("configure_team", false, ball)
		team_a.call_deferred("reset_positions", true)
		team_b.call_deferred("reset_positions", false)
		# Kickoff: the team that conceded restarts
		var kickoff_team: Node = team_b if last_scorer_team_a else team_a
		# Two-touch kickoff: small ground pass between two central midfielders
		var team_dir := 1.0 if kickoff_team == team_a else -1.0
		var kickoff_target := Vector3(team_dir * 2.0, 0.0, 0.0)
		ball.kick(kickoff_target, 6.0)

# Enhanced goal detection with backup method
func _on_goal_entered(body: Node) -> void:
	print("Goal area entered by: ", body.name if body else "unknown")
	if body != ball:
		return
	
	# Determine which goal was entered and award point to attacking team
	if goal_left and goal_left.get_overlapping_bodies().has(body):
		print("GOAL! Ball entered left goal via Area3D detection")
		# Team A scores (attacking left goal)
		score_a += 1
		last_scorer_team_a = true
		_reset_kickoff()
		print("Score A:", score_a, " B:", score_b)
		_update_score_ui()
		return
	
	if goal_right and goal_right.get_overlapping_bodies().has(body):
		print("GOAL! Ball entered right goal via Area3D detection")
		# Team B scores (attacking right goal)
		score_b += 1
		last_scorer_team_a = false
		_reset_kickoff()
		print("Score A:", score_a, " B:", score_b)
		_update_score_ui()
		return

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "A %d - %d B" % [score_a, score_b]
	
	# Trigger goal celebration effects
	var particle_effects = get_node_or_null("SimpleParticleEffects")
	if particle_effects and particle_effects.has_method("trigger_goal_celebration"):
		# Determine which goal was scored into based on the last scorer
		var is_left_goal_scored = not last_scorer_team_a  # If Team A scored, it was into the right goal
		particle_effects.trigger_goal_celebration(is_left_goal_scored)

func _detect_and_recover_from_stall(delta: float) -> void:
	if not ball:
		return
	var ball_vel := Vector3(ball.velocity.x, 0.0, ball.velocity.z).length()
	if ball_vel < stall_velocity_epsilon:
		_stall_timer += delta
	else:
		_stall_timer = 0.0
	if _stall_timer > stall_seconds_threshold:
		print("Ball stall detected - nudging toward nearest player")
		var nearest: Node = _nearest_player(true, ball.global_transform.origin)
		if not nearest:
			nearest = _nearest_player(false, ball.global_transform.origin)
		if nearest:
			# Fixed type inference issue by explicitly typing the Vector3
			var nudge_dir: Vector3 = nearest.global_transform.origin - ball.global_transform.origin
			nudge_dir.y = 0.0
			if nudge_dir.length() > 0.01:
				ball.velocity += nudge_dir.normalized() * 3.0
		_stall_timer = 0.0

func _perform_health_check(delta: float) -> void:
	health_check_timer += delta
	if health_check_timer >= health_check_interval:
		health_check_timer = 0.0
		# Check if teams and ball are still valid
		if not ball:
			push_error("Ball reference lost!")
		if not team_a or not team_b:
			push_error("Team reference lost!")
		# Check if any players are stuck
		var stuck_players := 0
		for team in [team_a, team_b]:
			if team:
				for child in team.get_children():
					if child is Player3D:
						var player: Player3D = child
						if player.velocity.length() < 0.1:
							stuck_players += 1
		if stuck_players > 8:  # More than 8 players stuck
			print("Many players stuck - performing emergency reset")
			_reset_kickoff()