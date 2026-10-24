shader_type canvas_item;

// Wind sway shader for spooky forest trees and branches in 2D
uniform float speed : hint_range(0.1, 5.0) = 1.4;
uniform float wind_strength : hint_range(0.0, 40.0) = 14.0;
uniform float detail_flutter : hint_range(0.0, 15.0) = 4.0;
uniform float sway_phase : hint_range(0.0, 6.28) = 0.0;

void vertex() {
	// UV.y is 0.0 at the top (canopy/branches) and 1.0 at the bottom (roots/trunk base)
	// We want the base firmly rooted in ground, and the branches swaying more towards the top
	float height_influence = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.5);
	
	// Primary gentle sway
	float sway = sin(TIME * speed + sway_phase + (UV.y * 2.5)) * wind_strength * height_influence;
	
	// Secondary organic flutter for smaller branches and twigs
	float flutter = cos(TIME * (speed * 1.8) + sway_phase + (UV.x * 5.0)) * detail_flutter * height_influence;
	
	VERTEX.x += sway + flutter;
}
