shader_type canvas_item;
// hit_flash — the "got hit" white-flash juice (TDD/design §4.5).
// Provenance: project-authored for Mutants_Game. License: CC0 (public domain).
// (Phase 5 may swap/augment with curated GodotShaders.com CC0 picks.)
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount * flash_color.a), tex.a);
}
