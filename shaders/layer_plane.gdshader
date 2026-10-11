shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// 머리 층 판: 판 아래 물체는 판 너머로 흐리게 보인다. 칸 격자를 옅게 긋는다.
uniform vec4 tint : source_color = vec4(0.95, 0.85, 0.6, 0.16);
uniform vec4 line : source_color = vec4(1.0, 0.95, 0.75, 0.5);

uniform bool border_only = false;  // 천장 판: 가장자리 선만(안쪽 격자선이 지렁이 몸 위에 겹쳐 비치지 않게)
uniform float box = 8.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(float v) {
	float d = abs(fract(v + 0.5) - 0.5);
	return 1.0 - smoothstep(0.0, fwidth(v) * 1.2, d);
}

float edge_line(float v) {
	float d = min(abs(v), abs(v - box));
	return 1.0 - smoothstep(0.0, fwidth(v) * 1.2, d);
}

void fragment() {
	float g = border_only ? max(edge_line(v_world.x), edge_line(v_world.z)) : max(grid_line(v_world.x), grid_line(v_world.z));
	ALBEDO = mix(tint.rgb, line.rgb, g);
	ALPHA = mix(tint.a, line.a, g);
}
