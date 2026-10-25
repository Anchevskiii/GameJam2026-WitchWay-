shader_type canvas_item;
render_mode unshaded;

// Soft, blurry FOV cone for entities: fades out toward the outer edges and the far end so it
// reads like a dim "gaze" rather than a hard triangle. The Polygon2D's color (set per state)
// supplies the tint and base alpha; this shader only shapes the falloff.

uniform float reach = 110.0;
uniform float facing = 1.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float along = local_pos.x * facing;
	float perp = abs(local_pos.y);
	float side = 1.0 - smoothstep(0.3, 1.0, perp / (along * 1.2 + 16.0));
	float far = 1.0 - smoothstep(0.45, 1.0, along / max(reach, 1.0));
	COLOR = vec4(COLOR.rgb, COLOR.a * side * far);
}
