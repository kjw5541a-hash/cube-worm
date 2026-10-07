shader_type spatial;
render_mode specular_disabled;

// 지렁이·벌레·바위가 같이 쓴다. 깊을수록 어둡게 칠해(높이 색) 화면에서 겹친 물체의 높이를 가른다.
uniform vec3 albedo : source_color = vec3(1.0);
uniform float emission = 0.0;
uniform float box_height = 8.0;
uniform float min_bright = 0.6;

void fragment() {
	float y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	vec3 base = albedo * mix(min_bright, 1.0, clamp(y / box_height, 0.0, 1.0));
	ALBEDO = base;
	EMISSION = base * emission;
}
