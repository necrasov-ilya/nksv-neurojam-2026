class_name ProceduralLayout
extends RefCounted


static func scatter(seed_value: int, count: int, half_extent: float) -> PackedVector3Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var points := PackedVector3Array()
	for index in range(count):
		var x := random.randf_range(-half_extent, half_extent)
		var z := random.randf_range(-half_extent, half_extent)
		if absf(x) < 2.0 and absf(z) < 2.0:
			x = 2.0 if x >= 0.0 else -2.0
		points.append(Vector3(x, 0.25, z))
	return points

