shader_type canvas_item;
render_mode unshaded;

// Fullscreen post-process: draw after the interview image/text and before pause UI.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// Parent-owned elapsed seconds; freeze on pause/focus loss. Never uses engine TIME.
uniform float clock = 0.0;
// 0 = normal picture, 1 = opaque black; intermediate values fade the whole pass.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
// 0 = no tracking disturbance; 1 = maximum localized band. Parent supplies rare pulses.
uniform float tracking_amount : hint_range(0.0, 1.0) = 0.0;
// Radial channel separation in UV space; the center and lower-left text stay calm.
uniform float chromatic_strength : hint_range(0.0, 0.01) = 0.003;
uniform vec4 text_rect = vec4(0.075, 0.10, 0.56, 0.88);
// Parent owns the brief appearance and its placement; no autonomous animation.
uniform float presence_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 presence_center = vec2(0.765, 0.31);
uniform vec2 presence_scale = vec2(1.0);
// Curvature is edge-localized so controls inside the 7% safe inset barely move.
uniform float curvature : hint_range(0.0, 0.08) = 0.05;
uniform float grain_amount : hint_range(0.0, 0.10) = 0.04;
uniform float scanline_amount : hint_range(0.0, 0.06) = 0.03;

float hash_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 safe_sample_uv(vec2 uv, vec2 pixel_size) {
	vec2 half_pixel = pixel_size * 0.5;
	return clamp(uv, half_pixel, vec2(1.0) - half_pixel);
}

float peripheral_presence(vec2 uv) {
	vec2 p = (uv - presence_center) / max(presence_scale, vec2(0.001));
	// A tilted, uneven head joins a single sloping shoulder/torso smear: no face.
	vec2 head_position = vec2(p.x + p.y * 0.10 + 0.002, p.y);
	float head_distance = length(head_position / vec2(0.014, 0.030));
	head_distance += 0.045 * sin(p.y * 231.0 + p.x * 177.0);
	float head = 1.0 - smoothstep(0.72, 1.22, head_distance);
	float shoulder = smoothstep(0.018, 0.068, p.y);
	float torso_width = mix(0.009, 0.0325, shoulder)
		* (1.0 - 0.18 * smoothstep(0.09, 0.24, p.y));
	float lean = 0.004 * sin(p.y * 18.0) - 0.003 * shoulder;
	float body_distance = abs(p.x - lean) / torso_width;
	body_distance += 0.055 * sin(p.y * 103.0 + p.x * 219.0);
	float body = (1.0 - smoothstep(0.70, 1.18, body_distance))
		* smoothstep(0.012, 0.034, p.y)
		* (1.0 - smoothstep(0.20, 0.245, p.y));
	// The supplied center puts this crop inside the left pane, before the mullion
	// at x=.816 and sill at y=.60; it follows Inspector changes to the center.
	float pane = smoothstep(-0.052, -0.042, p.x)
		* (1.0 - smoothstep(0.038, 0.046, p.x))
		* (1.0 - smoothstep(0.265, 0.29, p.y));
	return max(head, body) * pane;
}

void fragment() {
	vec2 centered = (SCREEN_UV - 0.5) * 2.0;
	// Bend only the outer 12%: most text and the bottom-left controls stay put.
	vec2 edge_weight = smoothstep(vec2(0.76), vec2(1.0), abs(centered));
	vec2 cross_axis_squared = centered.yx * centered.yx;
	vec2 curved = centered + centered * cross_axis_squared * curvature * edge_weight;
	vec2 picture_uv = curved * 0.5 + 0.5;

	// Rounded glass aperture in physical pixels, consistent on wide/tall displays.
	// At default curvature the border stays well outside the 7% content inset.
	vec2 half_size = vec2(0.5) / SCREEN_PIXEL_SIZE;
	float corner_radius = min(half_size.x, half_size.y) * 0.10;
	vec2 corner_distance = abs((picture_uv - 0.5) / SCREEN_PIXEL_SIZE)
		- (half_size - vec2(corner_radius));
	float aperture_distance = length(max(corner_distance, vec2(0.0)))
		+ min(max(corner_distance.x, corner_distance.y), 0.0) - corner_radius;
	float aperture = 1.0 - smoothstep(-1.0, 1.0, aperture_distance);

	float grain_tick = floor(max(clock, 0.0) * 12.0);
	float tracking = clamp(tracking_amount, 0.0, 1.0);
	float tracking_center = mix(0.15, 0.85, fract(clock * 0.13 + 0.31));
	float tracking_band = 1.0 - smoothstep(0.012, 0.042,
		abs(picture_uv.y - tracking_center));
	float row_noise = hash_noise(vec2(floor(picture_uv.y / SCREEN_PIXEL_SIZE.y / 3.0),
		grain_tick + 47.0)) - 0.5;
	// Shift only this band, including its grain coordinates; never shake the screen.
	picture_uv.x += tracking * tracking_band * 0.006 * (0.65 + row_noise * 0.70);

	// Three sharp taps preserve the photograph's contrast instead of adding glow.
	float radial_weight = smoothstep(0.25, 0.95,
		max(abs(centered.x), abs(centered.y)));
	vec2 text_inside = smoothstep(text_rect.xy - vec2(0.02), text_rect.xy, picture_uv)
		* (vec2(1.0) - smoothstep(text_rect.zw, text_rect.zw + vec2(0.02), picture_uv));
	float text_safe = 1.0 - 0.92 * text_inside.x * text_inside.y;
	vec2 separation = centered * clamp(chromatic_strength, 0.0, 0.01)
		* radial_weight * text_safe;
	vec3 middle = texture(screen_texture, safe_sample_uv(picture_uv, SCREEN_PIXEL_SIZE)).rgb;
	vec3 left = texture(screen_texture, safe_sample_uv(picture_uv - separation, SCREEN_PIXEL_SIZE)).rgb;
	vec3 right = texture(screen_texture, safe_sample_uv(picture_uv + separation, SCREEN_PIXEL_SIZE)).rgb;
	vec3 image = vec3(right.r, middle.g, left.b);

	// Static, translucent photographic shading inherits the scene's light and tint.
	// Applying it before CRT grain/scanlines keeps the smear inside the picture.
	if (presence_amount > 0.0) {
		float silhouette = peripheral_presence(picture_uv);
		float luminance = dot(middle, vec3(0.2126, 0.7152, 0.0722));
		float smudge = 0.86 + 0.14 * hash_noise(floor(picture_uv / SCREEN_PIXEL_SIZE / 7.0));
		float opacity = 0.5 * clamp(presence_amount, 0.0, 1.0) * silhouette
			* smudge * (0.75 + 0.25 * luminance);
		vec3 reflection = image * 0.16 + vec3(0.085) * (0.75 + 0.25 * luminance);
		image = mix(image, reflection, opacity);
	}

	vec2 pixel = picture_uv / SCREEN_PIXEL_SIZE;
	float fine_grain = hash_noise(floor(pixel) + grain_tick * vec2(19.0, 37.0)) - 0.5;
	float coarse_grain = hash_noise(floor(pixel / 5.0)
		+ grain_tick * vec2(7.0, 23.0)) - 0.5;
	float grain = fine_grain * 0.75 + coarse_grain * 0.25;
	// Scanlines stay on output rows, avoiding interference from the curved sampling.
	float scanline = 1.0 - scanline_amount
		* (0.5 + 0.5 * sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 3.14159265));
	float brightness_center = fract(clock * 0.045 + 0.22);
	float brightness_band = 0.004 * (1.0 - smoothstep(0.015, 0.065,
		abs(SCREEN_UV.y - brightness_center)));
	float vignette = 1.0 - 0.0275 * dot(centered, centered);
	image = image * (scanline + brightness_band) * vignette;
	image += grain * grain_amount + fine_grain * tracking * tracking_band * 0.025;

	// Mask in output space: tracking must not move the glass or expose clamped edges.
	image = clamp(image, vec3(0.0), vec3(1.0)) * aperture;
	COLOR = vec4(image * (1.0 - clamp(fade, 0.0, 1.0)), 1.0);
}
