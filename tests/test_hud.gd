extends SceneTree

func _initialize() -> void:
	await _test_pop_rises_and_disappears()
	print("test_hud: OK")
	quit()

# 먹은 점수 "+N" 은 위로 떠오르며 사라지고, 다 사라지면 스스로 지워진다.
func _test_pop_rises_and_disappears() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	var label := hud.pop("+3", Vector2(360, 400), Color.RED)
	assert(label.text == "+3" and label.get_theme_color("font_color") == Color.RED, "점수 글자와 색")
	var y0 := label.position.y
	await create_timer(Tuning.POP_TIME * 0.5).timeout
	assert(label.position.y < y0 - 10.0, "위로 떠오른다: %f → %f" % [y0, label.position.y])
	await create_timer(Tuning.POP_TIME * 0.5 + 0.3).timeout
	assert(not is_instance_valid(label), "다 떠오르면 사라진다")
	hud.queue_free()
