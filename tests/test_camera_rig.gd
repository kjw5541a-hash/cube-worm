extends SceneTree

const B := Tuning.BOX
const CENTER := Vector3(B, B, B) * 0.5

func _initialize() -> void:
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

# 화면에 비친 월드 방향 v 의 각도(라디안, 화면 오른쪽이 0, 반시계). 실제 카메라가 그린 그대로 잰다.
func _screen_angle(r: CameraRig, v: Vector3) -> float:
	var s := r.camera.unproject_position(CENTER + v) - r.camera.unproject_position(CENTER)
	return atan2(-s.y, s.x)

# 맵 회전은 위에서 본 월드가 시계 방향으로 도는 것이다: 화면 ↗(30°)에 보이던 수평 축이 ↘(-30°)로 간다.
func _test_turn_is_clockwise_and_accumulates() -> void:
	var r := _rig()
	await process_frame
	var ne := Vector3.ZERO  # 처음 시점에서 화면 ↗ 에 보이는 수평 축
	for a in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		if absf(angle_difference(_screen_angle(r, a), deg_to_rad(30.0))) < deg_to_rad(1.0):
			ne = a
	assert(ne != Vector3.ZERO, "처음 시점에 ↗ 로 보이는 수평 축이 있어야 한다")
	r.turn(1)
	assert(r.yaw_step == 1, "회전 단계는 누르는 즉시 바뀐다")
	assert(r.is_turning(), "트윈이 도는 중")
	await create_timer(Tuning.TURN_TIME + 0.2).timeout
	assert(absf(angle_difference(_screen_angle(r, ne), deg_to_rad(-30.0))) < deg_to_rad(1.0),
		"시계 방향: ↗ 에 보이던 축이 ↘ 로 간다 (화면 각도 %f°)" % rad_to_deg(_screen_angle(r, ne)))
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
