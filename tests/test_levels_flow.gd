extends SceneTree

# 판 흐름: 클리어하면 다음 레벨(점수 이어짐), 죽으면 같은 레벨(점수는 판 시작 값), 레벨은 LEVEL_MAX 에서 멈춘다.
func _initialize() -> void:
	SaveData.PATH = "user://test_levels_flow.cfg"
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(main)
	await process_frame
	main.title.image.tapped.emit()  # 시작 그림을 넘긴다(방식 선택이 열린다)
	main.title.buttons[Title.Mode.CLASSIC].chosen.emit()  # 기존 방식
	assert(main.level == 1 and main.game.height == 1 and not main.controller.vertical, "첫 판은 1층, 위아래 버튼 꺼짐")
	assert(is_equal_approx(main.rig.position.y, 0.5), "카메라는 1층 가운데를 본다")

	_clear(main, 1)
	await create_timer(Tuning.CLEAR_DELAY + 0.1).timeout
	assert(main.hud.clear_label.visible, "클리어 안내가 뜬다")
	var score: int = main.game.score
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(main.level == 2 and main.game.height == 2 and main.controller.vertical, "다음 레벨은 2층")
	assert(main.game.score == score and main.base_score == score, "점수가 이어진다")

	main.game.score += 5
	main.game.state = Game.State.DEAD
	main._dead_time = Tuning.DEATH_DELAY + 1.0
	main._restart_if_ready()
	assert(main.level == 2 and main.game.score == score, "죽으면 같은 레벨, 점수는 판 시작 값")

	for i in 10:
		_clear(main, main.level)
		main._dead_time = 10.0
		main._restart_if_ready()
	assert(main.level == Tuning.LEVEL_MAX and main.game.height == Tuning.LEVEL_MAX, "레벨은 %d 에서 멈춘다" % Tuning.LEVEL_MAX)
	print("test_levels_flow: OK")
	quit()

func _clear(main: Node, _lv: int) -> void:
	var g: Game = main.game
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.state = Game.State.CLEARED
	g.score += 3
	g.cleared.emit()
