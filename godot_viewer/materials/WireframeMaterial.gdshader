shader_type spatial;

uniform vec4 wire_color = vec4(1.0, 1.0, 1.0, 1.0); // hint_color

void fragment() {
    vec3 bary = fract(VERTEX * 10.0); // Größe des Wireframes anpassen
    float line_thickness = 0.02;     // Dicke der Linien
    float min_distance = min(bary.x, min(bary.y, bary.z));
    if (min_distance < line_thickness) {
        ALBEDO = wire_color.rgb;
    } else {
        discard; // Hintergrund ausblenden
    }
}
