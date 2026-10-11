shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, blend_mix;

// 머리가 있는 층 밖의 물체: 매우 흐린 회색. 깊이를 쓰지 않아 뒤의 물체를 가리지 않는다.
#include "res://shaders/focus.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.6);
uniform float alpha = 0.16;

varying float v_origin_y;

void vertex() {
	v_origin_y = MODEL_MATRIX[3].y;
}

void fragment() {
	if (in_focus(v_origin_y)) {
		discard;
	}
	float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
	ALBEDO = vec3(0.45 + lum * 0.3);  // 색은 거의 지우고 밝기만 남긴 회색
	ALPHA = alpha;
}
