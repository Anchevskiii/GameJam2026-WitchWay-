shader_type canvas_item;

// Full-screen glitch for the world SubViewport. GlitchFX drives `intensity` (0..1):
// tearing horizontal slices, displaced blocks, RGB split, scanlines and magenta stripes.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = floor(TIME * 20.0) + seed;

	// Tearing: some horizontal slices slide sideways.
	float band = floor(uv.y * 45.0);
	if (rand(vec2(band, t)) < intensity * 0.3) {
		uv.x += (rand(vec2(t, band)) - 0.5) * 0.09 * intensity;
	}
	// Blocks of the picture jump to the wrong place. The jump distance also scales
	// with intensity, so a calm house only twitches instead of teleporting chunks.
	vec2 block = floor(uv * vec2(16.0, 9.0));
	if (rand(block + t) < intensity * 0.05) {
		uv += (vec2(rand(block + 1.7), rand(block.yx + 3.1)) - 0.5) * 0.15 * intensity;
	}

	// RGB split.
	float split = 0.007 * intensity;
	vec4 c = texture(TEXTURE, uv);
	c.r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	c.b = texture(TEXTURE, uv - vec2(split, 0.0)).b;

	// Scanlines.
	c.rgb *= 1.0 - 0.1 * intensity * step(0.5, fract(uv.y * 120.0));
	// Magenta "missing texture" stripes. At low intensity they are faint hints.
	if (rand(vec2(t, band * 0.37)) < intensity * 0.025) {
		float magenta = clamp(intensity * 2.4, 0.0, 1.0) * 0.6;
		c.rgb = mix(c.rgb, vec3(1.0, 0.0, 0.86), magenta);
	}
	c.a = 1.0;
	COLOR = c;
}
