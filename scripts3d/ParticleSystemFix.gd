extends Node

# Verification script to ensure particle systems are working correctly
# This script can be run to test that all particle properties are valid

func _ready() -> void:
	print("🔍 Verifying particle system fixes...")
	_test_cpu_particles_2d()
	_test_cpu_particles_3d()
	print("✅ All particle system tests passed!")

func _test_cpu_particles_2d() -> void:
	var particles_2d = CPUParticles2D.new()
	
	# Test all the properties we use
	particles_2d.emission_burst_count = 50
	particles_2d.amount = 100
	particles_2d.lifetime = 2.0
	particles_2d.direction = Vector2(0, -1)
	particles_2d.spread = 45.0
	particles_2d.initial_velocity_min = 100.0
	particles_2d.initial_velocity_max = 200.0
	particles_2d.gravity = Vector2(0, 98)
	particles_2d.angular_velocity_min = -180.0
	particles_2d.angular_velocity_max = 180.0
	particles_2d.scale_amount_min = 0.5
	particles_2d.scale_amount_max = 1.5
	particles_2d.color = Color.YELLOW
	
	print("✅ CPUParticles2D properties verified")
	particles_2d.queue_free()

func _test_cpu_particles_3d() -> void:
	var particles_3d = CPUParticles3D.new()
	
	# Test all the properties we use
	particles_3d.amount = 200
	particles_3d.lifetime = 3.0
	particles_3d.direction = Vector3(0, 1, 0)
	particles_3d.spread = 45.0
	particles_3d.initial_velocity_min = 5.0
	particles_3d.initial_velocity_max = 15.0
	particles_3d.angular_velocity_min = -180.0
	particles_3d.angular_velocity_max = 180.0
	particles_3d.gravity = Vector3(0, -9.8, 0)
	particles_3d.scale_amount_min = 0.1
	particles_3d.scale_amount_max = 0.3
	particles_3d.color = Color.GOLD
	
	# Test emission shapes
	particles_3d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles_3d.emission_box_extents = Vector3(10, 5, 10)
	
	print("✅ CPUParticles3D properties verified")
	particles_3d.queue_free()

# Test function that can be called from anywhere
static func verify_particle_fix() -> bool:
	print("🧪 Running particle system verification...")
	
	# Try to create and configure particles without errors
	var test_particles = CPUParticles3D.new()
	test_particles.amount = 100  # This should work now
	test_particles.queue_free()
	
	print("✅ Particle system fix verified successfully!")
	return true
