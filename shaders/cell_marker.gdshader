shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;

// 지렁이 머리가 있는 칸을 감싸는 블록: 옅은 면과 굵은 모서리. 흙·벽에 가려져도 보인다.
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.4, 0.14);
uniform vec4 edge : source_color = vec4(1.0, 0.95, 0.6, 0.95);
uniform float edge_width = 0.06;

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float e = 1.0 - smoothstep(edge_width * 0.7, edge_width, min(d.x, d.y));
	ALBEDO = mix(tint.rgb, edge.rgb, e);
	ALPHA = mix(tint.a, edge.a, e);
}
