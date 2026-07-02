shader_type canvas_item;
// grimoire_grade — Wave 10 "Entropy Crescendo": the ONE combined colour-grade + vignette
// fullscreen pass (plan tension 9: exactly one grade+vignette pass, rendered above the arena
// and BELOW the HUD, never past readable text contrast). It replaces the 65k-set_pixel
// vignette texture battle_card_kit used to bake (make_vignette — deleted with this pass).
//
// `warmth` is the battle's normalized entropy (0..1): it drags the grade from parchment-
// neutral toward ember heat and tightens the vignette, so a turn-8 screenshot visibly burns
// hotter than turn 1. Drive `ember_color` from GrimoirePalette.EMBER at runtime (shaders
// cannot read GDScript constants — the creature_sway outline precedent).
//
// Provenance: vignette falloff adapted from the CC0 "Vignette" canvas-item pattern published
// on godotshaders.com (https://godotshaders.com/shader/vignette/, CC0 / public domain);
// grade stage project-authored for Mutants_Game. Combined file license: CC0.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.66;
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.02, 0.012, 0.03, 1.0);
uniform float warmth : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ember_color : source_color = vec4(0.8, 0.38, 0.14, 1.0);
uniform float grade_strength : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	// Grade: warmth pulls the frame toward luminance-preserving ember heat...
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 warmed = mix(col, ember_color.rgb * (luma * 1.4 + 0.05), warmth * grade_strength);
	// ...with a light contrast push as the crescendo builds (never crushing HUD-adjacent blacks).
	warmed = mix(warmed, warmed * warmed * 1.55 + 0.02, warmth * 0.16);
	// Vignette: radial falloff toward the ink edge, tightening as entropy climbs.
	float d = distance(SCREEN_UV, vec2(0.5));
	float vig = smoothstep(vignette_radius, 1.0, d * (1.0 + 0.4 * warmth));
	vec3 graded = mix(warmed, vignette_color.rgb, vig * vignette_intensity * vignette_color.a);
	COLOR = vec4(graded, 1.0);
}
