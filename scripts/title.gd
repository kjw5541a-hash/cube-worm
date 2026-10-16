class_name Title
extends CanvasLayer

# 시작 화면(TAP): 그림 한 장이 화면을 채운다. 어디든 터치하면 방식 선택(MENU)이 열린다.
# MENU: 같은 그림 위에 방식 버튼 둘이 뜬다. 그림 아래쪽에 박힌 TAP TO START 글자는 어두운 띠로 덮는다.
# 버튼을 누르면 mode_chosen 신호를 내고 사라진다. 게임 중 HUD 의 메뉴 버튼은 show_menu() 로 MENU 를 다시 연다.

signal started                 # 첫 터치(TAP → MENU). 웹은 첫 터치 뒤에야 소리가 풀리므로 밖에서 이때 BGM 을 시작한다
signal mode_chosen(mode: int)  # 고른 방식(Mode)

# 게임 방식. 방식 선택 화면의 버튼 순서와 같다.
enum Mode { CLASSIC, TIME_ATTACK }

const IMAGE := "res://assets/title.jpg"
const SHADE_H := 620.0         # MENU 에서 화면 아래쪽을 덮는 어두운 띠의 높이
const BOX_GAP := 130.0         # 버튼 묶음 아래와 화면 아래 가장자리 사이
const BUTTON_W := 560.0
const BUTTON_H := 160.0
const BUTTON_GAP := 36.0

var image := Picture.new()
var shade := TextureRect.new()
var box := VBoxContainer.new()
var buttons: Array[ModeButton] = []
var in_menu := false           # 방식 선택이 열려 있는가(첫 터치 뒤 true)

func _init() -> void:
	layer = 10  # HUD(1) 위
	add_child(image)
	image.tapped.connect(_on_tapped)
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -SHADE_H
	shade.visible = false
	add_child(shade)
	var box_h := BUTTON_H * 2.0 + BUTTON_GAP
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -BUTTON_W * 0.5
	box.offset_right = BUTTON_W * 0.5
	box.offset_top = -(BOX_GAP + box_h)
	box.offset_bottom = -BOX_GAP
	box.add_theme_constant_override("separation", int(BUTTON_GAP))
	box.visible = false
	add_child(box)
	for m in [Mode.CLASSIC, Mode.TIME_ATTACK]:
		var b := ModeButton.new("기존 방식" if m == Mode.CLASSIC else "타임어택")
		b.chosen.connect(_on_chosen.bind(m))
		box.add_child(b)
		buttons.append(b)
	set_records(0, 0)

# 위는 투명, 아래로 갈수록 배경색으로 짙어지는 세로 그라데이션.
static func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4])
	g.colors = PackedColorArray([Color(0.11, 0.07, 0.05, 0.0), Color(0.11, 0.07, 0.05, 0.96)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	t.width = 8
	t.height = 256
	return t

# 방식 선택 버튼에 내 최고 기록을 적는다(0 = 기록 없음).
func set_records(best_score: int, best_time_ms: int) -> void:
	buttons[Mode.CLASSIC].record.text = ("최고 점수 %d" % best_score) if best_score > 0 else "기록 없음"
	buttons[Mode.TIME_ATTACK].record.text = ("최고 기록 %s초" % Records.format_time(best_time_ms, 2)) if best_time_ms > 0 else "기록 없음"

# 방식 선택을 다시 연다(게임 중 HUD 메뉴 버튼). 시작 신호는 내지 않는다.
func show_menu() -> void:
	visible = true
	_open_menu()

func _open_menu() -> void:
	in_menu = true
	shade.visible = true
	box.visible = true

func _on_tapped() -> void:
	if not visible or in_menu:
		return
	_open_menu()
	started.emit()

func _on_chosen(m: int) -> void:
	visible = false
	mode_chosen.emit(m)

class Picture extends TextureRect:
	signal tapped

	func _init() -> void:
		texture = load(IMAGE)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 버튼이 터치를 받지 않게 막는다

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			tapped.emit()
			accept_event()

# 방식 선택 버튼: 둥근 사각형, 위에 이름, 아래에 한 줄 기록.
class ModeButton extends Control:
	signal chosen
	var title := Label.new()
	var record := Label.new()
	var _style := StyleBoxFlat.new()

	func _init(text: String) -> void:
		custom_minimum_size = Vector2(BUTTON_W, BUTTON_H)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_style.bg_color = Color(0.22, 0.13, 0.08, 0.94)
		_style.border_color = Color(0.98, 0.78, 0.45)
		_style.set_border_width_all(4)
		_style.set_corner_radius_all(44)
		title.text = text
		title.add_theme_font_size_override("font_size", 56)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title.offset_top = 20.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
		record.add_theme_font_size_override("font_size", 32)
		record.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		record.offset_top = 98.0
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(record)

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			chosen.emit()
			accept_event()

	func _draw() -> void:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
