shader_type spatial;
render_mode unshaded;

// 흙 상자의 먼 쪽 벽 2개와 바닥. 지층 띠(깊을수록 짙게), 옅은 칸 격자, 벽 위 가장자리 풀 띠.
uniform float box_size = 8.0;
uniform vec3 top_soil : source_color = vec3(0.56, 0.39, 0.25);
uniform vec3 deep_soil : source_color = vec3(0.24, 0.15, 0.10);
uniform vec3 grass : source_color = vec3(0.38, 0.63, 0.28);
uniform float grid_strength = 0.22;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 가장 가까운 정수 격자선에 가까울수록 1.
float grid_line(float v) {
	float d = abs(fract(v + 0.5) - 0.5);
	return 1.0 - smoothstep(0.0, fwidth(v) * 1.2, d);
}

void fragment() {
	float h = clamp(v_world.y / box_size, 0.0, 1.0);
	vec3 col = mix(deep_soil, top_soil, min(floor(h * 4.0) / 3.0, 1.0));
	// 면의 법선 축은 빼고 나머지 두 축의 정수선만 긋는다.
	float g = 0.0;
	if (v_normal.x < 0.5) g = max(g, grid_line(v_world.x));
	if (v_normal.y < 0.5) g = max(g, grid_line(v_world.y));
	if (v_normal.z < 0.5) g = max(g, grid_line(v_world.z));
	col = mix(col, vec3(0.0), g * grid_strength);
	if (v_normal.y < 0.5 && v_world.y > box_size - 0.15) {
		col = grass;
	}
	ALBEDO = col;
}
