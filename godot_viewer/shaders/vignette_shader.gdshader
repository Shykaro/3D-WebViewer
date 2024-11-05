shader_type canvas_item;

uniform vec2 focus_center;  // Fokuspunkt in Viewport-Koordinaten
uniform float vignette_radius = 0.2;  // Radius der Vignettierung (anpassbar)
uniform float vignette_softness = 0.5;  // Weichheit des Übergangs (anpassbar)

void fragment() {
    // Berechne die Distanz des Pixels zum Fokuspunkt
    float distance = length(UV - focus_center);

    // Berechne die Transparenz basierend auf der Distanz
    float alpha = smoothstep(vignette_radius, vignette_radius + vignette_softness, distance);

    // Wende die Transparenz auf die aktuelle Farbe an
    COLOR.a *= alpha;
}