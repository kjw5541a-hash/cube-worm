class_name SkinPicker
extends Control

# 시작 전 대기 중에 컨트롤러 바로 위에 뜨는 선택 줄: "◀  지렁이 젤리  ▶".
# 왼쪽 버튼은 이전 스킨, 나머지(오른쪽 버튼과 이름 자리)는 다음 스킨이다. 닿는 순간 한 번 바뀐다.
# 화살표는 글꼴에 없는 기호라 직접 그린다.

signal skin_changed(index: int)

const HEIGHT := 112.0
const GAP := 14.0          # 컨트롤러 영역 위쪽과의 간격
const MARGIN := 24.0       # 화면 좌우 여백
const BUTTON_W := 160.0    # 왼쪽 버튼 폭(이 안을 누르면 이전 스킨). 오른쪽 버튼도 같은 폭이다

var index := 0
var _label := Label.new()
var _style := StyleBoxFlat.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = MARGIN
	offset_right = -MARGIN
	offset_bottom = -(Controller.HEIGHT + GAP)
	offset_top = offset_bottom - HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style.bg_color = Color(0.08, 0.05, 0.04, 0.62)
	_style.set_corner_radius_all(24)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = BUTTON_W
	_label.offset_right = -BUTTON_W
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()

# 번호를 바꾼다(신호 없음). 저장된 스킨을 처음 띄울 때 쓴다.
func set_index(i: int) -> void:
	index = posmod(i, Skins.WORMS.size())
	_refresh()

# 한 칸 돌리고(+1 다음, -1 이전, 끝에서 처음으로 이어진다) 바뀌었다고 알린다.
func change(delta: int) -> void:
	set_index(index + delta)
	skin_changed.emit(index)

func _refresh() -> void:
	_label.text = "지렁이  %s" % Skins.WORMS[index]["name"]

func _gui_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t == null or not t.pressed:
		return
	change(-1 if t.position.x < BUTTON_W else 1)
	accept_event()

# PC 테스트용: Q 이전, E 다음. 줄이 보일 때만 듣는다.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree():
		return
	if k.physical_keycode == KEY_Q:
		change(-1)
	elif k.physical_keycode == KEY_E:
		change(1)

func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var l := Vector2(BUTTON_W * 0.5, size.y * 0.5)
	draw_colored_polygon(PackedVector2Array([l + Vector2(-16, 0), l + Vector2(14, -22), l + Vector2(14, 22)]), Color(1, 1, 1, 0.9))
	var r := Vector2(size.x - BUTTON_W * 0.5, size.y * 0.5)
	draw_colored_polygon(PackedVector2Array([r + Vector2(16, 0), r + Vector2(-14, -22), r + Vector2(-14, 22)]), Color(1, 1, 1, 0.9))
