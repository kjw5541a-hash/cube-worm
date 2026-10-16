class_name SaveData
extends RefCounted

# 기기에 저장하는 값(서버 없음). 테스트가 실제 사용자 기록을 지우지 않도록 경로를 바꿔 끼울 수 있게 둔다.
static var PATH := "user://cube_worm_save.cfg"
const SECTION := "progress"
const SKIN_KEY := "worm_skin"
const MUTE_KEY := "sound_muted"
const SCORE_KEY := "best_score"
const TIME_KEY := "best_time_ms"
const LAYOUT_KEY := "best_time_layout"

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

# 소리를 껐는지. 없거나 깨졌거나 불리언이 아니면 켜짐(false).
static func load_muted() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	var v: Variant = cfg.get_value(SECTION, MUTE_KEY, false)
	return v if typeof(v) == TYPE_BOOL else false

static func save_muted(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 읽어서 덮어쓰므로 스킨 같은 다른 값은 지워지지 않는다
	cfg.set_value(SECTION, MUTE_KEY, on)
	cfg.save(PATH)

# 설정 cfg 에서 key 의 정수값. 없거나 정수가 아니거나 1 미만이면 0(기록 없음).
static func _positive_int(cfg: ConfigFile, key: String) -> int:
	var v: Variant = cfg.get_value(SECTION, key, 0)
	return v if typeof(v) == TYPE_INT and v > 0 else 0

# 기존 방식 최고 점수. 기록 없음 = 0.
static func load_best_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return _positive_int(cfg, SCORE_KEY)

# score 가 저장된 최고보다 높을 때만 저장한다(나쁜 값이 와도 기록은 내려가지 않는다). 저장했으면 true.
static func save_best_score(score: int) -> bool:
	if score <= load_best_score():
		return false
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 읽어서 덮어쓰므로 스킨·소리 같은 다른 값은 지워지지 않는다
	cfg.set_value(SECTION, SCORE_KEY, score)
	cfg.save(PATH)
	return true

# 타임어택 최고 시간(밀리초). 저장된 판 배치 이름이 지금 layout 과 다르면 다른 판의 기록이라 0(기록 없음).
static func load_best_time_ms(layout: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	var stored: Variant = cfg.get_value(SECTION, LAYOUT_KEY, "")
	if typeof(stored) != TYPE_STRING or stored != layout:
		return 0
	return _positive_int(cfg, TIME_KEY)

# ms 가 같은 배치의 저장된 최고보다 빠를 때(또는 기록이 없거나 배치가 다를 때)만 저장한다. 저장했으면 true.
static func save_best_time_ms(ms: int, layout: String) -> bool:
	if ms <= 0:
		return false
	var best := load_best_time_ms(layout)
	if best > 0 and ms >= best:
		return false
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(SECTION, TIME_KEY, ms)
	cfg.set_value(SECTION, LAYOUT_KEY, layout)
	cfg.save(PATH)
	return true
