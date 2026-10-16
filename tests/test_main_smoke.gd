extends SceneTree

func _screen() -> Node:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(main)
	return main

# 실제 게임 화면을 띄워 몇 초 돌린다. 연결이 끊긴 곳이 있으면 여기서 SCRIPT ERROR 가 난다.
func _initialize() -> void:
	# 사용자가 고른 스킨을 건드리지 않도록 테스트 전용 저장 파일을 쓴다.
	SaveData.PATH = "user://test_main_smoke.cfg"
	var abs_path := ProjectSettings.globalize_path(SaveData.PATH)
	DirAccess.remove_absolute(abs_path)
	var main := _screen()
	await process_frame
	var game: Game = main.game
	assert(main.sfx != null and not main.sfx.muted and not main.sfx.music_active, "처음에는 소리가 켜져 있고, 첫 입력 전에는 BGM 이 조용하다")
	assert(game.state == Game.State.WAITING, "처음에는 출발을 기다린다")
	assert(main.picker.visible and main.worm_view.skin_index == 0, "대기 중에는 지렁이 선택 줄이 보이고 기본 스킨이다")
	# 시작 화면이 먼저 보이고, 그 뒤에서는 입력이 게임에 닿지 않는다. 터치하면 사라지고 BGM 이 시작된다.
	assert(main.title.visible, "처음에는 시작 화면이 보인다")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	main.controller.turn_pressed.emit(1)
	assert(game.state == Game.State.WAITING and main.rig.yaw_step == 0 and main.sfx.plays == 0, "시작 화면 뒤에서는 조향·회전 입력이 먹히지 않는다")
	var title_tap := InputEventScreenTouch.new()
	title_tap.pressed = true
	main.title.image._gui_input(title_tap)
	assert(main.title.visible and main.title.in_menu and game.state == Game.State.WAITING, "첫 터치로 방식 선택이 열린다(아직 시작 화면 위)")
	assert(main.sfx.music_active, "시작 화면을 터치하면 BGM 이 시작된다(웹은 이 터치에서 소리가 풀린다)")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(game.state == Game.State.WAITING, "방식 선택 중에도 입력이 게임에 닿지 않는다")
	main.title.buttons[Title.Mode.CLASSIC]._gui_input(title_tap)
	assert(not main.title.visible and main.game != game and main.game.state == Game.State.WAITING, "기존 방식을 고르면 새 판이 출발을 기다린다")
	game = main.game
	main.picker.change(1)
	assert(main.worm_view.skin_index == 1 and SaveData.load_skin() == Skins.WORMS[1]["id"], "고른 스킨이 지렁이에 적용되고 저장된다")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)  # 출발 전 첫 입력은 바로 꺾임: -X 를 보는 지렁이의 왼쪽 = +Z
	assert(main.sfx.last_id == "start" and main.sfx.music_active, "출발 입력에서 시작 소리가 나고 BGM 이 시작된다")
	assert(game.state == Game.State.RUNNING, "조향 입력으로 출발한다")
	assert(game.worm.head_exit == Vector3i(0, 0, 1), "컨트롤러의 ◀ 가 게임까지 이어져 왼쪽(+Z)으로 꺾는다: %s" % game.worm.head_exit)
	await process_frame
	assert(not main.picker.visible, "출발하면 선택 줄이 사라진다")
	await create_timer(0.5).timeout
	assert(game.worm.head() != Tuning.START_HEAD, "0.5초면 한 칸 넘게 간다")
	assert(main.worm_view.body.multimesh.visible_instance_count == game.worm.length() - 1, "몸 마디 수 = 길이 - 1")
	var tap_box := InputEventScreenTouch.new()
	tap_box.pressed = true
	tap_box.position = Vector2(360, 480)
	main._unhandled_input(tap_box)
	assert(main.game == game and game.state == Game.State.RUNNING, "플레이 중 상자를 탭해도 아무 일 없다")

	# 벌레를 먹으면 먹은 칸 위에 점수가 떠오른다.
	main._on_ate(1, Tuning.BUG_SCORES[1], Vector3i(3, 4, 4))
	var pops: Array = main.hud.get_children().filter(func(n: Node) -> bool: return n is Label and n.text == "+%d" % Tuning.BUG_SCORES[1])
	assert(pops.size() == 1, "먹은 점수 +N 이 뜬다")
	assert(main.sfx.last_id == "eat_1", "먹으면 그 종류의 먹는 소리가 난다")

	# HUD 의 회전 버튼(오른쪽 = 시계)을 손가락으로 누른다.
	var turn_buttons: Array = main.hud.get_children().filter(func(n: Node) -> bool: return n is Hud.TurnButton)
	assert(turn_buttons.size() == 2, "회전 버튼 2개")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	var right_button: Hud.TurnButton = turn_buttons.filter(func(b: Hud.TurnButton) -> bool: return b.dir == 1)[0]
	right_button._gui_input(tap)
	assert(main.rig.yaw_step == 1, "회전 버튼으로 맵이 돈다")
	assert(main.sfx.last_id == "rotate", "회전하면 회전 소리가 난다")
	var plays_before: int = main.sfx.plays
	main.hud.sound_button._gui_input(tap)  # 위에서 만든 터치 이벤트(pressed = true)를 다시 쓴다
	assert(main.sfx.muted and not main.sfx.music_active and SaveData.load_muted(), "소리 버튼을 누르면 꺼지고 저장된다")
	main.controller.steer_pressed.emit(Worm.Steer.RIGHT)
	assert(main.sfx.plays == plays_before, "꺼진 동안에는 조향 소리도 나지 않는다")
	main.hud.sound_button._gui_input(tap)
	assert(not main.sfx.muted and main.sfx.music_active and not SaveData.load_muted(), "다시 누르면 켜지고 BGM 도 돌아온다")
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
	assert(main.rig.is_shaking(), "죽으면 화면이 흔들린다")
	assert(main.sfx.last_id == "die" and main.sfx.music.volume_db < Sfx.MUSIC_DB, "죽으면 쿵 소리가 나고 BGM 이 작아진다")
	var yaw: int = main.rig.yaw_step
	main.controller.turn_pressed.emit(1)
	assert(main.rig.yaw_step == yaw, "죽은 뒤에는 맵이 돌지 않는다")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(main.game == game, "죽은 직후에는 다시 시작하지 않는다")
	await create_timer(Tuning.DEATH_DELAY + 0.1).timeout
	assert(main.hud.restart_label.visible, "잠시 뒤 다시 시작 안내")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(main.game != game and main.game.state == Game.State.WAITING, "새 판이 시작된다")
	assert(is_equal_approx(main.sfx.music.volume_db, Sfx.MUSIC_DB), "새 판에서는 BGM 이 원래 크기로 돌아온다")
	await process_frame
	await process_frame  # 선택 줄은 _process 에서 갱신되므로 한 프레임 더 기다린다
	assert(main.picker.visible and main.worm_view.skin_index == 1, "새 판도 대기 중이라 선택 줄이 보이고, 고른 스킨이 이어진다")

	# 저장된 스킨은 다음에 화면을 열 때도 이어진다.
	SaveData.save_skin(Skins.WORMS[2]["id"])
	SaveData.save_muted(true)
	var quiet := _screen()
	await process_frame
	assert(quiet.sfx.muted and quiet.hud.sound_button.muted, "꺼진 채 저장하면 다음에도 꺼진 채로 시작한다")
	quiet.title.image._gui_input(title_tap)  # 시작 화면을 넘긴다(꺼진 상태라 BGM 이 시작되지 않아야 한다)
	quiet.title.buttons[Title.Mode.CLASSIC]._gui_input(title_tap)
	quiet.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(not quiet.sfx.music_active and quiet.sfx.plays == 0, "꺼진 채로 시작하면 첫 입력에도 소리가 나지 않는다")
	SaveData.save_muted(false)
	var again := _screen()
	await process_frame
	assert(again.worm_view.skin_index == 2 and again.picker.index == 2, "저장된 스킨으로 시작한다")
	DirAccess.remove_absolute(abs_path)
	print("test_main_smoke: OK")
	quit()
