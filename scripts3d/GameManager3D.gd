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
var ball_radius: float = 0.5  # Approx ball radius for precise goal-line decisions

# Match statistics
var shots_a: int = 0
var shots_b: int = 0
var passes_a: int = 0
var passes_b: int = 0

# Transient tracking for pass/shot detection
var _last_kick_time: float = -9999.0
var _last_kick_team_a: bool = true
var _last_kick_kicker_id: int = -1
var _last_kick_pass_logged: bool = false
var _last_kick_shot_logged: bool = false

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
	# Make discoverable to other nodes (e.g., Ball) for audio callbacks
	if not is_in_group("game_manager"):
		add_to_group("game_manager")
	# Initialize audio players
	_setup_audio()
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
	
	# Then check out-of-bounds: if ball leaves field area, restart from center
	# Use touchline_x for X bounds and goalline_z for Z bounds
	if not _restart_in_progress:
		if abs(pos.x) > touchline_x or abs(pos.z) > goalline_z:
			_restart_from_out_of_bounds()
	_detect_and_recover_from_stall(delta)
	_perform_health_check(delta)
	_update_stats_detection(delta)

func register_kick(by_team_a: bool, kicker_id: int, direction: Vector3, force: float) -> void:
	# Called by players when they kick the ball
	_last_kick_time = Time.get_unix_time_from_system()
	_last_kick_team_a = by_team_a
	_last_kick_kicker_id = kicker_id
	_last_kick_pass_logged = false
	_last_kick_shot_logged = false

func _update_stats_detection(_delta: float) -> void:
	if ball == null:
		return
	if _last_kick_time < 0.0:
		return
	var now: float = Time.get_unix_time_from_system()
	var since: float = now - _last_kick_time
	# Detect completed pass within 2.5s: ball received by same team player (not kicker)
	if not _last_kick_pass_logged and since <= 2.5:
		var receiver := _nearest_player(_last_kick_team_a, ball.global_transform.origin)
		if receiver and receiver is Player3D:
			var pid: int = receiver.get_instance_id()
			var dist: float = receiver.global_transform.origin.distance_to(ball.global_transform.origin)
			if pid != _last_kick_kicker_id and dist < 1.5:
				if _last_kick_team_a:
					passes_a += 1
				else:
					passes_b += 1
				_last_kick_pass_logged = true
	# Detect shot attempt within 3.0s near goal mouth
	if not _last_kick_shot_logged and since <= 3.0:
		if _is_in_shot_region(ball.global_transform.origin, _last_kick_team_a):
			if _last_kick_team_a:
				shots_a += 1
			else:
				shots_b += 1
			_last_kick_shot_logged = true
	# Expire tracking after 4s
	if since > 4.0:
		_last_kick_time = -9999.0

func _is_in_shot_region(pos: Vector3, team_a: bool) -> bool:
	# Use same post/crossbar constraints, but within 6 units of the goal plane on attacking side
	var goal_width: float = 12.0
	var goal_height: float = 7.0
	var max_goal_y: float = goal_height / 2.0
	var under_crossbar: bool = (pos.y + ball_radius) <= max_goal_y
	var between_posts: bool = abs(pos.z) <= (goal_width * 0.5)
	if not (under_crossbar and between_posts):
		return false
	var plane_x: float = 58.0 if team_a else -58.0
	# If attacking right (+58): be within [52, 58]; else [-58, -52]
	if team_a:
		return pos.x >= 52.0 and pos.x <= 58.0
	else:
		return pos.x <= -52.0 and pos.x >= -58.0

func _restart_from_out_of_bounds() -> void:
	# Whistle and immediate center restart; keep score as-is
	play_whistle_sfx()
	_reset_kickoff()

# ===================== AUDIO SYSTEM =====================

func _setup_audio() -> void:
	# Create AudioStreamPlayers for SFX and ambience. Non-fatal if files missing.
	var configs := {
		"sfx_goal": {"path": "res://assets/audio/goal.ogg", "volume_db": -2.0, "loop": false},
		"sfx_kick": {"path": "res://assets/audio/kick.ogg", "volume_db": -6.0, "loop": false},
		"sfx_whistle": {"path": "res://assets/audio/whistle.ogg", "volume_db": -4.0, "loop": false},
		"ambience_crowd": {"path": "res://assets/audio/crowd_ambience.ogg", "volume_db": -10.0, "loop": true}
	}
	for name in configs.keys():
		if get_node_or_null(name) != null:
			continue
		var p := AudioStreamPlayer.new()
		p.name = name
		var cfg = configs[name]
		var stream: AudioStream = null
		if ResourceLoader.exists(cfg.path):
			stream = load(cfg.path)
		else:
			print("[Audio] Missing sound ", cfg.path, " for ", name)
		p.stream = stream
		p.volume_db = cfg.volume_db
		p.autoplay = false
		add_child(p)
		if name == "ambience_crowd" and p.stream:
			# Loop ambience if supported
			if p.stream is AudioStreamOggVorbis:
				p.stream.loop = true
			p.play()

func _play_sfx(node_name: String) -> void:
	var p := get_node_or_null(node_name)
	if p and p is AudioStreamPlayer and p.stream:
		p.stop()
		p.play()

func play_goal_sfx() -> void:
	_play_sfx("sfx_goal")

func play_kick_sfx() -> void:
	_play_sfx("sfx_kick")

func play_whistle_sfx() -> void:
	_play_sfx("sfx_whistle")

# NEW: Manual goal checking function
func _check_for_goal(pos: Vector3) -> bool:
	# Check if ball is in goal area (X beyond ±58 and Z within goal width)
	var goal_width: float = 12.0  # Goal is 12 units wide (from Goal3D.tscn)
	var goal_height: float = 7.0  # Goal is 7 units tall (from Goal3D.tscn)
	var max_goal_y: float = goal_height / 2.0  # 3.5 units from ground (center is at y=0, so top is at 3.5)
	
	# Precise rectangle check using ball radius: fully under crossbar and between posts
	var under_crossbar: bool = (pos.y + ball_radius) <= max_goal_y
	var above_ground: bool = (pos.y - ball_radius) >= 0.0
	var between_posts: bool = abs(pos.z) <= (goal_width * 0.5 - ball_radius)
	if not (under_crossbar and above_ground and between_posts):
		return false
	
	# Left goal (X < -58)
	# Require the whole ball to cross the line: center + radius beyond plane
	if (pos.x + ball_radius) < -58.0:
		print("⚽ GOAL! Ball entered left goal at position: ", pos)
		print("⚽ Team B scores! (attacking left goal)")
		# Team B scores (attacking left goal)
		score_b += 1
		last_scorer_team_a = false
		print("⚽ Updated scores - A:", score_a, " B:", score_b)
		play_goal_sfx()
		_trigger_team_celebration(false)  # Team B celebrates
		_update_score_ui()
		_reset_kickoff()
		return true
	
	# Right goal (X > 58)
	# Require the whole ball to cross the line: center - radius beyond plane
	if (pos.x - ball_radius) > 58.0:
		print("⚽ GOAL! Ball entered right goal at position: ", pos)
		print("⚽ Team A scores! (attacking right goal)")
		# Team A scores (attacking right goal)
		score_a += 1
		last_scorer_team_a = true
		print("⚽ Updated scores - A:", score_a, " B:", score_b)
		play_goal_sfx()
		_trigger_team_celebration(true)  # Team A celebrates
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
		play_whistle_sfx()
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
			play_whistle_sfx()
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
			play_whistle_sfx()
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
		play_kick_sfx()
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
		play_whistle_sfx()
		ball.kick(kickoff_target, 6.0)

# Enhanced goal detection with backup method
func _on_goal_entered(body: Node) -> void:
	print("Goal area entered by: ", body.name if body else "unknown")
	if body != ball:
		return
	# Delegate scoring decision to precise check
	var pos := ball.global_transform.origin
	if _check_for_goal(pos):
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

func _trigger_team_celebration(celebrating_team_a: bool) -> void:
	"""Trigger celebration animations for the scoring team"""
	var celebrating_group := "team_a" if celebrating_team_a else "team_b"
	var players := get_tree().get_nodes_in_group(celebrating_group)
	
	print("🎉 Triggering celebration for ", celebrating_group)
	
	# Trigger celebration for 3 closest players to the ball
	var ball_pos = ball.global_transform.origin if ball else Vector3.ZERO
	var closest_players = []
	
	for player in players:
		if player != null and is_instance_valid(player) and player is Player3D:
			if player.has_method("trigger_celebration"):
				var distance = player.global_transform.origin.distance_to(ball_pos)
				closest_players.append({"player": player, "distance": distance})
	
	# Sort by distance and celebrate the 3 closest
	closest_players.sort_custom(func(a, b): return a.distance < b.distance)
	
	for i in min(3, closest_players.size()):
		var player_data = closest_players[i]
		var player = player_data.player
		if player != null and is_instance_valid(player) and player.has_method("trigger_celebration"):
			# Delay celebrations slightly so they don't all start at once
			var delay_timer = get_tree().create_timer(i * 0.2)
			delay_timer.timeout.connect(func(): 
				if player != null and is_instance_valid(player) and player.has_method("trigger_celebration"):
					player.trigger_celebration()
			)

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
