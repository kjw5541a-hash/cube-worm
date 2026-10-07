extends SceneTree

# 실제 게임 화면을 띄워 몇 초 돌린다. 연결이 끊긴 곳이 있으면 여기서 SCRIPT ERROR 가 난다.
func _initialize() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(main)
	await process_frame
	var game: Game = main.game
	assert(game.state == Game.State.WAITING, "처음에는 출발을 기다린다")
	var ahead := -1  # 머리가 보는 쪽을 가리키는 화면 방향
	for i in 6:
		if main.rig.world_dir(i) == Tuning.START_DIR:
			ahead = i
	main.controller.direction_pressed.emit(ahead)
	assert(game.state == Game.State.RUNNING, "방향 입력으로 출발한다")
	await create_timer(0.5).timeout
	assert(game.worm.head() != Tuning.START_HEAD, "0.5초면 한 칸 넘게 간다")
	assert(main.worm_view.body.multimesh.visible_instance_count == game.worm.length() - 1, "몸 마디 수 = 길이 - 1")
	var tap_box := InputEventScreenTouch.new()
	tap_box.pressed = true
	tap_box.position = Vector2(360, 480)
	main._unhandled_input(tap_box)
	assert(main.game == game and game.state == Game.State.RUNNING, "플레이 중 상자를 탭해도 아무 일 없다")

	# HUD 의 회전 버튼(오른쪽 = 시계)을 손가락으로 누른다.
	var turn_buttons: Array = main.hud.get_children().filter(func(n: Node) -> bool: return n is Hud.TurnButton)
	assert(turn_buttons.size() == 2, "회전 버튼 2개")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	var right_button: Hud.TurnButton = turn_buttons.filter(func(b: Hud.TurnButton) -> bool: return b.dir == 1)[0]
	right_button._gui_input(tap)
	assert(main.rig.yaw_step == 1, "회전 버튼으로 맵이 돈다")
	await process_frame
	var a := game.alpha
	var head := game.worm.head()
	await create_timer(0.1).timeout
	assert(game.alpha == a and game.worm.head() == head, "맵이 도는 동안 게임이 멈춘다")
	await create_timer(Tuning.TURN_TIME + 0.1).timeout
	assert(not main.rig.is_turning())

	# 그대로 두면 벽에 부딪혀 죽는다.
	for i in 100:
		if game.state == Game.State.DEAD:
			break
		await create_timer(0.1).timeout
	assert(game.state == Game.State.DEAD, "곧장 가면 벽에 부딪힌다")
	var yaw: int = main.rig.yaw_step
	main.controller.turn_pressed.emit(1)
	assert(main.rig.yaw_step == yaw, "죽은 뒤에는 맵이 돌지 않는다")
	main.controller.direction_pressed.emit(0)
	assert(main.game == game, "죽은 직후에는 다시 시작하지 않는다")
	await create_timer(Tuning.DEATH_DELAY + 0.1).timeout
	assert(main.hud.restart_label.visible, "잠시 뒤 다시 시작 안내")
	main.controller.direction_pressed.emit(0)
	assert(main.game != game and main.game.state == Game.State.WAITING, "새 판이 시작된다")
	print("test_main_smoke: OK")
	quit()
