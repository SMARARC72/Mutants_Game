shader_type canvas_item;
// dissolve — splice/death "burn away" reveal (TDD/design §4.5).
// Provenance: project-authored for Mutants_Game. License: CC0 (public domain).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = vnoise(UV * 24.0);
	if (n < progress) {
		discard;
	}
	float edge = step(n - edge_width, progress);
	COLOR = vec4(mix(tex.rgb, edge_color.rgb, edge * edge_color.a), tex.a);
}
