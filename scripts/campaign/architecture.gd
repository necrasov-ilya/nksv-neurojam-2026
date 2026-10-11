extends "res://scripts/intro/geometry.gd"

const CampaignSurface := preload("res://assets/shaders/campaign_surface.gdshader")
static var _campaign_materials: Dictionary = {}

func flush() -> void:
	var first := get_child_count()
	super.flush()
	for index in range(first, get_child_count()):
		var mesh := get_child(index) as MultiMeshInstance3D
		if mesh == null or not mesh.material_override is ShaderMaterial:
			continue
		var kind: int = mesh.material_override.get_shader_parameter("surface_kind")
		if not _campaign_materials.has(kind):
			var material := ShaderMaterial.new()
			material.shader = CampaignSurface
			material.set_shader_parameter("grain_texture", SurfaceGrain)
			material.set_shader_parameter("surface_kind", kind)
			_campaign_materials[kind] = material
		mesh.material_override = _campaign_materials[kind]
