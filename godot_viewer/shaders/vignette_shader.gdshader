shader_type canvas_item;

uniform vec2 focus_center;  
uniform float vignette_radius = 0.2; 
uniform float vignette_softness = 0.5;

void fragment() {

    float distance = length(UV - focus_center);


    float alpha = smoothstep(vignette_radius, vignette_radius + vignette_softness, distance);


    COLOR.a *= alpha;
}