shader_type canvas_item;

uniform vec2 player_screen_pos = vec2(0.0, 0.0);
uniform vec2 arc_points[128];
uniform int arc_count = 0;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.88;
uniform float fov_screen_radius = 280.0;
uniform vec2 aim_dir = vec2(1.0, 0.0);
uniform float fov_half_cos = 0.707; // cos(45deg)

bool point_in_fan(vec2 p) {
	if (arc_count < 2) return false;

	int crossings = 0;
	vec2 origin = player_screen_pos;

	vec2 a = origin;
	vec2 b = arc_points[0];
	if ((a.y <= p.y && b.y > p.y) || (b.y <= p.y && a.y > p.y)) {
		float x_int = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x);
		if (p.x < x_int) crossings++;
	}

	for (int i = 1; i < arc_count; i++) {
		a = arc_points[i - 1];
		b = arc_points[i];
		if ((a.y <= p.y && b.y > p.y) || (b.y <= p.y && a.y > p.y)) {
			float x_int = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x);
			if (p.x < x_int) crossings++;
		}
	}

	a = arc_points[arc_count - 1];
	b = origin;
	if ((a.y <= p.y && b.y > p.y) || (b.y <= p.y && a.y > p.y)) {
		float x_int = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x);
		if (p.x < x_int) crossings++;
	}

	return (crossings % 2) == 1;
}

void fragment() {
	vec2 pixel = FRAGCOORD.xy;

	if (!point_in_fan(pixel)) {
		COLOR = vec4(0.0, 0.0, 0.0, overlay_alpha);
		return;
	}

	vec2 to_pixel = pixel - player_screen_pos;
	float dist = length(to_pixel);
	float t = clamp(dist / fov_screen_radius, 0.0, 1.0);

	// Falloff angular : centre du faisceau plus brillant que les bords
	float cos_a = dist > 0.5 ? dot(normalize(to_pixel), aim_dir) : 1.0;
	float angle_t = clamp(1.0 - (cos_a - fov_half_cos) / max(1.0 - fov_half_cos, 0.001), 0.0, 1.0);
	// angle_t = 0 au centre du faisceau, 1 au bord du cône

	// Noyau très lumineux (t < 0.18) : superposition blanc chaud → éclaircissement
	float hot_core = max(0.0, 1.0 - t / 0.18) * (1.0 - angle_t * 0.6);
	if (hot_core > 0.001) {
		COLOR = vec4(1.0, 0.96, 0.82, hot_core * 0.55);
		return;
	}

	// Teinte chaude ambiante dans tout le cône (effet faisceau visible)
	float beam_glow = (1.0 - t * 0.85) * (1.0 - angle_t * 0.7) * 0.28;
	if (beam_glow > 0.005) {
		COLOR = vec4(1.0, 0.88, 0.55, beam_glow);
		return;
	}

	// Bord du cône : assombrissement progressif + falloff angulaire
	float edge_start = 0.65;
	float edge_shadow = smoothstep(edge_start, 1.0, t) * (0.5 + angle_t * 0.35) * overlay_alpha;
	COLOR = vec4(0.0, 0.0, 0.0, edge_shadow);
}
