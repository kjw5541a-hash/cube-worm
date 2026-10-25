extends SceneTree

func _initialize() -> void:
	_test_worm_skins()
	_test_bug_kinds()
	_test_gold_bug()
	_test_worm_index()
	print("test_skins: OK")
	quit()

func _test_worm_skins() -> void:
	assert(Skins.WORMS.size() == 3, "지렁이 스킨은 3종")
	var ids := {}
	for s in Skins.WORMS:
		assert(not ids.has(s["id"]), "id 가 겹친다: %s" % s["id"])
		ids[s["id"]] = true
		assert(s["name"] != "", "이름이 있어야 한다: %s" % s["id"])
		assert(ResourceLoader.exists(s["segment"]) and ResourceLoader.exists(s["head"]), "에셋 파일이 있어야 한다: %s" % s["id"])

func _test_bug_kinds() -> void:
	assert(Skins.BUGS.size() == Tuning.BUG_COUNT, "벌레 종류 수 = BUG_COUNT")
	assert(Tuning.BUG_SCORES.size() == Tuning.BUG_COUNT, "종류마다 점수가 있다")
	var colors := {}
	for b in Skins.BUGS:
		assert(b["name"] != "" and ResourceLoader.exists(b["model"]), "벌레 이름과 에셋: %s" % b["id"])
		colors[b["color"]] = true
	assert(colors.size() == Skins.BUGS.size(), "종류마다 색이 달라야 구별된다")

# 황금 벌레는 일반 종류 목록에 없고, 번호는 그다음(Game.GOLD)이며, 색이 일반 벌레 셋과 다르다.
func _test_gold_bug() -> void:
	assert(Game.GOLD == Skins.BUGS.size(), "황금 벌레 번호는 일반 종류 다음이다")
	assert(Skins.GOLD["name"] != "" and ResourceLoader.exists(Skins.GOLD["model"]), "황금 벌레 이름과 에셋")
	for b in Skins.BUGS:
		assert(b["color"] != Skins.GOLD["color"], "황금 벌레 색이 일반 벌레와 겹친다: %s" % b["id"])

func _test_worm_index() -> void:
	for i in Skins.WORMS.size():
		assert(Skins.worm_index(Skins.WORMS[i]["id"]) == i, "id 로 번호를 찾는다")
	assert(Skins.worm_index("없는 스킨") == 0 and Skins.worm_index("") == 0, "없는 id 는 기본 스킨")
