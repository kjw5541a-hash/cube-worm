extends Node3D

# 게임 화면: 게임 진행, 입력 연결, 지렁이 선택, 죽은 뒤 다시 시작.
# 타이틀·일시정지·게임오버 화면은 6단계에서 붙인다.

var game: Game
var rig := CameraRig.new()
var field_view := FieldView.new()
var worm_view := WormView.new()
var hud := Hud.new()
var floors := FloorGauge.new()  # 층 눈금(HUD 위에 얹는다)
var controller := Controller.new()
var picker := SkinPicker.new()
var sfx := Sfx.new()
var title := Title.new()  # 시작 화면: 터치하면 사라지고 게임이 시작을 기다린다
var level := 1          # 지금 판의 레벨(= 맵 높이)
var base_score := 0     # 이 레벨을 시작할 때의 점수. 죽으면 여기서 다시 시작한다
var mode: int = Title.Mode.CLASSIC  # 지금 방식(Title.Mode)
var best_score := 0     # 기존 방식 최고 점수(저장된 값)
var best_time_ms := 0   # 타임어택 최고 시간(밀리초, 저장된 값)
var _record_enabled := true    # 확인용 주소(?level, ?perf)로 시작한 기존 방식 판은 기록을 쓰지 않는다
var _celebrate_best := false   # 기존 방식: 시작 때 기록이 있었고 아직 신기록을 알리지 않았다
var _dead_time := 0.0
var _was_dead := false

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.07, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.9)
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 20.0, 0.0)
	sun.light_energy = 0.9
	add_child(sun)
	rig.position = Vector3.ONE * Tuning.BOX * 0.5
	add_child(rig)
	add_child(field_view)
	add_child(worm_view)
	add_child(sfx)
	sfx.muted = SaveData.load_muted()
	add_child(hud)
	floors.position = Vector2(24, 845)  # 맨 아래 칸의 왼쪽 아래: 지렁이 선택 줄 바로 위
	hud.add_child(floors)
	hud.add_child(controller)
	hud.add_child(picker)
	add_child(title)
	title.started.connect(_on_title_started)
	controller.steer_pressed.connect(_on_steer)
	controller.turn_pressed.connect(_on_turn)
	hud.turn_pressed.connect(_on_turn)
	picker.skin_changed.connect(_on_skin_changed)
	hud.sound_toggled.connect(_on_sound_toggled)
	hud.set_muted(sfx.muted)
	picker.set_index(Skins.worm_index(SaveData.load_skin()))
	worm_view.apply_skin(picker.index)
	start_mode(Title.Mode.CLASSIC)

# 방식을 정하고 새 판을 준비한다. 기존 방식은 새 세션(시작 레벨, 점수 0)이다.
# start_level, perf 는 확인용 주소(?level=N, ?perf)의 값이다. 그렇게 시작한 판은 기록을 쓰지 않는다. 테스트가 바꿔 끼울 수 있게 인자로 둔다.
func start_mode(m: int, start_level := start_level_requested(), perf := perf_requested()) -> void:
	mode = m
	hud.set_mode(mode)
	if mode == Title.Mode.CLASSIC:
		level = start_level
		_record_enabled = start_level == 1 and not perf
	else:
		level = Tuning.TIME_LEVEL  # 타임어택은 확인용 주소를 무시한다
		_record_enabled = true
	base_score = 0
	_refresh_records()
	_celebrate_best = mode == Title.Mode.CLASSIC and best_score > 0
	new_game()

func new_game() -> void:
	if mode == Title.Mode.TIME_ATTACK:
		game = Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)  # 늘 같은 배치
	else:
		game = Game.new(randi(), perf_requested(), level)
	game.score = base_score
	game.ate.connect(_on_ate)
	game.cleared.connect(_on_cleared)
	rig.position = Vector3(Tuning.BOX * 0.5, game.height * 0.5, Tuning.BOX * 0.5)  # 시점은 그대로, 상자 중심을 본다
	controller.vertical = game.height > 1
	if mode == Title.Mode.CLASSIC:
		hud.set_level(game.level)
	hud.show_clear(false)
	field_view.setup(game)
	floors.update_from(game)
	worm_view.setup(game)
	_dead_time = 0.0
	_was_dead = false
	sfx.duck(false)
	hud.show_restart(false)

# 주소 끝 ?level=N(웹) 또는 실행 인자 --level=N(데스크톱)이면 그 레벨에서 시작한다(확인용). 없으면 1.
static func start_level_requested() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			return clampi(int(a.substr(8)), 1, Tuning.LEVEL_MAX)
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search", true))
		var i := q.find("level=")
		if i >= 0:
			return clampi(int(q.substr(i + 6).split("&")[0]), 1, Tuning.LEVEL_MAX)  # to_int 는 숫자가 아닌 글자를 건너뛰고 이어 붙이므로 & 앞에서 자른다
	return 1

# 웹은 주소 끝 ?perf, 데스크톱은 실행 인자 --perf 면 500마디로 시작한다(성능 확인용).
static func perf_requested() -> bool:
	if OS.get_cmdline_user_args().has("--perf"):
		return true
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.search", true)).contains("perf")
	return false

func _process(delta: float) -> void:
	game.paused = rig.is_turning()
	if not title.visible:
		game.advance(delta)  # 시작·방식 선택 화면이 떠 있는 동안 게임은 멈춘다
	hud.set_score(game.score)
	if mode == Title.Mode.TIME_ATTACK:
		hud.set_timer(game.elapsed)
		hud.set_bugs_left(game.field.bugs.size())
	floors.update_from(game)
	picker.visible = game.state == Game.State.WAITING  # 시작 전에만 지렁이를 고른다
	if game.state == Game.State.DEAD:
		if not _was_dead:
			_was_dead = true
			rig.shake()
			sfx.play("die")
			sfx.duck(true)
		_dead_time += delta
		hud.show_restart(_dead_time >= Tuning.DEATH_DELAY)
	elif game.state == Game.State.CLEARED:
		_dead_time += delta
		hud.show_clear(_dead_time >= Tuning.CLEAR_DELAY)

func _on_skin_changed(index: int) -> void:
	sfx.start_music()
	sfx.play("skin")
	worm_view.apply_skin(index)
	SaveData.save_skin(Skins.WORMS[index]["id"])

# 벌레를 먹으면 먹은 칸 위에 점수가 떠오른다. 색은 벌레 종류 색이다.
func _on_ate(kind: int, points: int, cell: Vector3i) -> void:
	sfx.play_eat(kind)
	var at := rig.camera.unproject_position(WormPath.center(cell)) - Vector2(0, 40)
	hud.pop("+%d" % points, at, Skins.BUGS[kind]["color"])
	if mode == Title.Mode.CLASSIC:
		_update_best_score()

func _on_title_started() -> void:
	sfx.start_music()  # 사용자의 첫 터치라서 웹에서도 소리가 풀린다

func _on_steer(steer: int) -> void:
	if title.visible:
		return  # 시작 화면 뒤에서 키보드로 출발하지 않게 한다
	if game.state == Game.State.DEAD or game.state == Game.State.CLEARED:
		_restart_if_ready()
		return
	var was_waiting := game.state == Game.State.WAITING
	if game.press(steer):  # 받아들여진 입력만 소리가 난다
		sfx.start_music()
		sfx.play("start" if was_waiting else Sfx.steer_id(steer))

func _on_turn(dir: int) -> void:
	if title.visible:
		return
	if game.state != Game.State.DEAD:
		rig.turn(dir)
		sfx.start_music()
		sfx.play("rotate")

func _unhandled_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t != null and t.pressed and (game.state == Game.State.DEAD or game.state == Game.State.CLEARED):
		_restart_if_ready()

func _restart_if_ready() -> void:
	if game.state == Game.State.CLEARED:
		if _dead_time >= Tuning.CLEAR_DELAY:
			if mode == Title.Mode.CLASSIC:
				base_score = game.score  # 클리어한 점수는 이어진다
				level = mini(level + 1, Tuning.LEVEL_MAX)
			new_game()  # 타임어택은 같은 판을 다시 한다
	elif _dead_time >= Tuning.DEATH_DELAY:
		new_game()

func _on_sound_toggled(muted: bool) -> void:
	sfx.set_muted(muted)
	SaveData.save_muted(muted)
	if not muted:
		sfx.start_music()  # 사용자의 입력이므로 웹에서도 재생이 풀린다

# 판의 벌레를 전부 먹었다. 타임어택이면 걸린 시간을 기록과 비교해 저장하고 결과 문구를 정한다.
func _on_cleared() -> void:
	sfx.play("clear")
	if mode != Title.Mode.TIME_ATTACK:
		return
	var ms := Records.to_ms(game.elapsed)
	var verdict := Records.judge_time(ms, best_time_ms)
	if verdict != Records.Verdict.NONE:
		best_time_ms = ms
		SaveData.save_best_time_ms(ms, Records.time_layout())
	hud.set_best_time(best_time_ms)
	hud.set_clear_text(Records.time_result_text(ms, verdict, best_time_ms))

# 기존 방식: 점수가 저장된 최고를 넘으면 바로 갱신·저장한다. 시작 때 기록이 있었으면 처음 넘는 순간 한 번 신기록을 알린다.
func _update_best_score() -> void:
	if not _record_enabled or game.score <= best_score:
		return
	var verdict := Records.judge_score(game.score, best_score)
	best_score = game.score
	SaveData.save_best_score(best_score)
	hud.set_best_score(best_score)
	if verdict == Records.Verdict.NEW_BEST and _celebrate_best:
		_celebrate_best = false
		hud.pop("신기록!", Vector2(360.0, 300.0))

# 저장된 최고 기록을 다시 읽어 HUD 에 보인다.
func _refresh_records() -> void:
	best_score = SaveData.load_best_score()
	best_time_ms = SaveData.load_best_time_ms(Records.time_layout())
	if mode == Title.Mode.CLASSIC:
		hud.set_best_score(best_score)
	else:
		hud.set_best_time(best_time_ms)
