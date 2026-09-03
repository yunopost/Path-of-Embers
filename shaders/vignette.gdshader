shader_type canvas_item;

uniform float opacity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Remap UV to -1..1 range so distance is measured from center
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	// Smooth falloff — transparent in the center, dark at the edges
	float vignette = smoothstep(0.3, 1.3, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * opacity);
}
