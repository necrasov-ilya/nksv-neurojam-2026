extends Node3D
## Solid geometry batched by shared shape and 48m cell; instance colors preserve the palette.
const COLORS := {
	# White architecture, two brand inks and violet rather than grey shadows.
	"concrete": Color("e8e5f2"), "cream": Color("ffffff"),
	"teal": Color("dcd6ff"), "petrol": Color("29263a"),
	"mustard": Color("f2c750"), "brick": Color("ac2954"),
	"glass": Color("5b4cff"), "dark": Color("211f2d"),
	"road": Color("211f2d"), "wood": Color("e5e1f3"),
	"leaf": Color("8175f6"), "white": Color("ffffff"),
	"leaf_light": Color("bcb4ff"), "flower": Color("ac2954"),
	"sand": Color("f4f1ff"), "stone": Color("f1eff9"), "rose": Color("edbbd0"),
	"coral": Color("ac2954"), "terracotta": Color("863251"), "yellow": Color("f2c750"),
	"mint": Color("eeeaff"), "sky": Color("ece8ff"), "blue": Color("5b4cff"),
	"navy": Color("34276c"), "lilac": Color("c9c0ff"), "red": Color("d54062"),
	"grass": Color("ddd8ff"), "hedge": Color("6d62d0"), "leaf_dark": Color("5148bd"),
	"blossom": Color("edbbd0"), "steel": Color("8c86a8"), "pane": Color("786aff"),
	# Small safety controls retain amber/green so their meaning stays readable.
	"cross_green": Color("38ba91"), "asphalt": Color("211f2d"), "tile": Color("f1eff9"),
	"cloud": Color("ffffff"), "cloud_shade": Color("ded7fb"), "bulb": Color("ffffff"),
	"accent_magenta": Color("ac2954"), "accent_violet": Color("5b4cff"), "accent_pink": Color("d65b8b"),
	"clear_glass": Color("dbd4ff"),
	"masonry": Color("ffffff"),
}
static var _meshes: Dictionary = {}
const SurfaceShader = preload("res://assets/shaders/intro_surface.gdshader")
const SurfaceGrain = preload("res://assets/textures/intro/surface_grain.png")
const SURFACE_KINDS := {
	"concrete": 2, "stone": 2, "tile": 2, "road": 3, "asphalt": 3,
	"wood": 4, "steel": 5, "glass": 6, "pane": 6,
	"petrol": 7, "dark": 7, "accent_magenta": 7, "accent_violet": 7, "accent_pink": 7,
	"leaf": 8, "leaf_light": 8, "leaf_dark": 8, "grass": 8, "hedge": 8,
	"clear_glass": 9,
	"masonry": 10,
}
static var _surface_materials: Dictionary = {}
var _batches: Dictionary = {}
var piece_count := 0

func box(p: Vector3, size: Vector3, color: String, rotation_value := Vector3.ZERO) -> void:
	if not _meshes.has("box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_meshes["box"] = mesh
	_piece("box", p, size, color, rotation_value)

func cylinder(p: Vector3, radius: float, height: float, color: String, rotation_value := Vector3.ZERO) -> void:
	if not _meshes.has("cylinder"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 1
		_meshes["cylinder"] = mesh
	_piece("cylinder", p, Vector3(radius, height, radius), color, rotation_value)

func cone(p: Vector3, radius: float, height: float, color: String, rotation_value := Vector3.ZERO) -> void:
	if not _meshes.has("cone"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 9
		mesh.rings = 1
		_meshes["cone"] = mesh
	_piece("cone", p, Vector3(radius, height, radius), color, rotation_value)

func torus(p: Vector3, inner_radius: float, outer_radius: float, color: String, rotation_value := Vector3.ZERO) -> void:
	var key := "torus_%s_%s" % [inner_radius, outer_radius]
	if not _meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner_radius
		mesh.outer_radius = outer_radius
		mesh.rings = 24
		mesh.ring_segments = 8
		_meshes[key] = mesh
	_piece(key, p, Vector3.ONE, color, rotation_value)

func ellipsoid(p: Vector3, size: Vector3, color: String) -> void:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 5
		_meshes["sphere"] = mesh
	_piece("sphere", p, size, color, Vector3.ZERO)

## `scale_xy` stretches the profile in its own plane, so one profile serves many widths.
func prism(p: Vector3, profile: PackedVector2Array, depth: float, color: String, rotation_value := Vector3.ZERO, scale_xy := Vector2.ONE) -> void:
	var key := "prism_" + str(hash(profile))
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := profile.size()
		for side in [-1.0, 1.0]:
			for i in range(1, n - 1):
				var indices := [0, i + 1, i] if side > 0 else [0, i, i + 1]
				for index in indices:
					st.add_vertex(Vector3(profile[index].x, profile[index].y, side * 0.5))
		for i in n:
			var a := profile[i]
			var b := profile[(i + 1) % n]
			for v in [Vector3(a.x,a.y,-0.5),Vector3(b.x,b.y,0.5),Vector3(b.x,b.y,-0.5),Vector3(a.x,a.y,-0.5),Vector3(a.x,a.y,0.5),Vector3(b.x,b.y,0.5)]:
				st.add_vertex(v)
		st.generate_normals()
		_meshes[key] = st.commit()
	_piece(key, p, Vector3(scale_xy.x, scale_xy.y, depth), color, rotation_value)

func _piece(shape: String, p: Vector3, size: Vector3, color: String, r: Vector3) -> void:
	var cell := Vector2i(floori(p.x / 48.0), floori(p.z / 48.0))
	var surface_kind: int = SURFACE_KINDS.get(color, 1)
	var key := shape + ":" + str(cell) + ":" + str(surface_kind)
	if not _batches.has(key):
		_batches[key] = {"shape": shape, "surface": surface_kind, "transforms": [], "colors": []}
	var basis_value := Basis.from_euler(r).scaled_local(size)
	_batches[key]["transforms"].append(Transform3D(basis_value, p))
	_batches[key]["colors"].append(COLORS[color] if COLORS.has(color) else Color.from_string(color, Color.WHITE))
	piece_count += 1


func solid(p: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = p
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body

func label(text: String, p: Vector3, font_size: int = 48, color: String = "cream", rotation_value := Vector3.ZERO, pixel_size_value: float = 0.012, max_width: float = 0.0, max_height: float = 0.0) -> Label3D:
	# Optional bounds are usable world-space dimensions, after the caller's plaque padding.
	var node := Label3D.new()
	node.font = preload("res://assets/fonts/OpenRunde-Semibold.woff2")
	node.text = text
	node.position = p
	node.rotation = rotation_value
	node.font_size = font_size
	var fitted_pixel_size := pixel_size_value
	if max_width > 0.0 or max_height > 0.0:
		var font := node.font
		var lines := text.split("\n")
		var longest := 0.0
		for line in lines:
			longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		var text_height := font.get_height(font_size) * lines.size()
		if max_width > 0.0 and longest > 0.0:
			fitted_pixel_size = minf(fitted_pixel_size, max_width / longest)
		if max_height > 0.0 and text_height > 0.0:
			fitted_pixel_size = minf(fitted_pixel_size, max_height / text_height)
	node.pixel_size = fitted_pixel_size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.modulate = COLORS.get(color, Color.WHITE)
	node.outline_size = 0
	node.no_depth_test = false
	node.visibility_range_end = 140.0
	add_child(node)
	return node

func flush() -> void:
	for batch in _batches.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[batch["shape"]]
		mm.instance_count = batch["transforms"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, batch["transforms"][i])
			mm.set_instance_color(i, batch["colors"][i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		var surface_kind: int = batch["surface"]
		if not _surface_materials.has(surface_kind):
			if surface_kind == 9:
				var glass := StandardMaterial3D.new()
				glass.vertex_color_use_as_albedo = true
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(1, 1, 1, 0.16)
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				glass.roughness = 0.2
				_surface_materials[surface_kind] = glass
			else:
				var material := ShaderMaterial.new()
				material.shader = SurfaceShader
				material.set_shader_parameter("grain_texture", SurfaceGrain)
				material.set_shader_parameter("surface_kind", surface_kind)
				_surface_materials[surface_kind] = material
		node.material_override = _surface_materials[surface_kind]
		if surface_kind == 9:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 320.0
		node.visibility_range_end_margin = 25.0
		add_child(node)
	_batches.clear()
