shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float gamma : hint_range(0.6, 1.6) = 1.0;

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	COLOR = vec4(pow(max(screen.rgb, vec3(0.0)), vec3(1.0 / gamma)), screen.a);
}
