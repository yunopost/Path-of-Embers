shader_type canvas_item;

// Gradient colors — ember theme bottom to top
uniform vec4 color_base : source_color = vec4(0.35, 0.12, 0.02, 1.0);    // Deep burnt ember
uniform vec4 color_mid : source_color = vec4(0.85, 0.50, 0.08, 1.0);     // Warm amber
uniform vec4 color_tip : source_color = vec4(0.94, 0.90, 0.78, 1.0);     // Bone white highlight

// Gradient control
uniform float mid_point : hint_range(0.0, 1.0) = 0.5;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;

// Label screen-space bounds — passed from GDScript so FRAGCOORD can be normalised
// UV maps to the font atlas per-glyph and cannot be used for a label-spanning gradient
uniform float label_top : hint_range(0.0, 2000.0) = 150.0;
uniform float label_bottom : hint_range(0.0, 2000.0) = 330.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Derive vertical position from screen-space Y, normalised to label bounds
	float t = 1.0 - clamp(
		(FRAGCOORD.y - label_top) / max(label_bottom - label_top, 1.0),
		0.0, 1.0
	);
	// t = 1.0 at top of label (tip — bright), t = 0.0 at bottom (base — dark)

	// Two-stage gradient: base -> mid -> tip
	vec4 gradient;
	if (t < mid_point) {
		gradient = mix(color_base, color_mid, t / mid_point);
	} else {
		gradient = mix(color_mid, color_tip, (t - mid_point) / (1.0 - mid_point));
	}

	COLOR = vec4(gradient.rgb, tex.a);

	// Subtle ember glow on semi-transparent edges
	float edge = tex.a * (1.0 - tex.a) * 4.0;
	COLOR.rgb += color_mid.rgb * edge * glow_intensity;
}
