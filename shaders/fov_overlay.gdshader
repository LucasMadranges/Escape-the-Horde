shader_type canvas_item;

uniform vec2 player_screen_pos = vec2(0.0, 0.0);
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.88;
uniform float fov_screen_radius = 280.0;
uniform vec2 aim_dir = vec2(1.0, 0.0);
uniform float fov_half_cos = 0.707;

void fragment() {
	vec2 pixel = FRAGCOORD.xy;
	vec2 to_pixel = pixel - player_screen_pos;
	float dist = length(to_pixel);

	float cos_a = dist > 0.5 ? dot(normalize(to_pixel), aim_dir) : 1.0;
	bool in_cone = dist < fov_screen_radius && cos_a >= fov_half_cos;

	if (!in_cone) {
		COLOR = vec4(0.0, 0.0, 0.0, overlay_alpha);
		return;
	}

	// Intérieur du cône : transparent (le _draw() du joueur gère le gradient)
	COLOR = vec4(0.0, 0.0, 0.0, 0.0);
}
