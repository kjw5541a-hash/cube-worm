shader_type spatial;
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_back, blend_mix;

// 비침: 깊이 검사를 뒤집어 다른 물체에 가려진 부분에만 그린다.
// 자기 겉면과 깊이가 같아 얼룩지지 않도록 카메라 쪽으로 pull 만큼 당긴다(직교 투영이라 화면 위치는 그대로).
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.7, 0.55);
uniform float pull = 0.05;
uniform bool ignore_focus = false;
#include "res://shaders/focus.gdshaderinc"

varying float v_origin_y;

void vertex() {
	v_origin_y = MODEL_MATRIX[3].y;
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.z += pull;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	if (!ignore_focus && !in_focus(v_origin_y)) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
