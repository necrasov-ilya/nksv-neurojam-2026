shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D noise_texture : filter_linear, repeat_enable;
uniform float effect_amount : hint_range(0.0, 1.0) = 1.0;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.30;
uniform float colour_shift_pixels : hint_range(0.0, 8.0) = 3.2;
uniform float colour_bleed_pixels : hint_range(0.0, 12.0) = 6.0;
uniform float tracking_pixels : hint_range(0.0, 8.0) = 2.0;

vec3 rgb_to_yiq(vec3 rgb) {
	return vec3(
		dot(rgb, vec3(0.299, 0.587, 0.114)),
		dot(rgb, vec3(0.596, -0.274, -0.322)),
		dot(rgb, vec3(0.211, -0.523, 0.312))
	);
}

vec3 yiq_to_rgb(vec3 yiq) {
	return vec3(
		dot(yiq, vec3(1.0, 0.956, 0.621)),
		dot(yiq, vec3(1.0, -0.272, -0.647)),
		dot(yiq, vec3(1.0, -1.106, 1.703))
	);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = uv / SCREEN_PIXEL_SIZE;
	// Smooth irregular line tracking, not a tiled grid or a sine hash.
	float line_noise = texture(noise_texture, vec2(TIME * 0.11, uv.y * 0.73 + TIME * 0.029)).r - 0.5;
	float band_distance = (uv.y - fract(TIME * 0.045 + 0.76)) / 0.035;
	float tracking_band = exp(-band_distance * band_distance);
	float head_switch = smoothstep(0.91, 1.0, uv.y);
	float horizontal_shift = line_noise * (0.8 + tracking_band * 6.0);
	horizontal_shift += sin(uv.y * 13.0 + TIME * 0.8) * 0.6;
	horizontal_shift += head_switch * (sin(uv.y * 92.0 - TIME * 4.0) * 1.4 + line_noise * 7.0);
	uv.x += horizontal_shift * tracking_pixels * SCREEN_PIXEL_SIZE.x * effect_amount;
	vec2 split_offset = vec2(colour_shift_pixels * (1.0 + tracking_band * 0.65) * effect_amount * SCREEN_PIXEL_SIZE.x, 0.0);
	vec2 bleed_offset = vec2(colour_bleed_pixels * effect_amount * SCREEN_PIXEL_SIZE.x, 0.0);
	vec3 centre = texture(screen_texture, uv).rgb;
	vec3 left = rgb_to_yiq(texture(screen_texture, uv - bleed_offset).rgb);
	vec3 right = rgb_to_yiq(texture(screen_texture, uv + bleed_offset).rgb);
	vec3 split = vec3(texture(screen_texture, uv + split_offset).r, centre.g, texture(screen_texture, uv - split_offset).b);
	// VHS carries sharp-ish luminance but lower-bandwidth, delayed chroma.
	vec3 signal = rgb_to_yiq(centre);
	vec2 blurred_chroma = signal.yz * 0.20 + left.yz * 0.50 + right.yz * 0.30;
	signal.yz = mix(blurred_chroma, rgb_to_yiq(split).yz, 0.40);
	signal.x = signal.x * 0.90 + (left.x + right.x) * 0.05;
	vec3 image = yiq_to_rgb(signal);
	// Two non-axis-aligned texture samples remove coherent cell boundaries.
	// No floor(pixel), coarse squares or high-amplitude float hash quantisation.
	vec2 grain_uv = vec2(pixel.x * 0.91 + pixel.y * 0.27, -pixel.x * 0.23 + pixel.y * 1.07) / 512.0;
	vec3 fine_noise = texture(noise_texture, grain_uv + vec2(TIME * 17.3, TIME * 11.7)).rgb - 0.5;
	vec3 second_noise = texture(noise_texture, grain_uv.yx * 1.37 + vec2(-TIME * 9.1, TIME * 19.7)).rgb - 0.5;
	vec3 noise = fine_noise * 0.75 + second_noise * 0.25;
	float iso_gain = 0.90 + 0.65 * (1.0 - smoothstep(0.12, 0.80, signal.x));
	image += (vec3(noise.r) * 0.85 + noise * 0.15) * grain_amount * iso_gain * effect_amount;
	// Uneven analogue lines and rolling tracking, not regular checkerboarding.
	image *= 1.0 + effect_amount * (line_noise * 0.055 - tracking_band * 0.055 + head_switch * line_noise * 0.08);
	vec2 centre_uv = (SCREEN_UV - 0.5) * 2.0;
	image *= 1.0 - dot(centre_uv, centre_uv) * 0.022 * effect_amount;
	COLOR = vec4(clamp(image, vec3(0.0), vec3(1.0)), 1.0);
}
