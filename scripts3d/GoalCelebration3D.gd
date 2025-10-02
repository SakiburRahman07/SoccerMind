extends Control

class_name GoalCelebration3D

# Goal celebration effect system
@onready var celebration_label: Label = $CelebrationLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: CPUParticles2D = $ParticleEffect

var celebration_timer: float = 0.0
var celebration_duration: float = 3.0

func _ready() -> void:
	# Set up the celebration UI
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0  # Start invisible
	
	# Create celebration label if not exists
	if not celebration_label:
		celebration_label = Label.new()
		add_child(celebration_label)
		celebration_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		celebration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		celebration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set up particles if not exists
	if not particles:
		particles = CPUParticles2D.new()
		add_child(particles)
		_setup_particles()

func _setup_particles() -> void:
	if not particles:
		return
	
	particles.position = get_viewport().get_visible_rect().size / 2.0
	particles.emitting = false
	particles.amount = 100
	particles.lifetime = 2.0
	particles.texture = null  # Will use default
	
	# Emission
	particles.emission_burst_count = 50
	
	# Direction and spread
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	
	# Gravity and physics
	particles.gravity = Vector2(0, 98)
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	
	# Scale and color
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color.YELLOW

func play_celebration(team_name: String) -> void:
	# Set celebration text
	if celebration_label:
		celebration_label.text = "GOAL!\n%s SCORES!" % team_name
		
		# Create label settings for the celebration
		var label_settings = LabelSettings.new()
		label_settings.font_size = 48
		label_settings.outline_size = 4
		label_settings.outline_color = Color.BLACK
		label_settings.font_color = Color.YELLOW
		celebration_label.label_settings = label_settings
	
	# Start particle effect
	if particles:
		particles.emitting = true
		particles.restart()
	
	# Animate the celebration
	_animate_celebration()
	
	# Set timer
	celebration_timer = celebration_duration

func _animate_celebration() -> void:
	# Create tween for smooth animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Scale animation for the label
	if celebration_label:
		celebration_label.scale = Vector2(0.5, 0.5)
		tween.tween_property(celebration_label, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(celebration_label, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.5)
	
	# Fade out after duration
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(celebration_duration - 0.5)
	
	# Clean up after animation
	tween.tween_callback(_cleanup_celebration).set_delay(celebration_duration)

func _process(delta: float) -> void:
	if celebration_timer > 0.0:
		celebration_timer -= delta
		
		# Stop particles halfway through
		if celebration_timer < celebration_duration / 2.0 and particles and particles.emitting:
			particles.emitting = false

func _cleanup_celebration() -> void:
	# Stop particles
	if particles:
		particles.emitting = false
	
	# Remove from scene
	queue_free()
