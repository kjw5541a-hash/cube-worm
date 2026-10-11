shader_type spatial;
// 뒷면도 그린다: 다른 층 물체는 속이 비어 있어 뒤쪽 모서리까지 보여야 정육면체 윤곽이 된다(같은 층은 깊이 검사로 가려진다).
render_mode specular_disabled, cull_disabled;

// 지렁이·벌레·바위가 같이 쓴다. 깊을수록 어둡게 칠해(높이 색) 화면에서 겹친 물체의 높이를 가른다.
uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 band_color : source_color = vec3(1.0);
uniform float emission = 0.0;
uniform float box_height = 8.0;
uniform float min_bright = 0.6;
// 지렁이 머리가 있는 층. 이 층 밖의 물체는 윤곽만 남기고 속은 비워 층을 가른다.
global uniform float focus_layer;
uniform float outline_bevel = 0.88;   // 면 법선의 가장 큰 축 성분이 이보다 작으면 모서리(둥근 부분)
uniform float outline_rim = 0.3;      // 시선과 법선이 이보다 비스듬하면 실루엣

varying float v_band;
varying vec3 v_local_normal;
varying float v_origin_y;

void vertex() {
	// MultiMesh 인스턴스 색의 알파가 0 이면 밝은 띠(지렁이 환대) 마디다.
	// 인스턴스 색이 없는 메시는 COLOR 알파가 1 이라 띠가 아니다.
	v_band = 1.0 - COLOR.a;
	v_local_normal = NORMAL;
	v_origin_y = MODEL_MATRIX[3].y;  // 인스턴스 하나의 중심 높이: 어느 층에 있는지
}

void fragment() {
	bool in_focus = v_origin_y >= focus_layer - 0.02 && v_origin_y <= focus_layer + 1.02;
	if (!in_focus) {
		vec3 n = abs(normalize(v_local_normal));
		bool edge = max(n.x, max(n.y, n.z)) < outline_bevel || abs(dot(normalize(NORMAL), normalize(VIEW))) < outline_rim;
		if (!edge) {
			discard;
		}
	}
	float y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	vec3 base = mix(albedo, band_color, v_band) * mix(min_bright, 1.0, clamp(y / box_height, 0.0, 1.0));
	ALBEDO = base;
	EMISSION = base * emission;
}
