shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
uniform int surface_kind = 0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

// Screen-space antialiasing keeps fine joints stable at grazing angles.
float joint(float coordinate, float spacing, float width) {
	float distance_to_joint = abs(fract(coordinate / spacing + 0.5) - 0.5) * spacing;
	float aa = max(fwidth(coordinate), 0.001);
	return 1.0 - smoothstep(width, width + aa, distance_to_joint);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 p = n.y > max(n.x, n.z) ? world_position.xz : (n.x > n.z ? world_position.zy : world_position.xy);
	float shade = 1.0;
	// In diffuse_toon, roughness controls the width of the light transition.
	ROUGHNESS = 0.22;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// Flat colour carries the form. Only large construction joints survive;
	// no asphalt aggregate, brushed-metal noise or photographic timber grain.
	if (surface_kind == 2 && n.y > 0.7) {
		float row = floor(p.y / 0.8);
		vec2 stone = vec2(p.x + mod(row, 2.0) * 0.6, p.y);
		float seam = max(joint(stone.x, 1.2, 0.012), joint(stone.y, 0.8, 0.012));
		shade -= seam * 0.12;
	} else if (surface_kind == 4) {
		shade -= joint(p.y, 0.48, 0.006) * 0.06;
	} else if (surface_kind == 10) {
		float row = floor(p.y / 0.48);
		float mortar = max(joint(p.x + mod(row, 2.0) * 0.48, 0.96, 0.01), joint(p.y, 0.48, 0.01));
		shade -= mortar * 0.08;
	} else if (surface_kind == 1) {
		// A very faint print surface, not mottled pseudo-realistic plaster.
		shade += (texture(grain_texture, p * 0.35).r - 0.5) * 0.018;
	}
	ALBEDO = COLOR.rgb * shade;
}
