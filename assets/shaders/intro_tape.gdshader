shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.065;
uniform float moire_amount : hint_range(0.0, 0.03) = 0.010;

float hash_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = uv / SCREEN_PIXEL_SIZE;
	// A stable analogue softness, not a glitch or a moving camera distortion.
	vec2 chroma = vec2(SCREEN_PIXEL_SIZE.x * 1.2, 0.0);
	vec3 image = texture(screen_texture, uv).rgb;
	image.r = mix(image.r, texture(screen_texture, uv + chroma).r, 0.36);
	image.b = mix(image.b, texture(screen_texture, uv - chroma).b, 0.36);
	float luminance = dot(image, vec3(0.299, 0.587, 0.114));
	image = mix(vec3(luminance), image, 0.98);
	image = image * vec3(0.995, 0.988, 0.975) + vec3(0.006, 0.009, 0.006);
	vec2 center = (uv - 0.5) * 2.0;
	vec2 cell = floor(pixel / 2.0);
	float grain = hash_noise(floor(pixel) + floor(TIME * 12.0) * vec2(19.0, 37.0)) - 0.5;
	float coarse_grain = hash_noise(cell + floor(TIME * 8.0) * vec2(7.0, 23.0)) - 0.5;
	float scanline = 1.0 - 0.026 * (0.5 + 0.5 * sin(pixel.y * 3.14159265));
	float tape_band = 0.006 * sin(uv.y * 38.0 - TIME * 0.6);
	float radius = length(center);
	float rings = sin(radius * 180.0 + sin(atan(center.y, center.x) * 4.0) * 1.5);
	float moire = rings * sin(radius * 194.0 - atan(center.y, center.x) * 3.0);
	image = image * (scanline + tape_band) + (grain * 0.72 + coarse_grain * 0.35) * grain_amount;
	// Interference remains visible without replacing the image with a dark border.
	image += moire * moire_amount * smoothstep(0.35, 1.1, radius);
	float vignette = 1.0 - 0.025 * radius * radius;
	COLOR = vec4(clamp(image * vignette, vec3(0.0), vec3(1.0)), 1.0);
}
