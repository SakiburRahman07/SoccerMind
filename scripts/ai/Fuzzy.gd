extends Node

# Minimal fuzzy helper for pass strength
func decide_pass_force(distance: float, pressure: float) -> float:
	# distance 0..1000, pressure 0..1
	var near: float = clamp(1.0 - distance / 400.0, 0.0, 1.0)
	var far_val: float = 1.0 - near
	var low_pressure: float = clamp(1.0 - pressure, 0.0, 1.0)
	var high_pressure: float = 1.0 - low_pressure
	var slow_w: float = near * low_pressure
	var medium_w: float = near * high_pressure + far_val * low_pressure
	var fast_w: float = far_val * high_pressure
	var sum_w: float = slow_w + medium_w + fast_w + 0.0001
	var force: float = (slow_w * 250.0 + medium_w * 380.0 + fast_w * 520.0) / sum_w
	return force


