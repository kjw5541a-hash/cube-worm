class_name Hud
extends CanvasLayer

# 위쪽: 점수, 빌드 버전과 fps, 맵 회전 버튼 2개. 죽은 뒤에는 다시 시작 안내.

signal turn_pressed(dir: int)

var score_label := Label.new()
var info_label := Label.new()
var restart_label := Label.new()
var level_label := Label.new()
var clear_label := Label.new()
var _version := str(ProjectSettings.get_setting("application/config/version", "dev"))

func _ready() -> void:
	score_label.position = Vector2(24, 16)
	score_label.add_theme_font_size_override("font_size", 48)
	add_child(score_label)
	info_label.position = Vector2(24, 80)
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.modulate = Color(1, 1, 1, 0.6)
	add_child(info_label)
	restart_label.text = "탭하면 다시 시작"
	restart_label.add_theme_font_size_override("font_size", 40)
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	restart_label.offset_top = 130
	restart_label.visible = false
	add_child(restart_label)
	level_label.position = Vector2(262, 20)
	level_label.add_theme_font_size_override("font_size", 40)
	add_child(level_label)
	clear_label.text = "레벨 클리어!\n탭하면 다음 레벨"
	clear_label.add_theme_font_size_override("font_size", 44)
	clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	clear_label.offset_top = 130
	clear_label.visible = false
	add_child(clear_label)
	for d in [-1, 1]:
		var b := TurnButton.new(d)
		b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		b.position = Vector2(-120 if d == 1 else -232, 16)
		b.pressed_dir.connect(turn_pressed.emit)
		add_child(b)

func set_score(v: int) -> void:
	score_label.text = str(v)

func show_restart(on: bool) -> void:
	restart_label.visible = on

func set_level(n: int) -> void:
	level_label.text = "레벨 %d" % n

func show_clear(on: bool) -> void:
	clear_label.visible = on

# 벌레를 먹은 점수 "+N" 을 화면 위치 at(뷰포트 좌표)에서 위로 떠올렸다가 사라지게 한다.
func pop(text: String, at: Vector2, color := Color(1.0, 0.9, 0.45)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.position = at - l.get_minimum_size() * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 90.0, Tuning.POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, Tuning.POP_TIME * 0.45).set_delay(Tuning.POP_TIME * 0.55)
	tw.chain().tween_callback(l.queue_free)
	return l

func _process(_delta: float) -> void:
	info_label.text = "%s  %d fps" % [_version, Engine.get_frames_per_second()]

# 맵 회전 버튼. ⟲⟳ 같은 기호는 한글 폰트에 없어 네모로 나오므로 직접 그린다.
class TurnButton extends Control:
	signal pressed_dir(dir: int)
	var dir := 1

	func _init(d: int) -> void:
		dir = d
		size = Vector2(104, 104)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			pressed_dir.emit(dir)
			accept_event()

	# 240° 호 + 화살촉. dir = 1 이면 시계 방향, -1 이면 좌우를 뒤집어 반시계.
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 46.0, Color(1, 1, 1, 0.12))
		var flip := Vector2(dir, 1)
		var arc := PackedVector2Array()
		for k in 25:
			var a := deg_to_rad(-210.0 + 240.0 * k / 24.0)
			arc.append(c + Vector2(cos(a), sin(a)) * 24.0 * flip)
		draw_polyline(arc, Color.WHITE, 5.0, true)
		var a1 := deg_to_rad(30.0)
		var tip := Vector2(cos(a1), sin(a1)) * 24.0
		var tan := Vector2(-sin(a1), cos(a1))
		var out := Vector2(cos(a1), sin(a1))
		draw_colored_polygon(PackedVector2Array([
			c + (tip + tan * 12.0) * flip,
			c + (tip - tan * 4.0 + out * 10.0) * flip,
			c + (tip - tan * 4.0 - out * 10.0) * flip,
		]), Color.WHITE)
