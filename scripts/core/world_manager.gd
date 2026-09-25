class_name WorldManager
extends Node3D

const MARKER_COUNT := 60

var seed_value := 1
var markers: MultiMeshInstance3D


func _ready() -> void:
	_create_ground()
	_create_markers()
	regenerate(seed_value)


func regenerate(next_seed: int) -> void:
	seed_value = next_seed
	var points := ProceduralLayout.scatter(seed_value, MARKER_COUNT, 16.0)
	for index in range(points.size()):
		markers.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
	markers.multimesh.visible_instance_count = points.size()


func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40.0, 40.0)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.23, 0.27)
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)


func _create_markers() -> void:
	markers = MultiMeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.5, 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.53, 0.65, 0.71)
	box.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = box
	instances.instance_count = MARKER_COUNT
	markers.multimesh = instances
	add_child(markers)

