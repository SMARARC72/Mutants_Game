shader_type canvas_item;
// outline — selection/threat outline around opaque texels.
// Provenance: project-authored for Mutants_Game. License: CC0 (public domain).
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 1.0;

void fragment() {
	vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(ts.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(ts.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, ts.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, ts.y)).a);
	vec4 o = vec4(outline_color.rgb, outline_color.a * a);
	COLOR = mix(o, c, c.a);
}
