shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

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
	float grain = texture(grain_texture, p * 0.55).r - 0.5;
	float fine = texture(grain_texture, p * 3.0).r - 0.5;
	float shade = 1.0;
	float seam = 0.0;
	ROUGHNESS = 0.84;
	METALLIC = 0.0;
	SPECULAR = 0.28;
	if (surface_kind == 1) { // Mineral plaster, no painted-on large grid.
		shade += grain * 0.13 + fine * 0.045;
	} else if (surface_kind == 2) { // Paving below; board-formed concrete on vertical faces.
		if (n.y > 0.7) {
			float row = floor(p.y / 0.8);
			vec2 stone = vec2(p.x + mod(row, 2.0) * 0.6, p.y);
			seam = max(joint(stone.x, 1.2, 0.008), joint(stone.y, 0.8, 0.008));
			vec2 tile = floor(stone / vec2(1.2, 0.8));
			shade += (texture(grain_texture, (tile + 0.5) / 256.0).r - 0.5) * 0.12;
		} else {
			seam = joint(p.y, 1.5, 0.004) * 0.32;
		}
		shade += grain * 0.15 + fine * 0.04;
		shade *= 1.0 - seam * 0.19;
	} else if (surface_kind == 3) { // Asphalt aggregate, not a shiny flat plane.
		shade += grain * 0.25 + fine * 0.18;
		ROUGHNESS = 0.96;
	} else if (surface_kind == 4) { // Timber grain with subtle board joints.
		float fibres = texture(grain_texture, p * vec2(0.12, 5.5)).r - 0.5;
		shade += fibres * 0.25 + grain * 0.07;
		shade *= 1.0 - joint(p.y, 0.24, 0.003) * 0.10;
		ROUGHNESS = 0.68;
	} else if (surface_kind == 5) { // Brushed steel.
		shade += texture(grain_texture, p * vec2(0.15, 16.0)).r * 0.06 - 0.03;
		METALLIC = 0.45;
		ROUGHNESS = 0.46;
	} else if (surface_kind == 6) { // Opaque stylised window panes; no transparency sorting cost.
		shade += grain * 0.025;
		ROUGHNESS = 0.24;
		SPECULAR = 0.55;
	} else if (surface_kind == 7) { // Painted metal/accent panels.
		shade += grain * 0.035;
		ROUGHNESS = 0.55;
	} else if (surface_kind == 8) { // Foliage retains broad readable colour masses.
		shade += grain * 0.10;
		ROUGHNESS = 0.95;
	} else if (surface_kind == 10) {
		float row = floor(p.y / 0.24);
		float mortar = max(joint(p.x + mod(row, 2.0) * 0.24, 0.48, 0.006), joint(p.y, 0.24, 0.005));
		shade += grain * 0.20 + fine * 0.05;
		shade = mix(shade, 1.18, mortar * 0.55);
	}
	ALBEDO = COLOR.rgb * clamp(shade, 0.65, 1.2);
}
