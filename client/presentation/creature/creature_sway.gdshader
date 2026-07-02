shader_type canvas_item;
// creature_sway — Wave 9 "LivingPlate": cheap top-weighted vertex sway for the painterly RGBA
// cutouts, plus the MATERIAL HOOKS the later juice waves drive (the flash/dissolve/outline
// uniforms mirror presentation/shaders/hit_flash|dissolve|outline.gdshader, so Wave 10 can tween
// them on a live plate without swapping materials).
// Provenance: project-authored for Mutants_Game. License: CC0 (public domain).

// --- sway (LivingPlate zeroes the amplitude under headless / reduce_motion) -------------------
uniform float sway_amplitude : hint_range(0.0, 4.0) = 1.6; // px at the crown; feet stay planted
uniform float sway_speed : hint_range(0.0, 2.0) = 0.31; // cycles per second
uniform float sway_phase = 0.0; // per-instance identity offset (radians)

// --- hit_flash hook (Wave 10: flash_amount 1 -> 0 on impact) -----------------------------------
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// --- dissolve hook (Wave 10 death: dissolve 0 -> 1 burns the plate away) -----------------------
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;

// --- outline hook (target-pick / spotlight; width 0 = off, no extra sampling cost) -------------
// Default is GrimoirePalette.BRASS_BRIGHT #e0b95a (shaders cannot read GDScript constants;
// LivingPlate.set_outline() re-feeds the palette colour at runtime).
uniform vec4 outline_color : source_color = vec4(0.878, 0.725, 0.353, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 0.0;

varying vec4 v_modulate;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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

void vertex() {
	// Keep the tint/flash modulate chain alive through the custom fragment below.
	v_modulate = COLOR;
	// Quadratic top weighting: the crown drifts +/- amplitude, the feet never move, and the
	// painterly art shears gently instead of warping.
	float crown = 1.0 - UV.y;
	VERTEX.x += sin(TIME * TAU * sway_speed + sway_phase) * sway_amplitude * crown * crown;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float edge = 0.0;
	if (dissolve > 0.0) {
		float n = vnoise(UV * 24.0);
		if (n < dissolve) {
			discard;
		}
		edge = step(n - edge_width, dissolve) * edge_color.a;
	}
	vec3 rgb = mix(tex.rgb, edge_color.rgb, edge);
	rgb = mix(rgb, flash_color.rgb, flash_amount * flash_color.a);
	vec4 base = vec4(rgb, tex.a);
	if (outline_width > 0.0) {
		vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(ts.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(ts.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, ts.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, ts.y)).a);
		vec4 o = vec4(outline_color.rgb, outline_color.a * a);
		base = mix(o, base, base.a);
	}
	COLOR = base * v_modulate;
}
