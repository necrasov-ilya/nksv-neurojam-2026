extends SceneTree

const Pedestrians = preload("res://scripts/intro/pedestrians.gd")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var people := Pedestrians.new()
	for profile in [[true, false], [false, false], [false, true]]:
		var mesh := people._profile_mesh(profile[0], profile[1])
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			# Godot's clockwise front face must face the exterior lighting normals.
			if face.dot(normals[a] + normals[b] + normals[c]) >= 0.0:
				push_error("NPC exterior is culled: profile=%s triangle=%d" % [profile, i / 3])
				people.free()
				quit(1)
				return
	people.free()
	print("INTRO_MESHES_PASS: torso, limbs and skirt exterior faces and caps")
	quit(0)
