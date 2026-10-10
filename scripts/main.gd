extends Node3D

# 게임 화면: 게임 진행, 입력 연결, 지렁이 선택, 죽은 뒤 다시 시작.
# 타이틀·일시정지·게임오버 화면은 6단계에서 붙인다.

var game: Game
var rig := CameraRig.new()
var field_view := FieldView.new()
var worm_view := WormView.new()
var hud := Hud.new()
var controller := Controller.new()
var picker := SkinPicker.new()
var level := 1          # 지금 판의 레벨(= 맵 높이)
var base_score := 0     # 이 레벨을 시작할 때의 점수. 죽으면 여기서 다시 시작한다
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
	add_child(hud)
	hud.add_child(controller)
	hud.add_child(picker)
	controller.steer_pressed.connect(_on_steer)
	controller.turn_pressed.connect(_on_turn)
	hud.turn_pressed.connect(_on_turn)
	picker.skin_changed.connect(_on_skin_changed)
	picker.set_index(Skins.worm_index(SaveData.load_skin()))
	worm_view.apply_skin(picker.index)
	new_game()

func new_game() -> void:
	game = Game.new(randi(), perf_requested(), level)
	game.score = base_score
	game.ate.connect(_on_ate)
	rig.position = Vector3(Tuning.BOX * 0.5, game.height * 0.5, Tuning.BOX * 0.5)  # 시점은 그대로, 상자 중심을 본다
	controller.vertical = game.height > 1
	hud.set_level(game.level)
	hud.show_clear(false)
	field_view.setup(game)
	worm_view.setup(game)
	_dead_time = 0.0
	_was_dead = false
	hud.show_restart(false)

# 웹은 주소 끝 ?perf, 데스크톱은 실행 인자 --perf 면 500마디로 시작한다(성능 확인용).
static func perf_requested() -> bool:
	if OS.get_cmdline_user_args().has("--perf"):
		return true
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.search", true)).contains("perf")
	return false

func _process(delta: float) -> void:
	game.paused = rig.is_turning()
	game.advance(delta)
	hud.set_score(game.score)
	picker.visible = game.state == Game.State.WAITING  # 시작 전에만 지렁이를 고른다
	if game.state == Game.State.DEAD:
		if not _was_dead:
			_was_dead = true
			rig.shake()
		_dead_time += delta
		hud.show_restart(_dead_time >= Tuning.DEATH_DELAY)
	elif game.state == Game.State.CLEARED:
		_dead_time += delta
		hud.show_clear(_dead_time >= Tuning.CLEAR_DELAY)

func _on_skin_changed(index: int) -> void:
	worm_view.apply_skin(index)
	SaveData.save_skin(Skins.WORMS[index]["id"])

# 벌레를 먹으면 먹은 칸 위에 점수가 떠오른다. 색은 벌레 종류 색이다.
func _on_ate(kind: int, points: int, cell: Vector3i) -> void:
	var at := rig.camera.unproject_position(WormPath.center(cell)) - Vector2(0, 40)
	hud.pop("+%d" % points, at, Skins.BUGS[kind]["color"])

func _on_steer(steer: int) -> void:
	if game.state == Game.State.DEAD or game.state == Game.State.CLEARED:
		_restart_if_ready()
		return
	game.press(steer)

func _on_turn(dir: int) -> void:
	if game.state != Game.State.DEAD:
		rig.turn(dir)

func _unhandled_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t != null and t.pressed and (game.state == Game.State.DEAD or game.state == Game.State.CLEARED):
		_restart_if_ready()

func _restart_if_ready() -> void:
	if game.state == Game.State.CLEARED:
		if _dead_time >= Tuning.CLEAR_DELAY:
			base_score = game.score  # 클리어한 점수는 이어진다
			level = mini(level + 1, Tuning.LEVEL_MAX)
			new_game()
	elif _dead_time >= Tuning.DEATH_DELAY:
		new_game()
