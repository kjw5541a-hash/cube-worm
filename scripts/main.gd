extends Node3D

# 게임 화면: 게임 진행, 입력 연결, 죽은 뒤 다시 시작.
# 타이틀·일시정지·게임오버 화면은 6단계에서 붙인다.

var game: Game
var rig := CameraRig.new()
var field_view := FieldView.new()
var worm_view := WormView.new()
var hud := Hud.new()
var controller := Controller.new()
var _dead_time := 0.0

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
	controller.rig = rig
	hud.add_child(controller)
	controller.direction_pressed.connect(_on_direction)
	controller.turn_pressed.connect(_on_turn)
	hud.turn_pressed.connect(_on_turn)
	new_game()

func new_game() -> void:
	game = Game.new(randi(), perf_requested())
	field_view.setup(game)
	worm_view.setup(game)
	_dead_time = 0.0
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
	if game.state == Game.State.DEAD:
		_dead_time += delta
		hud.show_restart(_dead_time >= Tuning.DEATH_DELAY)

func _on_direction(screen_dir: int) -> void:
	if game.state == Game.State.DEAD:
		_restart_if_ready()
		return
	game.press(rig.world_dir(screen_dir))

func _on_turn(dir: int) -> void:
	if game.state != Game.State.DEAD:
		rig.turn(dir)

func _unhandled_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t != null and t.pressed and game.state == Game.State.DEAD:
		_restart_if_ready()

func _restart_if_ready() -> void:
	if _dead_time >= Tuning.DEATH_DELAY:
		new_game()
