class_name SaveData
extends RefCounted

# 기기에 저장하는 값(서버 없음). 테스트가 실제 사용자 기록을 지우지 않도록 경로를 바꿔 끼울 수 있게 둔다.
static var PATH := "user://cube_worm_save.cfg"
const SECTION := "progress"
const SKIN_KEY := "worm_skin"

# 저장된 지렁이 스킨 id. 없거나 깨졌으면 "".
static func load_skin() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return ""
	var v: Variant = cfg.get_value(SECTION, SKIN_KEY, "")
	# 손으로 고친 파일에 배열이나 숫자가 들어 있어도 죽지 않는다.
	return v if typeof(v) == TYPE_STRING else ""

static func save_skin(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 실패해도 빈 설정으로 이어간다. 읽어서 덮어쓰므로 다른 값(최고 기록 등)은 지워지지 않는다.
	cfg.set_value(SECTION, SKIN_KEY, id)
	cfg.save(PATH)
