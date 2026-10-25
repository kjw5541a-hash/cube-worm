class_name Hud
extends CanvasLayer

# 위쪽: 점수(타임어택은 타이머), 빌드 버전과 fps, 가운데 레벨·최고 기록, 소리·맵 회전 버튼. 기존 방식은 점수 아래에 콤보 줄. 죽은 뒤에는 다시 시작 안내.
# 왼쪽 위 메뉴 버튼은 방식 선택 화면으로 돌아간다.

signal turn_pressed(dir: int)
signal sound_toggled(muted: bool)
signal menu_pressed

# 가운데 글자(레벨 또는 타임어택, 그 아래 최고 기록)의 왼쪽 끝과 폭: 왼쪽 점수·타이머와 오른쪽 버튼 사이에 놓는다.
const HEADER_X := 190.0
const HEADER_W := 180.0
const CLEAR_TEXT := "레벨 클리어!\n탭하면 다음 레벨"
const COMBO_BAR_W := 120.0   # 콤보 막대가 꽉 찼을 때의 폭

var score_label := Label.new()
var info_label := Label.new()
var restart_label := Label.new()
var level_label := Label.new()
var clear_label := Label.new()
var sound_button := SoundButton.new()
var timer_label := Label.new()   # 타임어택 타이머(점수 자리)
var best_label := Label.new()    # 레벨 글자 아래 최고 기록
var bugs_label := Label.new()    # 타임어택 남은 벌레
var combo_label := Label.new()   # 기존 방식: 다음 벌레에 붙을 배율 ×N
var combo_bar := ColorRect.new() # 남은 콤보 시간(폭이 줄어든다)
var menu_button := HomeButton.new()
var _version := str(ProjectSettings.get_setting("application/config/version", "dev"))

func _ready() -> void:
	score_label.position = Vector2(24, 16)
	score_label.add_theme_font_size_override("font_size", 48)
	add_child(score_label)
	info_label.position = Vector2(24, 88)  # 빌드 문구는 길어서 가운데까지 뻗는다: 그 위의 레벨·최고 글자와 세로로 비켜 놓는다
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
	level_label.position = Vector2(HEADER_X, 0)
	level_label.custom_minimum_size = Vector2(HEADER_W, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 38)
	add_child(level_label)
	best_label.position = Vector2(HEADER_X, 52)
	best_label.custom_minimum_size = Vector2(HEADER_W, 0)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 24)
	best_label.modulate = Color(1, 1, 1, 0.75)
	add_child(best_label)
	timer_label.position = Vector2(24, 16)
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.visible = false
	add_child(timer_label)
	bugs_label.position = Vector2(24, 112)
	bugs_label.add_theme_font_size_override("font_size", 24)
	bugs_label.visible = false
	add_child(bugs_label)
	combo_label.position = Vector2(24, 112)  # 타임어택의 남은 벌레와 같은 자리: 두 방식이 나눠 쓴다
	combo_label.add_theme_font_size_override("font_size", 28)
	combo_label.add_theme_color_override("font_color", Skins.GOLD["color"])
	combo_label.visible = false
	add_child(combo_label)
	combo_bar.position = Vector2(80, 124)  # 글자 오른쪽, 세로로는 글자 가운데
	combo_bar.size = Vector2(COMBO_BAR_W, 12)
	combo_bar.color = Skins.GOLD["color"]
	combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 막대 위를 눌러도 게임 입력을 막지 않는다
	combo_bar.visible = false
	add_child(combo_bar)
	clear_label.text = CLEAR_TEXT
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
	sound_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound_button.position = Vector2(-344, 16)  # 회전 버튼 둘(-232, -120) 왼쪽
	sound_button.toggled.connect(sound_toggled.emit)
	add_child(sound_button)
	menu_button.position = Vector2(24, 150)
	menu_button.pressed.connect(menu_pressed.emit)
	add_child(menu_button)

func set_score(v: int) -> void:
	score_label.text = str(v)

func show_restart(on: bool) -> void:
	restart_label.visible = on

func set_level(n: int) -> void:
	level_label.text = "레벨 %d" % n

func show_clear(on: bool) -> void:
	clear_label.visible = on

# 클리어 문구(타임어택은 걸린 시간과 기록이 들어간다).
func set_clear_text(text: String) -> void:
	clear_label.text = text

# 방식별 표시: 기존 방식은 점수, 타임어택은 타이머와 남은 벌레.
func set_mode(mode: int) -> void:
	set_combo(1, 0.0)  # 방식을 바꿀 때마다 콤보 줄은 숨긴 채로 시작한다
	var time_attack := mode == Title.Mode.TIME_ATTACK
	score_label.visible = not time_attack
	timer_label.visible = time_attack
	bugs_label.visible = time_attack
	if time_attack:
		level_label.text = "타임어택"
	else:
		clear_label.text = CLEAR_TEXT

# 타임어택 타이머(초). 소수 첫째 자리까지 보인다.
func set_timer(seconds: float) -> void:
	timer_label.text = Records.format_time(Records.to_ms(seconds), 1)

func set_bugs_left(n: int) -> void:
	bugs_label.text = "남은 벌레 %d" % n

# 콤보 줄(기존 방식): mult 는 다음 벌레에 붙을 배율, frac 은 남은 콤보 시간의 비율. frac 이 0 이하면 숨긴다.
func set_combo(mult: int, frac: float) -> void:
	var on := frac > 0.0
	combo_label.visible = on
	combo_bar.visible = on
	if on:
		combo_label.text = "×%d" % mult
		combo_bar.size.x = COMBO_BAR_W * minf(frac, 1.0)

# 기존 방식 최고 점수. 기록이 없으면 --.
func set_best_score(best: int) -> void:
	best_label.text = "최고 %d" % best if best > 0 else "최고 --"

# 타임어택 최고 시간(밀리초). 기록이 없으면 --.
func set_best_time(ms: int) -> void:
	best_label.text = "최고 %s초" % Records.format_time(ms, 2) if ms > 0 else "최고 --"

# 저장된 값을 버튼에 반영한다(신호는 내지 않는다).
func set_muted(on: bool) -> void:
	sound_button.muted = on
	sound_button.queue_redraw()

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

# 소리 켜짐·꺼짐 버튼. 스피커 기호가 한글 폰트에 없을 수 있어 직접 그린다.
class SoundButton extends Control:
	signal toggled(muted: bool)
	var muted := false

	func _init() -> void:
		size = Vector2(104, 104)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			muted = not muted
			queue_redraw()
			toggled.emit(muted)
			accept_event()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 46.0, Color(1, 1, 1, 0.12))
		var col := Color(1, 1, 1, 0.45 if muted else 1.0)
		# 스피커: 네모 + 나팔
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-22, -9), c + Vector2(-10, -9), c + Vector2(4, -22),
			c + Vector2(4, 22), c + Vector2(-10, 9), c + Vector2(-22, 9),
		]), col)
		if muted:  # ✕
			draw_line(c + Vector2(12, -12), c + Vector2(30, 12), col, 5.0, true)
			draw_line(c + Vector2(30, -12), c + Vector2(12, 12), col, 5.0, true)
		else:  # 소리 파동 두 겹
			for r in [14.0, 24.0]:
				draw_arc(c + Vector2(4, 0), r, deg_to_rad(-45.0), deg_to_rad(45.0), 12, col, 4.0, true)

# 게임 중 방식 선택 화면으로 돌아가는 작은 버튼. 글자는 라벨, 바탕은 직접 그린다.
class HomeButton extends Control:
	signal pressed
	var _label := Label.new()
	var _style := StyleBoxFlat.new()

	func _init() -> void:
		size = Vector2(120.0, 68.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_style.bg_color = Color(1, 1, 1, 0.12)
		_style.set_corner_radius_all(24)
		_label.text = "메뉴"
		_label.add_theme_font_size_override("font_size", 30)
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
