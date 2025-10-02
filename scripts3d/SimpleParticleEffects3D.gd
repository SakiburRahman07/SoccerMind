extends Node3D

class_name SimpleParticleEffects3D

# Simplified particle effects that work reliably with Godot 4.x CPUParticles3D
# This replaces the complex FieldEffects3D system with a simpler approach

var goal_celebration_left: CPUParticles3D
var goal_celebration_right: CPUParticles3D

func _ready() -> void:
	_create_simple_goal_effects()

func _create_simple_goal_effects() -> void:
	# Left goal celebration
	goal_celebration_left = CPUParticles3D.new()
	goal_celebration_left.name = "GoalCelebrationLeft"
	goal_celebration_left.position = Vector3(-58, 3, 0)
	add_child(goal_celebration_left)
	_setup_goal_particles(goal_celebration_left)
	
	# Right goal celebration
	goal_celebration_right = CPUParticles3D.new()
	goal_celebration_right.name = "GoalCelebrationRight"
	goal_celebration_right.position = Vector3(58, 3, 0)
	add_child(goal_celebration_right)
	_setup_goal_particles(goal_celebration_right)

func _setup_goal_particles(particles: CPUParticles3D) -> void:
	# Basic particle setup that works with CPUParticles3D
	particles.emitting = false
	particles.amount = 100
	particles.lifetime = 2.0
	
	# Movement and physics
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 30.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 8.0
	particles.gravity = Vector3(0, -5.0, 0)
	
	# Visual properties
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.8
	particles.color = Color.GOLD

func trigger_goal_celebration(is_left_goal: bool) -> void:
	var particles = goal_celebration_left if is_left_goal else goal_celebration_right
	
	if particles:
		# Start the celebration
		particles.restart()
		particles.emitting = true
		
		# Stop after a short burst
		await get_tree().create_timer(1.0).timeout
		particles.emitting = false

func create_simple_ambient_effect() -> void:
	# Optional: Create a simple ambient effect
	var ambient = CPUParticles3D.new()
	ambient.name = "AmbientEffect"
	ambient.position = Vector3(0, 2, 0)
	ambient.emitting = true
	add_child(ambient)
	
	# Very subtle ambient particles
	ambient.amount = 20
	ambient.lifetime = 8.0
	ambient.direction = Vector3(0, 1, 0)
	ambient.spread = 15.0
	ambient.initial_velocity_min = 0.2
	ambient.initial_velocity_max = 1.0
	ambient.gravity = Vector3(0, -0.5, 0)
	ambient.scale_amount_min = 0.02
	ambient.scale_amount_max = 0.05
	ambient.color = Color(0.9, 0.95, 0.8, 0.2)  # Very subtle
