// 지렁이 머리가 있는 층. 이 층 밖의 물체는 흐릿한 회색 유령으로만 그린다(ghost.gdshader).
global uniform float focus_layer;

// y 는 물체(인스턴스) 중심의 월드 높이. 층 경계에서 깜빡이지 않게 조금 여유를 둔다.
bool in_focus(float y) {
	return y >= focus_layer - 0.02 && y <= focus_layer + 1.02;
}
