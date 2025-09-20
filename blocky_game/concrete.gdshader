shader_type spatial;

uniform float skew_amount = 0.05;
uniform sampler3D noise_texture;

varying vec3 world_position_skewed;


// Blender bump port from: https://github.com/RBerezkin/Godot-Blender-Shaders-Port/blob/master/addons/blender_visual_shaders/bump.gd

vec3 node_bump (
	float strength,
	float dist,
	float height,
	vec3 normal,
	vec3 surf_pos,
	float invert,
	mat4 ViewMatrix,
	mat4 ViewMatrixInverse
) {
	normal = mat3(ViewMatrix) * normalize(normal);

	if (invert != 0.0) {
		dist *= -1.0;
	}

	vec3 dPdx = dFdx(surf_pos);
	vec3 dPdy = dFdy(surf_pos);

	/* Get surface tangents from normal. */
	vec3 Rx = cross(dPdy, normal);
	vec3 Ry = cross(normal, dPdx);

	/* Compute surface gradient and determinant. */
	float det = dot(dPdx, Rx);
	float absdet = abs(det);

	float dHdx = dFdx(height);
	float dHdy = dFdy(height);
	vec3 surfgrad = dHdx * Rx + dHdy * Ry;

	strength = max(strength, 0.0);

	vec3 out_normal = normalize(absdet * normal - dist * sign(det) * surfgrad);
	out_normal = normalize(mix(normal, out_normal, strength));

	out_normal = mat3(ViewMatrixInverse) * out_normal;
	return out_normal;
}


//// Helper math functions

vec3 matrix_mult(mat4 matrix, vec3 vector) {
  return (matrix * vec4(vector, 1.0)).xyz;
}

float remap(float value, float input_min, float input_max, float output_min, float output_max) {
	return output_min + (output_max - output_min) * ((value - input_min) / (input_max - input_min));
}

vec3 remap_vec3(vec3 value, float input_min, float input_max, float output_min, float output_max) {
	return vec3(
		remap(value.x, input_min, input_max, output_min, output_max),
		remap(value.y, input_min, input_max, output_min, output_max),
		remap(value.z, input_min, input_max, output_min, output_max));
}


void vertex() {
	// Skew the vertex position so that there are no flat faces on any voxels.
	// This breaks up voxel tiling.
	vec3 vertex_skewed = VERTEX;
	vertex_skewed.x += VERTEX.y * skew_amount + VERTEX.z * skew_amount;
	vertex_skewed.y += VERTEX.x * skew_amount + VERTEX.z * skew_amount;
	vertex_skewed.z += VERTEX.x * skew_amount + VERTEX.y * skew_amount;

	world_position_skewed = matrix_mult(MODEL_MATRIX, vertex_skewed);
}

void fragment() {
	vec3 noise_sample = texture(noise_texture, world_position_skewed * .25).rgb;
	noise_sample = remap_vec3(noise_sample, -3., 0., -1., 1.);
	vec3 noise_sample2 = texture(noise_texture, world_position_skewed * .5).rgb;
	noise_sample2 = remap_vec3(noise_sample2, -1., 1., 0., 1.);
	noise_sample -= noise_sample2 * .5;

	vec3 bump = node_bump(.05, .5, noise_sample.r, vec3(1.), world_position_skewed, 0., VIEW_MATRIX, INV_VIEW_MATRIX);
	NORMAL_MAP = bump;
	ALBEDO = noise_sample.rgb * .1;
}
