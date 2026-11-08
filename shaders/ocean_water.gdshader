shader_type canvas_item;

uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wave_freq : hint_range(0.0, 60.0) = 20.0;
uniform float wave_amp : hint_range(0.0, 0.05) = 0.003;
uniform float horizon_y : hint_range(0.0, 1.0) = 0.675;

void fragment() {
    vec2 uv = UV;
    
    if (uv.y > horizon_y) {
        // Exclude the tower structure on the far right (x > 0.82)
        if (uv.x < 0.82 || uv.y > 0.95) {
            float depth = (uv.y - horizon_y) / (1.0 - horizon_y);
            
            // Harmonic wave motion
            float w1 = sin(TIME * wave_speed + uv.y * wave_freq + uv.x * 12.0);
            float w2 = cos(TIME * (wave_speed * 0.8) + uv.y * (wave_freq * 0.5) - uv.x * 16.0);
            
            // Stepped displacement
            float disp_x = floor((w1 * 0.65 + w2 * 0.35) * 6.0) / 6.0 * wave_amp * (0.3 + depth * 0.7);
            float disp_y = floor(w1 * 4.0) / 4.0 * (wave_amp * 0.4) * (0.3 + depth * 0.7);
            
            vec2 sample_uv = uv + vec2(disp_x, disp_y);
            
            if (sample_uv.y > horizon_y && sample_uv.x < 0.84) {
                uv = sample_uv;
            }
        }
    }
    
    COLOR = texture(TEXTURE, uv);
}
