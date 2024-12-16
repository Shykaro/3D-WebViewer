shader_type spatial;
render_mode unshaded; // Remove this line to apply lighting.

/*
	Uniforms;
	
	'Matcap' is the matcap texture.
	'Margin' reduces the size of the final UV, to avoid seams.
	'Is Spatial' allows horizontal wrapping.
*/
uniform sampler2D matcap: source_color, hint_default_black;
uniform float margin: hint_range(0.0, 0.099) = 0.008;
uniform bool is_spatial = false;

/*
	Varyings;
	
	World-space normal, position, and eye position.
*/
varying vec3 v_world_normal;
varying vec3 v_world_pos;
varying vec3 v_eye_pos;

// Up direction.
const vec3 up = vec3(0.0, 1.0, 0.0);

void vertex() {
	/*
		Set varyings into place;
	*/
	v_world_normal = (MODEL_NORMAL_MATRIX * NORMAL);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_eye_pos = (INV_VIEW_MATRIX * vec4(EYE_OFFSET, 1.0)).xyz;
}

void fragment() {
	/*
		Fix the normal, and calculate the direction from the eye position.
		Then calculate the reflection based on both of these.
		All of this in world space, for convenience.
	*/
	vec3 normal = normalize(v_world_normal);
	vec3 view_dir = normalize(v_eye_pos - v_world_pos);
	vec3 reflection = reflect(view_dir, normal);
	
	/*
		Find the horizontal and vertical target direction.
		Differs if we're going spatial.
	*/
	float vert = dot(reflection, up);
	float hor;
	if (is_spatial) {
		hor = cross(reflection, up).z;
	} else {
		hor = cross(reflection, normal).y;
	}
	
	/*
		Calculate the UV based on the horizontal and vertical direction.
		Account for the margin.
	*/
	vec2 uv = vec2(hor, vert) * (1.0 - margin);
	uv = 0.5 + 0.5 * uv;
	
	/*
		Sample the texture and finish up.
	*/
	vec4 color = texture(matcap, uv);
	
	ALBEDO = color.rgb;
	// ALPHA = color.a;
	
}
