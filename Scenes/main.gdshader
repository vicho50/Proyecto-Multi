shader_type canvas_item;

uniform vec4 shine_color : source_color = vec4(1.0);
uniform float shine_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float shine_size : hint_range(0.01, 1.0, 0.01) = 0.1;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float val = sin(UV.x - UV.y + TIME * shine_speed);
    
    float shine = smoothstep(1.0 - shine_size, 1.0, val);
    
    COLOR.rgb = mix(tex.rgb, shine_color.rgb, shine * shine_color.a);
    COLOR.a = tex.a;
}