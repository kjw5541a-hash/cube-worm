extends SceneTree

# 방식별 흐름(Main): 기존 방식의 최고 점수, 타임어택의 타이머·죽음·클리어·기록.
# Main 하나를 띄워 두고 테스트마다 저장 파일을 비운 뒤 start_mode 로 새 세션을 연다.
# 프레임을 기다리지 않고 _process 를 직접 불러 시간을 정확히 정한다.

var _main: Node

func _initialize() -> void:
	SaveData.PATH = "user://test_modes_flow.cfg"  # 실제 기록을 건드리지 않는다
	_reset()
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	_main = load("res://scenes/main.tscn").instantiate()
	view.add_child(_main)
	await process_frame
	_main.title.visible = false  # 시작 화면은 넘긴 것으로 친다
	_test_classic_best_score()
	_test_classic_first_record_is_quiet()
	_test_classic_debug_start_does_not_record()
	_test_classic_combo_and_gold()
	_test_time_attack_setup_and_timer()
	_test_time_attack_death_retries_new_layout()
	_test_time_attack_clear_records()
	_test_time_attack_has_no_gold_or_combo_line()
	_test_game_stops_while_title_is_open()
	_test_menu_flow()
	_test_rotation_pauses_timer()  # 회전 애니메이션이 끝나지 않은 채 남으므로 마지막에 둔다
	_reset()
	print("test_modes_flow: OK")
	quit()

func _reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))

# HUD 에 떠 있는 라벨 중 글자가 text 인 것의 수(떠오르는 문구를 센다).
func _count(text: String) -> int:
	return _main.hud.get_children().filter(func(n: Node) -> bool: return n is Label and n.text == text).size()

# 마지막 벌레를 먹고 seconds 초 만에 클리어한 상태로 만든다(실제 플레이를 건너뛴다).
func _clear_with(seconds: float) -> void:
	var g: Game = _main.game
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.elapsed = seconds
	g.state = Game.State.CLEARED
	g.cleared.emit()

func _test_classic_best_score() -> void:
	_reset()
	SaveData.save_best_score(5)
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main.mode == Title.Mode.CLASSIC and _main.best_score == 5, "기존 방식으로 시작하고 저장된 최고 점수를 읽는다")
	assert(_main.hud.best_label.text == "최고 5", "HUD 에 최고 점수")
	assert(_main.hud.score_label.visible and not _main.hud.timer_label.visible and not _main.hud.bugs_label.visible, "기존 방식은 점수를 보인다")
	assert(_main.level == 1 and _main.hud.level_label.text == "레벨 1", "레벨 1 에서 시작")
	var cell := Vector3i(3, 4, 4)
	var pops := _count("신기록!")
	_main.game.score = 3
	_main._on_ate(0, 1, cell)
	assert(_main.best_score == 5 and SaveData.load_best_score() == 5 and _count("신기록!") == pops, "최고 아래에서는 아무 일 없다")
	_main.game.score = 6
	_main._on_ate(0, 1, cell)
	assert(_main.best_score == 6 and SaveData.load_best_score() == 6, "최고를 넘는 순간 갱신하고 바로 저장한다")
	assert(_main.hud.best_label.text == "최고 6", "HUD 최고 점수도 바뀐다")
	assert(_count("신기록!") == pops + 1, "이전 기록이 있었으니 신기록을 한 번 알린다")
	_main.game.score = 7
	_main._on_ate(0, 1, cell)
	assert(_main.best_score == 7 and SaveData.load_best_score() == 7 and _count("신기록!") == pops + 1, "계속 넘어도 신기록 알림은 한 번뿐")
	_main.game.state = Game.State.DEAD
	_main._dead_time = Tuning.DEATH_DELAY + 1.0
	_main._restart_if_ready()
	assert(_main.game.score == 0 and _main.best_score == 7 and SaveData.load_best_score() == 7, "죽어서 점수가 돌아가도 최고는 내려가지 않는다")

func _test_classic_first_record_is_quiet() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main.best_score == 0 and _main.hud.best_label.text == "최고 --", "기록이 없으면 최고 --")
	var pops := _count("신기록!")
	_main.game.score = 2
	_main._on_ate(0, 1, Vector3i(3, 4, 4))
	assert(_main.best_score == 2 and SaveData.load_best_score() == 2, "첫 기록도 저장된다")
	assert(_count("신기록!") == pops, "기록이 없던 첫 플레이에서는 신기록을 알리지 않는다")

func _test_classic_debug_start_does_not_record() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 5, false)
	assert(_main.level == 5 and not _main._record_enabled, "확인용 시작 레벨(?level=5)에서는 기록을 쓰지 않는다")
	_main.game.score = 9
	_main._on_ate(0, 1, Vector3i(3, 4, 4))
	assert(_main.best_score == 0 and SaveData.load_best_score() == 0, "점수를 올려도 저장되지 않는다")
	_main.start_mode(Title.Mode.CLASSIC, 1, true)
	assert(not _main._record_enabled, "?perf 로 시작한 판도 기록하지 않는다")
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main._record_enabled, "평소 시작은 기록한다")

# 기존 방식: 황금 벌레를 쓰고, 먹는 소리는 게임의 연속 수를 따르고, 콤보 줄은 달리는 동안만 뜬다.
func _test_classic_combo_and_gold() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	var g: Game = _main.game
	assert(g.golden, "기존 방식 판은 황금 벌레를 쓴다")
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible, "콤보가 없으면 줄이 숨어 있다")
	var cell := Vector3i(3, 4, 4)
	g.combo = 3
	_main._on_ate(0, 3, cell)
	assert(_main.sfx.last_id == "eat_0" and is_equal_approx(_main.sfx.last_pitch, Sfx.combo_pitch(3)), "먹는 소리 음높이는 게임의 연속 수를 따른다")
	var pops := _count("+20")
	_main._on_ate(Game.GOLD, 20, cell)
	assert(_main.sfx.last_id == "eat_3" and _count("+20") == pops + 1, "황금 벌레는 eat_3 소리와 +N")
	var gold_pops: Array = _main.hud.get_children().filter(func(n: Node) -> bool: return n is Label and n.text == "+20")
	assert(gold_pops[0].get_theme_color("font_color") == Skins.GOLD["color"], "황금 벌레 점수는 금색")
	var found := _count("황금!")
	g.gold_appeared.emit(cell)
	assert(_main.sfx.last_id == "gold" and _count("황금!") == found + 1, "황금 벌레가 나타나면 소리와 황금! 글자")
	_main.sfx.set_muted(true)
	var plays: int = _main.sfx.plays
	g.gold_appeared.emit(cell)
	_main._on_ate(0, 1, cell)
	assert(_main.sfx.plays == plays, "소리를 끈 동안에는 소리가 없다(글자만 뜬다)")
	_main.sfx.set_muted(false)
	g.state = Game.State.RUNNING
	g.combo = 1
	g.combo_left = Tuning.COMBO_WINDOW * 0.5
	_main._process(0.0)
	assert(_main.hud.combo_label.visible and _main.hud.combo_label.text == "×2", "달리는 중에는 다음 벌레의 배율: %s" % _main.hud.combo_label.text)
	assert(is_equal_approx(_main.hud.combo_bar.size.x, Hud.COMBO_BAR_W * 0.5), "막대는 남은 시간 비율")
	g.combo = Tuning.COMBO_MAX
	_main._process(0.0)
	assert(_main.hud.combo_label.text == "×%d" % Tuning.COMBO_MAX, "배율은 COMBO_MAX 를 넘지 않는다")
	g.state = Game.State.CLEARED
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible, "클리어하면 콤보 줄이 사라진다")
	g.state = Game.State.DEAD
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible, "죽으면 콤보 줄이 사라진다")

# 타임어택: 황금 벌레를 쓰지 않고 콤보 줄도 없다(콤보는 소리 음높이에만 드러난다).
func _test_time_attack_has_no_gold_or_combo_line() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var g: Game = _main.game
	assert(not g.golden, "타임어택 판은 황금 벌레를 쓰지 않는다")
	g.state = Game.State.RUNNING
	g.combo = 2
	g.combo_left = Tuning.COMBO_WINDOW
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible and not _main.hud.combo_bar.visible, "타임어택에는 콤보 줄이 없다")

func _test_time_attack_setup_and_timer() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK, 5, true)  # 확인용 주소 값이 와도 무시한다
	var g: Game = _main.game
	assert(_main.mode == Title.Mode.TIME_ATTACK and _main.level == Tuning.TIME_LEVEL and g.height == Tuning.TIME_LEVEL, "타임어택은 레벨 8 판이다(확인용 주소는 무시)")
	assert(_main._record_enabled, "타임어택은 늘 기록한다")
	assert(_main.hud.timer_label.visible and _main.hud.bugs_label.visible and not _main.hud.score_label.visible, "타이머와 남은 벌레를 보이고 점수는 숨긴다")
	assert(_main.hud.level_label.text == "타임어택" and _main.hud.best_label.text == "최고 --", "가운데 글자")
	_main._process(0.2)
	assert(g.elapsed == 0.0 and _main.hud.timer_label.text == "0.0", "출발 전에는 타이머가 0")
	assert(_main.hud.bugs_label.text == "남은 벌레 9", "벌레 9마리")
	assert(g.press(Worm.Steer.LEFT), "첫 방향 입력으로 출발한다")
	_main._process(0.3)
	assert(is_equal_approx(g.elapsed, 0.3) and _main.hud.timer_label.text == "0.3", "출발하면 타이머가 흐른다: %f" % g.elapsed)

# 죽으면 그 시도는 끝: 타이머가 멈추고, 탭하면 새 배치로 처음부터(타이머 0). 죽은 시도는 기록이 되지 않는다.
func _test_time_attack_death_retries_new_layout() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var g: Game = _main.game
	g.press(Worm.Steer.LEFT)
	_main._process(0.3)
	g.state = Game.State.DEAD  # 막다른 길을 찾아가는 대신 죽은 상태로 만든다
	var at_death := g.elapsed
	_main._process(0.5)
	assert(g.elapsed == at_death, "죽으면 타이머가 멈춘다")
	_main._dead_time = Tuning.DEATH_DELAY + 1.0
	_main._restart_if_ready()
	assert(_main.game != g and _main.game.elapsed == 0.0 and _main.game.state == Game.State.WAITING, "탭하면 새 판, 타이머는 0")
	assert(_main.game.field.rocks != g.field.rocks, "바위를 새로 놓는다")
	assert(_main.game.field.bugs != g.field.bugs, "벌레를 새로 놓는다")
	assert(SaveData.load_best_time_ms(Records.time_layout()) == 0, "죽은 시도는 기록이 되지 않는다")

func _test_time_attack_clear_records() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var layout := Records.time_layout()
	_clear_with(42.31)
	assert(_main.best_time_ms == 42310 and SaveData.load_best_time_ms(layout) == 42310, "첫 클리어가 기록이 된다")
	assert(_main.hud.clear_label.text == "클리어!\n42.31초\n첫 기록!\n탭하면 다시 도전", "첫 기록 문구: %s" % _main.hud.clear_label.text)
	assert(_main.hud.best_label.text == "최고 42.31초", "HUD 최고 시간")
	assert(_main.sfx.last_id == "clear", "클리어 소리")
	_main._dead_time = Tuning.CLEAR_DELAY + 0.1
	_main._restart_if_ready()
	assert(_main.level == Tuning.TIME_LEVEL and _main.game.state == Game.State.WAITING and _main.game.elapsed == 0.0, "클리어 뒤 탭하면 레벨 8 을 다시 한다(다음 레벨로 가지 않는다)")
	_clear_with(50.0)
	assert(SaveData.load_best_time_ms(layout) == 42310 and _main.best_time_ms == 42310, "더 느린 시간은 기록을 바꾸지 않는다")
	assert(_main.hud.clear_label.text == "클리어!\n50.00초\n최고 42.31초\n탭하면 다시 도전", "느린 기록 문구: %s" % _main.hud.clear_label.text)
	_main._dead_time = Tuning.CLEAR_DELAY + 0.1
	_main._restart_if_ready()
	_clear_with(42.31)
	assert(SaveData.load_best_time_ms(layout) == 42310, "같은 시간은 기록을 바꾸지 않는다")
	assert(_main.hud.clear_label.text == "클리어!\n42.31초\n최고 42.31초\n탭하면 다시 도전", "같은 시간 문구: %s" % _main.hud.clear_label.text)
	_main._dead_time = Tuning.CLEAR_DELAY + 0.1
	_main._restart_if_ready()
	_clear_with(41.8)
	assert(_main.best_time_ms == 41800 and SaveData.load_best_time_ms(layout) == 41800, "더 빠르면 신기록")
	assert(_main.hud.clear_label.text == "클리어!\n41.80초\n신기록!\n탭하면 다시 도전", "신기록 문구: %s" % _main.hud.clear_label.text)
	assert(_main.hud.best_label.text == "최고 41.80초", "HUD 최고 시간도 바뀐다")

func _test_game_stops_while_title_is_open() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	_main.game.press(Worm.Steer.LEFT)
	_main._process(0.2)
	var t: float = _main.game.elapsed
	assert(t > 0.0, "달리는 중에는 시계가 흐른다")
	_main.title.visible = true
	_main._process(1.0)
	assert(_main.game.elapsed == t and _main.game.state == Game.State.RUNNING, "시작·선택 화면이 떠 있는 동안 게임이 멈춘다")
	_main.title.visible = false

func _test_rotation_pauses_timer() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var g: Game = _main.game
	g.press(Worm.Steer.LEFT)
	_main._process(0.3)
	var t := g.elapsed
	_main.rig.turn(1)
	_main._process(0.1)
	assert(g.elapsed == t, "맵이 도는 동안에는 타이머가 멈춘다")

# 시작 그림 → 방식 선택 → 판 → 메뉴 버튼 → 다시 선택: 화면 흐름과 최고 기록 표시.
func _test_menu_flow() -> void:
	_reset()
	SaveData.save_best_score(128)
	SaveData.save_best_time_ms(42310, Records.time_layout())
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(main)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	assert(main.title.visible and not main.title.in_menu, "처음에는 시작 그림")
	main.title.image._gui_input(tap)
	assert(main.title.in_menu and main.sfx.music_active, "첫 터치로 방식 선택이 열리고 BGM 이 시작된다")
	assert(main.title.buttons[Title.Mode.CLASSIC].record.text == "최고 점수 128", "방식 선택에 최고 점수")
	assert(main.title.buttons[Title.Mode.TIME_ATTACK].record.text == "최고 기록 42.31초", "방식 선택에 최고 시간")
	main.title.buttons[Title.Mode.TIME_ATTACK]._gui_input(tap)
	assert(not main.title.visible and main.mode == Title.Mode.TIME_ATTACK and main.game.height == Tuning.TIME_LEVEL, "타임어택을 고르면 레벨 8 판이 준비된다")
	assert(main.sfx.last_id == "start" and main.hud.best_label.text == "최고 42.31초", "시작 소리, HUD 에 최고 시간")
	# 게임 중 메뉴 버튼: 최신 기록을 읽어 선택 화면으로 돌아오고, 그동안 게임은 멈춘다.
	var running: Game = main.game
	running.press(Worm.Steer.LEFT)
	main._process(0.2)
	var t := running.elapsed
	SaveData.save_best_score(200)
	main.hud.menu_button._gui_input(tap)
	assert(main.title.visible and main.title.in_menu, "메뉴 버튼으로 방식 선택 화면에 돌아온다")
	assert(main.title.buttons[Title.Mode.CLASSIC].record.text == "최고 점수 200", "돌아오면 최신 기록을 다시 읽는다")
	main._process(1.0)
	assert(running.elapsed == t, "선택 화면이 떠 있는 동안 게임이 멈춘다")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(main.game == running, "선택 화면 뒤에서는 입력이 게임에 닿지 않는다")
	# 같은 방식을 다시 골라도 새 판이다.
	main.title.buttons[Title.Mode.TIME_ATTACK]._gui_input(tap)
	assert(main.game != running and main.game.elapsed == 0.0 and main.game.state == Game.State.WAITING, "같은 방식을 다시 골라도 새 판이다")
	main.hud.menu_button._gui_input(tap)
	main.title.buttons[Title.Mode.CLASSIC]._gui_input(tap)
	assert(main.mode == Title.Mode.CLASSIC and main.level == 1 and main.game.score == 0, "기존 방식은 새 세션(레벨 1, 점수 0)")
	assert(main.hud.level_label.text == "레벨 1" and main.hud.score_label.visible and not main.hud.timer_label.visible, "기존 방식 HUD 로 돌아온다")
	view.queue_free()
