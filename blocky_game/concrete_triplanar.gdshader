// NOTE: Shader automatically converted from Godot Engine 4.5.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0);
varying vec3 uv1_triplanar_pos;

uniform float uv1_blend_sharpness : hint_range(0.0, 150.0, 0.001);
varying vec3 uv1_power_normal;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

uniform sampler2D noise;
uniform sampler2D streak_noise;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;

	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);

	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);

	// UV1 Triplanar: Enabled (with World Triplanar)
	uv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_triplanar_pos = world_position * uv1_scale + uv1_offset;
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
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

void fragment() {
	vec4 absolute_normal = abs(inverse(VIEW_MATRIX) * vec4(NORMAL, .0));
	vec3 noise_sample;
	vec3 noise_sample_2;
	vec3 streak_noise_sample;
	if (absolute_normal.x > 0.1) {
		noise_sample = texture(noise, world_position.yz * .002).xyz;
		noise_sample_2 = texture(noise, world_position.yz * .001).xyz;
		streak_noise_sample = texture(noise, vec2(world_position.y, world_position.z * 10.) * .0002).xyz;
	}
	else if (absolute_normal.y > 0.1) {
		noise_sample = texture(noise, world_position.xz * .002).xyz;
		noise_sample_2 = texture(noise, world_position.xz * .001).xyz;
		streak_noise_sample = texture(noise, world_position.xz * .0002).xyz;
	}
	else if (absolute_normal.z > 0.1) {
		noise_sample = texture(noise, world_position.xy * .002).xyz;
		noise_sample_2 = texture(noise, world_position.xy * .001).xyz;
		streak_noise_sample = texture(noise, vec2(world_position.x * 10., world_position.y) * .0002).xyz;
	}
	//streak_noise_sample = remap_vec3(streak_noise_sample, .7, 1., .5, 1.);
	streak_noise_sample = clamp(streak_noise_sample, vec3(.5), vec3(1.));
	//streak_noise_sample -= .15;
	ALBEDO = noise_sample;
	
	vec3 albedo_tex = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos).rgb;
	vec3 color = mix(albedo_tex, vec3(.6, .55, .4), .3);
	color = mix(color, noise_sample, .15);
	color = mix(color, noise_sample_2, .1);
	color = mix(color, streak_noise_sample, .3);
	ALBEDO = albedo.rgb * color;

	float metallic_tex = dot(triplanar_texture(texture_metallic, uv1_power_normal, uv1_triplanar_pos), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(triplanar_texture(texture_roughness, uv1_power_normal, uv1_triplanar_pos), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;

	// Normal Map: Enabled
	NORMAL_MAP = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
