shader_type spatial;
render_mode unshaded;

varying vec3 v_world_normal;

void vertex() {
    v_world_normal = (MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 wnorm = normalize(v_world_normal);
    ALBEDO = (wnorm * 0.5) + vec3(0.5);
}