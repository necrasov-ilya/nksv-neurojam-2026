shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D grain_texture : filter_linear_mipmap, repeat_enable;
uniform int surface_kind = 1;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float joint(float coordinate, float spacing, float width) {
	float distance_to_joint = abs(fract(coordinate / spacing + 0.5) - 0.5) * spacing;
	float aa = max(fwidth(coordinate), 0.001);
	return 1.0 - smoothstep(width, width + aa, distance_to_joint);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 p = n.y > max(n.x, n.z) ? world_position.xz : (n.x > n.z ? world_position.zy : world_position.xy);
	float grain = texture(grain_texture, p * 0.7).r - 0.5;
	float shade = 1.0;
	ROUGHNESS = 0.86;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	if (surface_kind == 2) {
		shade -= max(joint(p.x, 1.2, 0.008), joint(p.y, 0.6, 0.008)) * 0.16;
		shade += grain * 0.025;
	} else if (surface_kind == 4) {
		shade -= joint(p.x, 0.24, 0.005) * 0.12;
		shade += grain * 0.045;
		ROUGHNESS = 0.72;
	} else if (surface_kind == 5) {
		METALLIC = 0.5;
		ROUGHNESS = 0.48;
		shade += grain * 0.015;
	} else if (surface_kind == 6) {
		ROUGHNESS = 0.28;
		EMISSION = COLOR.rgb * 0.22;
	} else if (surface_kind == 7) {
		ROUGHNESS = 0.62;
	} else {
		shade += grain * 0.025;
	}
	ALBEDO = COLOR.rgb * shade;
}
