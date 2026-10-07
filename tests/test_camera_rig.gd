extends SceneTree

const B := Tuning.BOX
const CENTER := Vector3(B, B, B) * 0.5

func _initialize() -> void:
	await _test_buttons_match_real_camera()
	_test_vertical_and_opposites()
	await _test_turn_is_clockwise_and_accumulates()
	await _test_box_fits_screen()
	await _test_same_scale_on_other_screens()
	print("test_camera_rig: OK")
	quit()

# 헤드리스 창은 64×64 로 고정이라 크기를 바꿀 수 없다. 폰과 같은 720×1280 서브뷰포트 안에서 본다.
func _rig(size := Vector2i(720, 1280)) -> CameraRig:
	var view := SubViewport.new()
	view.size = size
	root.add_child(view)
	var r := CameraRig.new()
	r.position = CENTER
	view.add_child(r)
	r.camera.make_current()
	return r

# 실제 Camera3D 로 투영한 화면 각도와 버튼 각도를 대조한다. 표끼리의 관계만 보면 표 전체가
# 뒤집혀도 통과하므로, 여기서는 카메라가 그린 그대로를 본다.
func _test_buttons_match_real_camera() -> void:
	var r := _rig()
	for step in 4:
		r.yaw_step = step
		r.rotation_degrees.y = CameraRig.YAW_BASE_DEG + 90.0 * step
		await process_frame
		var o := r.camera.unproject_position(CENTER)
		for i in 6:
			var s := r.camera.unproject_position(CENTER + Vector3(r.world_dir(i))) - o
			var ang := rad_to_deg(atan2(-s.y, s.x))
			var want := 30.0 + 60.0 * i
			assert(absf(angle_difference(deg_to_rad(ang), deg_to_rad(want))) < deg_to_rad(1.0),
				"시점 %d 버튼 %d: 화면 각도 %f, 기대 %f" % [step, i, ang, want])
	r.get_parent().queue_free()

func _test_vertical_and_opposites() -> void:
	for step in 4:
		var yaw := CameraRig.YAW_BASE_DEG + 90.0 * step
		assert(CameraRig.axis_for(1, yaw) == Vector3i(0, 1, 0), "▲ 는 언제나 위")
		assert(CameraRig.axis_for(4, yaw) == Vector3i(0, -1, 0), "▼ 는 언제나 아래")
		var seen := {}
		for i in 6:
			var a := CameraRig.axis_for(i, yaw)
			assert(a == -CameraRig.axis_for((i + 3) % 6, yaw), "마주 보는 버튼은 반대 방향")
			seen[a] = true
		assert(seen.size() == 6, "버튼 6개가 축 6개에 하나씩")

func _test_turn_is_clockwise_and_accumulates() -> void:
	var r := _rig()
	var ne := r.world_dir(0)
	r.turn(1)
	assert(r.yaw_step == 1, "회전 단계는 누르는 즉시 바뀐다")
	assert(r.is_turning(), "트윈이 도는 중")
	assert(r.world_dir(5) == ne, "시계 방향: ↗ 에 있던 축이 ↘ 로 간다")
	for d in [1, 1, -1, 1]:
		r.turn(d)
	await create_timer(Tuning.TURN_TIME + 0.2).timeout
	assert(not r.is_turning())
	assert(r.yaw_step == 3, "+1 +1 +1 -1 +1 이면 3단계: %d" % r.yaw_step)
	var want := CameraRig.YAW_BASE_DEG + 90.0 * r.yaw_step
	assert(absf(angle_difference(deg_to_rad(r.current_yaw()), deg_to_rad(want))) < 0.001,
		"연달아 돌려도 화면 각도가 단계와 같아야 한다: %f" % r.current_yaw())
	r.get_parent().queue_free()

# 상자 꼭짓점 8개가 화면 폭 안에 있고, 상자 중심이 정한 높이에 온다.
func _test_box_fits_screen() -> void:
	var r := _rig()
	await process_frame
	var c := r.camera.unproject_position(CENTER)
	assert(absf(c.x - 360.0) < 1.0 and absf(c.y - CameraRig.BOX_CENTER_Y_PX) < 1.0, "상자 중심 위치: %s" % c)
	for x in [0, B]:
		for y in [0, B]:
			for z in [0, B]:
				var p := r.camera.unproject_position(Vector3(x, y, z))
				assert(p.x > 10 and p.x < 710 and p.y > 60 and p.y < 900, "상자 꼭짓점이 화면 밖이거나 컨트롤러 자리: %s" % p)
	r.get_parent().queue_free()

# 더 긴 폰과 가로로 넓은 데스크톱 창에서도 상자는 같은 픽셀 크기로, 위에서 같은 높이에 놓인다.
func _test_same_scale_on_other_screens() -> void:
	var widths := []
	for size in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(2276, 1280)]:
		var r := _rig(size)
		await process_frame
		var c := r.camera.unproject_position(CENTER)
		assert(absf(c.x - size.x * 0.5) < 1.0 and absf(c.y - CameraRig.BOX_CENTER_Y_PX) < 1.0, "%s 화면에서 상자 중심: %s" % [size, c])
		widths.append(r.camera.unproject_position(Vector3(B, 0, 0)).x - r.camera.unproject_position(Vector3(0, 0, B)).x)
		r.get_parent().queue_free()
	assert(absf(widths[1] - widths[0]) < 1.0 and absf(widths[2] - widths[0]) < 1.0, "화면 비율에 따라 상자 크기가 달라졌다: %s" % [widths])
