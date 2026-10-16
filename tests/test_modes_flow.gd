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
	_test_time_attack_setup_and_timer()
	_test_time_attack_death_retries_same_layout()
	_test_time_attack_clear_records()
	_test_game_stops_while_title_is_open()
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

func _test_time_attack_setup_and_timer() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK, 5, true)  # 확인용 주소 값이 와도 무시한다
	var g: Game = _main.game
	var ref := Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)
	assert(_main.mode == Title.Mode.TIME_ATTACK and _main.level == Tuning.TIME_LEVEL and g.height == Tuning.TIME_LEVEL, "타임어택은 레벨 8 판이다(확인용 주소는 무시)")
	assert(g.field.bugs == ref.field.bugs and g.field.rocks == ref.field.rocks, "고정 시드 배치다")
	assert(_main._record_enabled, "타임어택은 늘 기록한다")
	assert(_main.hud.timer_label.visible and _main.hud.bugs_label.visible and not _main.hud.score_label.visible, "타이머와 남은 벌레를 보이고 점수는 숨긴다")
	assert(_main.hud.level_label.text == "타임어택" and _main.hud.best_label.text == "최고 --", "가운데 글자")
	_main._process(0.2)
	assert(g.elapsed == 0.0 and _main.hud.timer_label.text == "0.0", "출발 전에는 타이머가 0")
	assert(_main.hud.bugs_label.text == "남은 벌레 9", "벌레 9마리")
	assert(g.press(Worm.Steer.LEFT), "첫 방향 입력으로 출발한다")
	_main._process(0.3)
	assert(is_equal_approx(g.elapsed, 0.3) and _main.hud.timer_label.text == "0.3", "출발하면 타이머가 흐른다: %f" % g.elapsed)

# 죽으면 그 시도는 끝: 타이머가 멈추고, 탭하면 같은 배치로 처음부터(타이머 0). 죽은 시도는 기록이 되지 않는다.
func _test_time_attack_death_retries_same_layout() -> void:
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
	var ref := Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)
	assert(_main.game != g and _main.game.elapsed == 0.0 and _main.game.state == Game.State.WAITING, "탭하면 새 판, 타이머는 0")
	assert(_main.game.field.bugs == ref.field.bugs and _main.game.field.rocks == ref.field.rocks, "같은 배치로 다시 한다")
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
	assert(_main.level == Tuning.TIME_LEVEL and _main.game.state == Game.State.WAITING and _main.game.elapsed == 0.0, "클리어 뒤 탭하면 같은 판을 다시 한다(다음 레벨로 가지 않는다)")
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
