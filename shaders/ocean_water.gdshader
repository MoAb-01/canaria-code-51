shader_type canvas_item;

uniform vec4 abyss_color : source_color = vec4(0.05, 0.09, 0.16, 1.0);  // Dark Navy
uniform vec4 mid_color : source_color = vec4(0.11, 0.20, 0.31, 1.0);    // Slate Blue
uniform vec4 crest_color : source_color = vec4(0.24, 0.42, 0.54, 1.0);  // Mid-sea Foam
uniform vec4 foam_color : source_color = vec4(0.85, 0.93, 0.96, 1.0);   // Dawn Highlight

uniform float pixel_scale : hint_range(1.0, 8.0) = 4.0;                // Keeps it retro
uniform float wave_speed : hint_range(0.1, 2.0) = 0.5;                 // Gentle side-roll

void fragment() {
    // Force coordinates to lock strictly to a retro pixel grid
    // (Fallback pixel size when attached to a textureless ColorRect where TEXTURE_PIXEL_SIZE is 1x1)
    vec2 base_pixel_size = (TEXTURE_PIXEL_SIZE.x >= 0.5) ? vec2(1.0 / 1920.0, 1.0 / 360.0) : TEXTURE_PIXEL_SIZE;
    vec2 grid_uv = floor(UV / (base_pixel_size * pixel_scale)) * (base_pixel_size * pixel_scale);
    
    // Create horizontal side-view rolling wave motion
    float wave_offset_a = sin(grid_uv.x * 35.0 + TIME * wave_speed * 3.0) * 0.025;
    float wave_offset_b = cos(grid_uv.x * 20.0 - TIME * wave_speed * 1.8) * 0.015;
    float final_y = grid_uv.y + wave_offset_a + wave_offset_b;
    
    // Stepped 16-bit color banding (no gradient)
    vec4 col = abyss_color;
    if (final_y < 0.70) col = mid_color;
    if (final_y < 0.38) col = crest_color;
    if (final_y < 0.14) col = foam_color;
    
    COLOR = col;
}
