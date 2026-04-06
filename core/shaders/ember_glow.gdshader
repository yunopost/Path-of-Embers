shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec4 glow_color : source_color = vec4(0.769, 0.506, 0.098, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float glow = tex.a * glow_strength;
	// Glow emanates upward — stronger at bottom of text
	float vertical_bias = 1.0 - UV.y;
	COLOR = mix(tex, glow_color, glow * vertical_bias * 0.4);
	COLOR.a = tex.a;
}
