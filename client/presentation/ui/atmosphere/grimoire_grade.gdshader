shader_type canvas_item;
render_mode unshaded;

// Grimoire grade + vignette — AtmosphereLayer pass #1 of exactly TWO (master-plan tension 9:
// one combined grade+vignette pass + one fog pass, both owned by AtmosphereLayer, above the
// world and BELOW the HUD). Authored for Wave 13's overworld layer; self-contained so the
// battle stage (owned by a sibling wave) can later share or port it without touching this file.
// All uniform strengths are clamped by atmosphere_layer.gd so the pass never crosses readable
// contrast (HAWKING veto).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// Multiplied colour grade (a gentle near-white modulate; corruption drags its hue).
uniform vec3 grade_tint = vec3(1.0, 1.0, 1.0);
uniform float grade_mix : hint_range(0.0, 1.0) = 0.3;
// Dread pulls colour out of the world (kept well under full grayscale).
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
// Ink-dark corners; corruption bruises the vignette hue.
uniform vec3 vignette_tint = vec3(0.02, 0.015, 0.03);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_reach : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	col = mix(col, col * grade_tint, grade_mix);
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(grey), desaturate);
	float d = distance(SCREEN_UV, vec2(0.5)) * 1.41421356;
	float vig = smoothstep(vignette_reach, 1.15, d) * vignette_strength;
	col = mix(col, vignette_tint, vig);
	COLOR = vec4(col, 1.0);
}
