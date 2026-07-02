shader_type canvas_item;
render_mode unshaded;

// Drifting low-alpha fog — AtmosphereLayer pass #2 of exactly TWO (master-plan tension 9).
// Two offset samples of one seamless noise tile multiply into slow curling banks; the drift
// freezes under reduce_motion (atmosphere_layer.gd sets time_scale to 0), so the pass is
// motion-safe. Density is clamped by the layer so the world always reads through the mist.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 fog_color = vec3(0.72, 0.74, 0.70);
uniform float density : hint_range(0.0, 0.4) = 0.1;
uniform float time_scale = 1.0;
uniform vec2 drift_a = vec2(0.013, 0.004);
uniform vec2 drift_b = vec2(-0.007, 0.009);

void fragment() {
	float t = TIME * time_scale;
	float a = texture(noise_tex, SCREEN_UV * 1.6 + drift_a * t).r;
	float b = texture(noise_tex, SCREEN_UV * 2.9 + drift_b * t).r;
	float bank = smoothstep(0.18, 0.95, a * b * 1.6);
	COLOR = vec4(fog_color, bank * density);
}
