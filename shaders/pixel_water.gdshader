shader_type canvas_item;

uniform sampler2D water_mask : hint_default_black, filter_nearest;
uniform float wave_speed = 3.0;
uniform float wave_amplitude = 2.0; // pixel offset
uniform float wave_frequency = 25.0;
uniform vec2 pixel_size = vec2(0.0015408, 0.0027174); // 1.0 / 649.0, 1.0 / 368.0

void fragment() {
    float mask = texture(water_mask, UV).r;
    vec2 uv = UV;
    
    if (mask > 0.5) {
        // Pixel-quantized wave motion for authentic retro pixel aesthetic
        float wave_phase = TIME * wave_speed + uv.y * wave_frequency;
        
        // Integer pixel-stepped displacement
        float step_x = floor(sin(wave_phase) * wave_amplitude + 0.5) * pixel_size.x;
        float step_y = floor(cos(wave_phase * 0.7) * (wave_amplitude * 0.4) + 0.5) * pixel_size.y;
        
        vec2 sample_uv = uv + vec2(step_x, step_y);
        
        // Stay within water boundary to preserve shoreline & metal structures
        if (texture(water_mask, sample_uv).r > 0.5) {
            uv = sample_uv;
        }
    }
    
    COLOR = texture(TEXTURE, uv);
}

