shader_type canvas_item;

uniform vec2 player_screen_pos = vec2(0.0, 0.0);
uniform vec2 arc_points[128];
uniform int arc_count = 0;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.85;

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
	if (point_in_fan(FRAGCOORD.xy)) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, overlay_alpha);
	}
}
