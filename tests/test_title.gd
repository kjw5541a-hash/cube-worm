extends SceneTree

# 시작 화면: 그림이 화면을 채우고, 터치하면 한 번 신호를 내며 사라진다.
func _initialize() -> void:
	var title := Title.new()
	root.add_child(title)
	assert(title.visible and title.image.texture != null, "처음에는 그림이 보인다")
	assert(title.image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "그림이 화면을 채운다(비율 유지)")
	var got := [0]
	title.started.connect(func() -> void: got[0] += 1)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	title.image._gui_input(release)
	assert(title.visible and got[0] == 0, "손가락을 뗄 때는 시작하지 않는다")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	title.image._gui_input(tap)
	assert(not title.visible and got[0] == 1, "터치하면 사라지고 시작 신호가 한 번 온다")
	title.image._gui_input(tap)
	assert(got[0] == 1, "이미 시작했으면 다시 신호를 내지 않는다")
	title.show_again()
	assert(title.visible, "다시 보일 수 있다")
	print("test_title: OK")
	quit()
