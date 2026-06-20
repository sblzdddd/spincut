shader_type canvas_item;

uniform int teeth_count : hint_range(4, 64) = 8;
uniform float inner_radius : hint_range(0.1, 0.9) = 0.4;
uniform float outer_radius : hint_range(0.1, 0.9) = 0.5;
uniform float hole_radius : hint_range(0.0, 0.5) = 0.15;
uniform float gear_speed : hint_range(-10.0, 10.0) = 2.0;
uniform vec4 gear_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);
// 由脚本驱动的动画时间：仅在播放模式累加，暂停/停止时保持不变以冻结齿轮
uniform float anim_time = 0.0;

void fragment() {
    // Center the UV coordinates (-0.5 to 0.5)
    vec2 uv = UV - 0.5;
    
    // Calculate distance from center and angle
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // Animate rotation over the script-driven time (frozen when not playing)
    angle += anim_time * gear_speed;
    
    // Create the square teeth wave using a sine wave passed through a clamp
    float teeth_wave = sin(angle * float(teeth_count));
    float teeth_shape = smoothstep(-0.5, 0.5, teeth_wave);
    
    // Interpolate between inner and outer radius to define the gear edge
    float gear_edge = mix(inner_radius, outer_radius, teeth_shape);
    
    // Create anti-aliased masks for the gear body and the center hole
    float pixel_size = fwidth(dist); // Smooths the edges
    float gear_mask = smoothstep(gear_edge, gear_edge - pixel_size, dist);
    float hole_mask = smoothstep(hole_radius, hole_radius + pixel_size, dist);
    
    // Combine masks to get the final cog shape
    float final_shape = gear_mask * hole_mask;
    
    // Output color and transparency
    COLOR = vec4(gear_color.rgb, final_shape * gear_color.a);
}
