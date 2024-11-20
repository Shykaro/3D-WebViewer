shader_type spatial;

void fragment() {
    vec3 normal_color = NORMAL * 0.5 + vec3(0.5);
    ALBEDO = normal_color;
}
