shader_type canvas_item;
// Simple radial vignette. Applied to a full-screen ColorRect on a dedicated
// CanvasLayer above the game world. Intentionally subtle — too much
// saturation eats the HUD corners.

uniform float intensity : hint_range(0.0, 1.0) = 0.42;
uniform float feather : hint_range(0.1, 1.2) = 0.85;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 center = SCREEN_UV - vec2(0.5, 0.5);
	float d = length(center) * 2.0;  // 0 at center, ~1.41 at corners
	float vig = smoothstep(1.0 - feather, 1.0, d);
	COLOR = vec4(tint.rgb, vig * intensity);
}
