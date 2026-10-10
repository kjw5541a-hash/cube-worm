shader_type spatial;
render_mode specular_disabled;

// 지렁이·벌레·바위가 같이 쓴다. 깊을수록 어둡게 칠해(높이 색) 화면에서 겹친 물체의 높이를 가른다.
uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 band_color : source_color = vec3(1.0);
uniform float emission = 0.0;
uniform float box_height = 8.0;
uniform float min_bright = 0.6;

varying float v_band;

void vertex() {
	// MultiMesh 인스턴스 색의 알파가 0 이면 밝은 띠(지렁이 환대) 마디다.
	// 인스턴스 색이 없는 메시는 COLOR 알파가 1 이라 띠가 아니다.
	v_band = 1.0 - COLOR.a;
}

void fragment() {
	float y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	vec3 base = mix(albedo, band_color, v_band) * mix(min_bright, 1.0, clamp(y / box_height, 0.0, 1.0));
	ALBEDO = base;
	EMISSION = base * emission;
}
