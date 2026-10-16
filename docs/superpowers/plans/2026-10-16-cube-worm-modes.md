# 큐브 지렁이 게임 방식 선택과 최고 기록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시작 그림 터치 뒤 방식 선택(기존 방식 / 타임어택)을 넣고, 두 방식의 최고 기록(점수 / 시간)을 업데이트해도 유지되게 저장한다.

**Architecture:** `Game` 에는 스톱워치(`elapsed`)만 더하고 방식 구분은 `Main` 의 `mode` 값으로 한다. 기록 판정·표시 형식은 순수 함수 `Records`, 저장은 `SaveData`(기존 파일에 키만 추가), 화면은 `Title`(TAP → MENU)과 `Hud`(타이머·최고·남은 벌레·메뉴 버튼)가 맡는다. 타임어택은 레벨 8, 고정 시드 1 의 판이다.

**Tech Stack:** Godot 4.7.2 GDScript(헤드리스 테스트 `./run_tests.sh`), Python 3(패치 스크립트), Chrome 모바일 에뮬레이션(웹 확인), GitHub Pages 배포.

**Spec:** `docs/superpowers/specs/2026-10-16-cube-worm-modes-design.md`

## Global Constraints

- 답변·주석·커밋 메시지는 한국어. 커밋 메시지 끝에 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- 작업 브랜치는 `game-modes`(스펙 커밋이 이미 있다). 푸시하면 Pages 가 라이브를 덮어쓴다 — 푸시 전에 전체 테스트가 `전체 통과` 여야 한다. `main` 병합은 사용자가 말할 때만 한다.
- **전체 테스트 명령(이하 `전체 테스트`):** `cd ~/games/cube-worm && ./run_tests.sh > .superpowers/t.txt 2>&1; grep -E "SCRIPT ERROR|FAIL|TIMEOUT" .superpowers/t.txt | head -5; tail -1 .superpowers/t.txt`. 통과하면 `grep` 은 아무것도 찍지 않고 마지막 줄이 `전체 통과` 다. 특정 테스트는 `grep -x "<파일명>: OK" .superpowers/t.txt` 로 본다. 파일당 제한은 20초이고 CI(`.github/workflows/deploy.yml`)도 같은 `./run_tests.sh` 를 쓴다. 테스트가 실패하면 배포가 막힌다.
- 저장 파일은 `user://cube_worm_save.cfg`, 칸은 `progress`. 키 이름은 `worm_skin`, `sound_muted`, `best_score`, `best_time_ms`, `best_time_layout`. 프로젝트 이름은 `큐브 지렁이`(`application/config/name`). **이 이름들을 바꾸지 않는다** — 바꾸면 이미 저장된 기록이 사라진다.
- 방식 값은 `Title.Mode`: `CLASSIC` = 0, `TIME_ATTACK` = 1. 메서드 인자는 `int` 로 받는다.
- 타임어택 판은 `Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)`, `TIME_LEVEL` = 8, `TIME_SEED` = 1. 판 배치 이름은 `"<TIME_LEVEL>-<TIME_SEED>-<TIME_LAYOUT_VERSION>"`(지금 `8-1-1`).
- 확인용 주소(`?level=N`(N≠1), `?perf`)로 시작한 기존 방식 판은 기록을 읽기만 하고 쓰지 않는다. 타임어택은 이 주소 값을 무시한다.
- 화면 문구(정확히): `기존 방식`, `타임어택`, `최고 점수 N`, `최고 기록 42.31초`, `기록 없음`, `메뉴`, `남은 벌레 N`, `최고 N`, `최고 --`, `최고 42.31초`, `신기록!`, `첫 기록!`, `탭하면 다시 도전`. 문자열의 글자는 프로젝트 폰트(NotoSansKR-hangul)에 있어야 하고 `tests/test_font.gd` 가 검사한다(이 계획의 문구는 모두 확인했다).
- Godot 내장 클래스 이름(`Image`, `MenuButton` 등)과 같은 이름의 내부 클래스를 만들지 않는다(파스 오류).
- 새 `class_name`·스크립트가 생기면 `./run_tests.sh` 가 임포트로 `.godot/` 캐시와 `.uid` 파일을 갱신한다. 새 파일의 `.uid` 도 같이 커밋한다. `.superpowers/` 는 커밋하지 않는다(추적 안 되는 작업 폴더).
- 소리는 지금 것만 쓴다(신기록 전용 효과음 없음). 레벨 선택, 순위표, 기록 초기화, 게임오버·일시정지 화면, 노치 대응은 하지 않는다.
- 코드 블록의 들여쓰기는 탭이다(GDScript). 파이썬 패치 스크립트는 앵커 문자열이 정확히 한 번 있어야 하고, 아니면 `AssertionError` 로 멈춘다(그러면 파일의 현재 모양을 읽고 앵커를 맞춘다).

## Review Focus

스펙이 암시하지만 작업별 테스트가 따로 겨누지 않을 수 있는 가장 위험한 다섯 가지. 각각 아래 작업에 테스트를 넣었다.

1. 저장 파일의 기록 키가 깨졌거나 엉뚱한 형식·배치 이름이어도 앱이 죽지 않고 "기록 없음"으로 읽히고, 그 위에 다시 저장할 수 있다 → Task 1 테스트(`_test_best_score`, `_test_best_time`).
2. 맵을 돌리는 동안과 방식 선택 화면이 떠 있는 동안 타이머가 흐르지 않는다 → Task 2(`paused`), Task 4(`Main` 의 회전·선택 화면 정지), Task 5(메뉴 버튼 뒤 정지).
3. 타임어택에서 죽은 뒤 다시 도전하면 같은 배치, 타이머 0, 기록 불변이다. 같은 시간·느린 시간은 기록을 바꾸지 않는다 → Task 4(`_test_time_attack_death_retries_same_layout`, `_test_time_attack_clear_records`).
4. 기존 방식 점수가 최고를 넘는 순간 저장되고, 죽어서 점수가 돌아가도 최고는 내려가지 않으며, 기록이 없던 첫 플레이에서는 `신기록!` 이 뜨지 않는다 → Task 4(`_test_classic_best_score`, `_test_classic_first_record_is_quiet`).
5. 방식 선택 화면으로 돌아오면 최신 기록이 보이고 같은 방식을 다시 골라도 항상 새 판이다. 옛 형식 저장 파일(스킨·소리만)을 읽고 기록을 써도 스킨·소리가 남는다 → Task 5(`_test_menu_flow`), Task 1(`_test_old_format_file_keeps_working`).

---

### Task 1: 기록 판정(Records)과 기록 저장(SaveData)

**Files:**
- Create: `scripts/records.gd`
- Create: `tests/test_records.gd`
- Modify: `scripts/save_data.gd`
- Modify: `tests/test_save_data.gd`
- Add(정리): `assets/audio/*.ogg.import` 12개(소리 작업 때 빠뜨린 임포트 파일. 다른 에셋은 이미 올려 두고 있다)

**Interfaces:**
- Produces(뒤 작업이 쓴다):
  - `Records.Verdict { NONE, FIRST, NEW_BEST }`
  - `Records.to_ms(seconds: float) -> int`, `Records.format_time(ms: int, decimals: int) -> String`
  - `Records.judge_time(ms: int, best_ms: int) -> int`(`Verdict`), `Records.judge_score(score: int, best: int) -> int`(`Verdict`)
  - `Records.time_result_text(ms: int, verdict: int, best_ms: int) -> String`
  - `SaveData.SCORE_KEY`, `TIME_KEY`, `LAYOUT_KEY`
  - `SaveData.load_best_score() -> int`, `save_best_score(score: int) -> bool`
  - `SaveData.load_best_time_ms(layout: String) -> int`, `save_best_time_ms(ms: int, layout: String) -> bool`

- [ ] **Step 1: 기준선 확인**

Run: `cd ~/games/cube-worm && git branch --show-current` 그리고 `전체 테스트`
Expected: `game-modes`, 마지막 줄 `전체 통과`.

- [ ] **Step 2: 오디오 `.import` 파일을 올린다(정리 커밋)**

```bash
cd ~/games/cube-worm
git status --short | grep -c "assets/audio/.*\.ogg\.import$"
git add assets/audio/*.ogg.import
git commit -m "오디오 파일의 .import 파일을 저장소에 올린다

소리 작업 때 빠뜨렸다. 다른 에셋(glb, jpg 등)은 .import 파일을 이미 올려 두고 있다.

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```
Expected: 첫 줄 출력 `12`.

- [ ] **Step 3: 실패하는 테스트 — `tests/test_records.gd`**

```gdscript
extends SceneTree

# 기록 판정과 표시 형식(순수 함수).
func _initialize() -> void:
	_test_to_ms()
	_test_format_time()
	_test_judge_time()
	_test_judge_score()
	_test_time_result_text()
	print("test_records: OK")
	quit()

func _test_to_ms() -> void:
	assert(Records.to_ms(0.0) == 0, "0초는 0ms")
	assert(Records.to_ms(42.31) == 42310, "소수 둘째 자리까지 그대로")
	assert(Records.to_ms(12.3456) == 12346, "밀리초로 반올림한다")
	assert(Records.to_ms(12.3454) == 12345, "반올림은 가까운 쪽")
	assert(Records.to_ms(-1.0) == 0, "음수는 0")

func _test_format_time() -> void:
	assert(Records.format_time(42310, 2) == "42.31", "소수 둘째 자리")
	assert(Records.format_time(42310, 1) == "42.3", "소수 첫째 자리")
	assert(Records.format_time(0, 1) == "0.0", "0 은 0.0")
	assert(Records.format_time(5000, 2) == "5.00", "끝자리 0 도 그대로 둔다")
	assert(Records.format_time(123456, 2) == "123.46", "백 초가 넘어도 초 단위로 쓴다")

func _test_judge_time() -> void:
	assert(Records.judge_time(42310, 0) == Records.Verdict.FIRST, "기록이 없었으면 첫 기록")
	assert(Records.judge_time(42310, 50000) == Records.Verdict.NEW_BEST, "더 빠르면 신기록")
	assert(Records.judge_time(42310, 42310) == Records.Verdict.NONE, "같은 시간은 신기록이 아니다")
	assert(Records.judge_time(60000, 42310) == Records.Verdict.NONE, "느리면 아니다")
	assert(Records.judge_time(0, 42310) == Records.Verdict.NONE and Records.judge_time(0, 0) == Records.Verdict.NONE, "0ms 이하는 기록이 아니다")

func _test_judge_score() -> void:
	assert(Records.judge_score(10, 5) == Records.Verdict.NEW_BEST, "최고를 넘으면 신기록")
	assert(Records.judge_score(5, 5) == Records.Verdict.NONE and Records.judge_score(3, 5) == Records.Verdict.NONE, "같거나 낮으면 아니다")
	assert(Records.judge_score(10, 0) == Records.Verdict.NONE, "기록이 없으면 신기록 연출을 하지 않는다(저장은 부르는 쪽이 따로 한다)")

func _test_time_result_text() -> void:
	assert(Records.time_result_text(42310, Records.Verdict.FIRST, 42310) == "클리어!\n42.31초\n첫 기록!\n탭하면 다시 도전", "첫 기록 문구")
	assert(Records.time_result_text(41800, Records.Verdict.NEW_BEST, 41800) == "클리어!\n41.80초\n신기록!\n탭하면 다시 도전", "신기록 문구")
	assert(Records.time_result_text(50000, Records.Verdict.NONE, 41800) == "클리어!\n50.00초\n최고 41.80초\n탭하면 다시 도전", "기록을 못 깼으면 최고 시간을 보인다")
```

- [ ] **Step 4: 실패 확인(RED)**

Run: `전체 테스트`
Expected: `SCRIPT ERROR: Parse Error: Identifier "Records" not declared` 비슷한 줄과 마지막 줄 `테스트 실패`.

- [ ] **Step 5: 구현 — `scripts/records.gd`**

```gdscript
class_name Records
extends RefCounted

# 기록 판정과 표시 형식을 모은 순수 함수. 저장은 SaveData, 화면은 Title·Hud 가 맡는다.

# 기록 비교 결과: 못 깼다 / 첫 기록 / 신기록
enum Verdict { NONE, FIRST, NEW_BEST }

# 초 → 밀리초 정수(반올림). 음수는 0.
static func to_ms(seconds: float) -> int:
	return maxi(0, roundi(seconds * 1000.0))

# 밀리초 → 초 단위 글자. decimals 가 1 이하면 소수 첫째 자리, 아니면 둘째 자리.
static func format_time(ms: int, decimals: int) -> String:
	var s := ms / 1000.0
	return ("%.1f" if decimals <= 1 else "%.2f") % s

# 새 시간 ms 를 저장된 최고 best_ms(0 = 기록 없음)와 비교한다. 같은 시간은 신기록이 아니다.
static func judge_time(ms: int, best_ms: int) -> int:
	if ms <= 0:
		return Verdict.NONE
	if best_ms <= 0:
		return Verdict.FIRST
	return Verdict.NEW_BEST if ms < best_ms else Verdict.NONE

# 점수 score 가 저장된 최고 best 를 넘었는가. 기록이 없으면(best <= 0) 신기록 연출을 하지 않으므로 NONE 이다.
# 첫 기록을 저장하는 일은 부르는 쪽이 따로 한다.
static func judge_score(score: int, best: int) -> int:
	return Verdict.NEW_BEST if best > 0 and score > best else Verdict.NONE

# 타임어택 결과 문구. best_ms 는 이번 기록을 반영한 뒤의 최고 시간이다.
static func time_result_text(ms: int, verdict: int, best_ms: int) -> String:
	var lines: Array[String] = ["클리어!", "%s초" % format_time(ms, 2)]
	match verdict:
		Verdict.FIRST:
			lines.append("첫 기록!")
		Verdict.NEW_BEST:
			lines.append("신기록!")
		_:
			lines.append("최고 %s초" % format_time(best_ms, 2))
	lines.append("탭하면 다시 도전")
	return "\n".join(lines)
```

- [ ] **Step 6: 통과 확인(GREEN)**

Run: `전체 테스트` 그리고 `grep -x "test_records: OK" .superpowers/t.txt`
Expected: `grep` 은 아무것도 안 찍고 마지막 줄 `전체 통과`, `test_records: OK` 한 줄.
(`test_font` 가 `scripts/records.gd` 의 새 문구를 검사한다. 글자가 없다는 실패가 나오면 그 글자를 문구에서 뺀다.)

- [ ] **Step 7: 실패하는 테스트 — SaveData 기록·호환·이름 고정**

`tests/test_save_data.gd` 의 `_initialize` 를 다음 파이썬으로 고친다.

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='tests/test_save_data.gd'
s=open(p,encoding='utf-8').read()
def r(o,n):
    global s
    assert s.count(o)==1,o
    s=s.replace(o,n,1)
r('	# 실제 저장 파일을 건드리면','	var default_path: String = SaveData.PATH  # 이름 고정 테스트가 기본 경로를 봐야 하므로 바꿔 끼우기 전에 적어 둔다\n	# 실제 저장 파일을 건드리면')
r('	_test_muted()\n','	_test_muted()\n	_test_best_score()\n	_test_best_time()\n	_test_old_format_file_keeps_working()\n	_test_names_are_pinned(default_path)\n')
open(p,'w',encoding='utf-8').write(s)
PY
```

그리고 파일 끝에 다음을 붙인다.

```bash
cd ~/games/cube-worm && cat >> tests/test_save_data.gd <<'EOF'

func _reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))

func _test_best_score() -> void:
	_reset()
	assert(SaveData.load_best_score() == 0, "저장한 적이 없으면 기록 없음(0)")
	assert(SaveData.save_best_score(12), "첫 기록은 저장된다")
	assert(SaveData.load_best_score() == 12, "저장한 점수를 읽는다")
	assert(not SaveData.save_best_score(12) and not SaveData.save_best_score(7), "같거나 낮은 점수는 저장하지 않는다")
	assert(SaveData.load_best_score() == 12, "나쁜 값을 넘겨도 기록이 내려가지 않는다")
	assert(SaveData.save_best_score(20) and SaveData.load_best_score() == 20, "더 높으면 갱신한다")
	assert(not SaveData.save_best_score(0) and not SaveData.save_best_score(-5), "0 이하는 저장하지 않는다")
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.SCORE_KEY, "많이")
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_score() == 0, "정수가 아니면 기록 없음")
	cfg.set_value(SaveData.SECTION, SaveData.SCORE_KEY, -4)
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_score() == 0, "1 미만이면 기록 없음")
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("{{{ 깨진 파일")
	f.close()
	assert(SaveData.load_best_score() == 0, "손상된 파일이면 기록 없음")
	assert(SaveData.save_best_score(3) and SaveData.load_best_score() == 3, "손상된 파일 위에도 다시 저장할 수 있다")

func _test_best_time() -> void:
	_reset()
	const L := "8-1-1"
	assert(SaveData.load_best_time_ms(L) == 0, "저장한 적이 없으면 기록 없음")
	assert(SaveData.save_best_time_ms(42310, L), "첫 기록은 저장된다")
	assert(SaveData.load_best_time_ms(L) == 42310, "저장한 시간을 읽는다")
	assert(not SaveData.save_best_time_ms(42310, L) and not SaveData.save_best_time_ms(50000, L), "같거나 느린 시간은 저장하지 않는다")
	assert(SaveData.load_best_time_ms(L) == 42310, "나쁜 값을 넘겨도 기록이 올라가지 않는다")
	assert(SaveData.save_best_time_ms(41800, L) and SaveData.load_best_time_ms(L) == 41800, "더 빠르면 갱신한다")
	assert(not SaveData.save_best_time_ms(0, L) and not SaveData.save_best_time_ms(-1, L), "0 이하는 저장하지 않는다")
	assert(SaveData.load_best_time_ms("8-2-1") == 0, "배치가 다르면 다른 판의 기록이라 기록 없음")
	assert(SaveData.save_best_time_ms(60000, "8-2-1") and SaveData.load_best_time_ms("8-2-1") == 60000, "다른 배치의 첫 기록은 옛 기록보다 느려도 저장된다")
	assert(SaveData.load_best_time_ms(L) == 0, "배치가 바뀌었으니 옛 배치 기록은 덮어쓰였다")
	var cfg := ConfigFile.new()
	cfg.set_value(SaveData.SECTION, SaveData.TIME_KEY, "빠름")
	cfg.set_value(SaveData.SECTION, SaveData.LAYOUT_KEY, L)
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_time_ms(L) == 0, "시간이 정수가 아니면 기록 없음")
	cfg.set_value(SaveData.SECTION, SaveData.TIME_KEY, 5000)
	cfg.set_value(SaveData.SECTION, SaveData.LAYOUT_KEY, 7)
	cfg.save(SaveData.PATH)
	assert(SaveData.load_best_time_ms(L) == 0, "배치 이름이 문자열이 아니면 기록 없음")
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("{{{ 깨진 파일")
	f.close()
	assert(SaveData.load_best_time_ms(L) == 0, "손상된 파일이면 기록 없음")
	assert(SaveData.save_best_time_ms(30000, L) and SaveData.load_best_time_ms(L) == 30000, "손상된 파일 위에도 다시 저장할 수 있다")

# 옛 형식 파일(스킨·소리만 있던 때)을 그대로 읽고, 기록을 써도 옛 값이 남는다. 업데이트해도 설정이 유지돼야 한다.
func _test_old_format_file_keeps_working() -> void:
	var f := FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("[progress]\n\nworm_skin=\"block\"\nsound_muted=true\n")
	f.close()
	assert(SaveData.load_skin() == "block" and SaveData.load_muted(), "옛 형식 파일의 스킨·소리를 읽는다")
	assert(SaveData.load_best_score() == 0 and SaveData.load_best_time_ms("8-1-1") == 0, "기록 키가 없으면 기록 없음")
	assert(SaveData.save_best_score(9) and SaveData.save_best_time_ms(30500, "8-1-1"), "옛 파일에 기록을 쓴다")
	assert(SaveData.load_skin() == "block" and SaveData.load_muted(), "기록을 써도 스킨·소리가 남는다")
	assert(SaveData.load_best_score() == 9 and SaveData.load_best_time_ms("8-1-1") == 30500, "기록을 읽는다")
	SaveData.save_skin("jelly")
	SaveData.save_muted(false)
	assert(SaveData.load_best_score() == 9 and SaveData.load_best_time_ms("8-1-1") == 30500, "스킨·소리를 저장해도 기록이 남는다")
	f = FileAccess.open(SaveData.PATH, FileAccess.WRITE)
	f.store_string("[progress]\n\nworm_skin=\"jelly\"\nsound_muted=false\nbest_score=128\nbest_time_ms=42310\nbest_time_layout=\"8-1-1\"\n")
	f.close()
	assert(SaveData.load_best_score() == 128 and SaveData.load_best_time_ms("8-1-1") == 42310, "글자 그대로 적은 새 형식 파일을 읽는다")

# 저장 파일 경로·칸·키·프로젝트 이름이 바뀌면 이미 저장된 기록이 읽히지 않는다(재배포해도 기록이 사라지는 사고).
# 바꿀 일이 생기면 옛 이름을 읽어 새 이름으로 옮기는 코드를 먼저 넣고 이 테스트를 고칠 것.
func _test_names_are_pinned(default_path: String) -> void:
	assert(default_path == "user://cube_worm_save.cfg", "저장 파일 경로: %s" % default_path)
	assert(SaveData.SECTION == "progress", "저장 칸")
	assert(SaveData.SKIN_KEY == "worm_skin" and SaveData.MUTE_KEY == "sound_muted", "스킨·소리 키")
	assert(SaveData.SCORE_KEY == "best_score" and SaveData.TIME_KEY == "best_time_ms" and SaveData.LAYOUT_KEY == "best_time_layout", "기록 키")
	assert(str(ProjectSettings.get_setting("application/config/name")) == "큐브 지렁이", "프로젝트 이름(사용자 데이터 폴더가 여기서 나온다)")
EOF
```

- [ ] **Step 8: 실패 확인(RED)**

Run: `전체 테스트`
Expected: `SCRIPT ERROR: Parse Error: Static function "load_best_score()" not found in base "SaveData"` 비슷한 줄과 마지막 줄 `테스트 실패`.

- [ ] **Step 9: 구현 — `scripts/save_data.gd`**

키 상수를 `MUTE_KEY` 줄 아래에 넣고, 파일 끝에 함수를 붙인다.

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='scripts/save_data.gd'
s=open(p,encoding='utf-8').read()
o='const MUTE_KEY := "sound_muted"\n'
assert s.count(o)==1
s=s.replace(o,o+'const SCORE_KEY := "best_score"\nconst TIME_KEY := "best_time_ms"\nconst LAYOUT_KEY := "best_time_layout"\n',1)
open(p,'w',encoding='utf-8').write(s)
PY
cat >> scripts/save_data.gd <<'EOF'

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
EOF
```

- [ ] **Step 10: 통과 확인(GREEN)과 커밋**

Run: `전체 테스트` 그리고 `grep -x "test_save_data: OK" .superpowers/t.txt`
Expected: 마지막 줄 `전체 통과`, `test_save_data: OK` 한 줄.

```bash
cd ~/games/cube-worm
git add scripts/records.gd scripts/records.gd.uid tests/test_records.gd tests/test_records.gd.uid scripts/save_data.gd tests/test_save_data.gd
git commit -m "기록 판정(Records)과 최고 기록 저장(SaveData)

- 점수·시간 판정, 시간 표시 형식, 타임어택 결과 문구를 순수 함수로 둔다
- 같은 저장 파일에 best_score, best_time_ms, best_time_layout 키만 더한다(기존 스킨·소리 값은 그대로)
- 좋아지는 방향으로만 쓰고, 깨진 값은 기록 없음으로 읽는다
- 옛 형식 파일 호환과 파일·키·프로젝트 이름 고정을 테스트로 묶는다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 시계(`Game.elapsed`)와 타임어택 고정 판

**Files:**
- Modify: `scripts/tuning.gd`, `scripts/records.gd`, `scripts/game.gd`
- Modify: `tests/test_game.gd`, `tests/test_records.gd`
- Create: `tests/test_time_layout.gd`

**Interfaces:**
- Consumes: Task 1 의 `Records`.
- Produces:
  - `Tuning.TIME_LEVEL := 8`, `Tuning.TIME_SEED := 1`, `Tuning.TIME_LAYOUT_VERSION := 1`
  - `Records.time_layout() -> String`(`"8-1-1"`)
  - `Game.elapsed: float`(초. `RUNNING` 이고 `paused` 가 아닐 때만 `delta` 를 더한다)

시드 1 은 미리 검사했다: 레벨 8 에서 모든 벌레가 바위를 거치지 않고 시작 칸에서 닿고, 벌레가 서로 다른 층 7개에 퍼져 있다(스펙의 "처음 만족하는 시드" 규칙에서 1 이 처음이다). 아래 스냅샷 값은 그 검사에서 나온 배치다.

- [ ] **Step 1: 실패하는 테스트 세 개**

(a) `tests/test_game.gd` — 등록과 함수:

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='tests/test_game.gd'
s=open(p,encoding='utf-8').read()
o='	_test_paused_freezes()\n'
assert s.count(o)==1
s=s.replace(o,o+'	_test_elapsed()\n',1)
open(p,'w',encoding='utf-8').write(s)
PY
cat >> tests/test_game.gd <<'EOF'

# 타임어택 시계: 실행 중에만 흐르고(맵 회전 중 제외), 클리어·죽음 뒤에는 멈춘다.
func _test_elapsed() -> void:
	var g := _clean()
	assert(g.elapsed == 0.0, "새 판의 시계는 0")
	g.advance(0.5)
	assert(g.elapsed == 0.0, "출발 전(대기 중)에는 시계가 서 있다")
	_go(g, -X)
	g.advance(0.1)
	g.advance(0.2)
	assert(is_equal_approx(g.elapsed, 0.3), "실행 중에는 프레임 시간이 쌓인다: %f" % g.elapsed)
	g.paused = true
	g.advance(0.5)
	assert(is_equal_approx(g.elapsed, 0.3), "맵이 도는 동안(paused)에는 멈춘다")
	g.paused = false
	g.advance(0.1)
	assert(is_equal_approx(g.elapsed, 0.4), "회전이 끝나면 다시 흐른다")
	var c := _clean()
	_bugs(c, [[Vector3i(3, 4, 4), 0]])
	_go(c, -X)
	_one_step(c)
	assert(c.state == Game.State.CLEARED, "마지막 벌레를 먹으면 클리어")
	var at_clear := c.elapsed
	assert(at_clear > 0.0, "클리어까지 시간이 흘렀다")
	for i in 60:
		c.advance(FRAME)
	assert(c.elapsed == at_clear, "클리어 뒤에는 시계가 멈춘다")
	var d := _clean(Vector3i(0, 4, 4))
	_go(d, -X)
	_one_step(d)
	assert(d.state == Game.State.DEAD, "벽에 부딪혀 죽었다")
	var at_death := d.elapsed
	d.advance(1.0)
	assert(d.elapsed == at_death, "죽은 뒤에는 시계가 멈춘다")
EOF
```

(b) `tests/test_records.gd` — 배치 이름:

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='tests/test_records.gd'
s=open(p,encoding='utf-8').read()
o='	_test_time_result_text()\n'
assert s.count(o)==1
s=s.replace(o,o+'	_test_time_layout()\n',1)
open(p,'w',encoding='utf-8').write(s)
PY
cat >> tests/test_records.gd <<'EOF'

# 판 배치 이름은 레벨-시드-규칙버전이다. 바뀌면 옛 시간 기록은 다른 판의 기록이라 숨겨진다.
# 일부러 바꿀 때는 이 테스트와 test_time_layout.gd 의 스냅샷을 같이 고친다.
func _test_time_layout() -> void:
	assert(Records.time_layout() == "8-1-1", "판 배치 이름: %s" % Records.time_layout())
EOF
```

(c) 새 파일 `tests/test_time_layout.gd`:

```gdscript
extends SceneTree

# 타임어택 고정 판: 같은 시드는 늘 같은 배치이고, 타임어택으로 할 만한 배치다.
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

# 고정 시드가 만드는 배치를 글자 그대로 적어 둔다. 판 생성 코드(Field, Game)가 바뀌어 배치가 달라지면 여기서 실패한다.
# 의도한 변경이면 Tuning.TIME_LAYOUT_VERSION 을 올리고(옛 시간 기록은 숨겨진다) 이 목록을 새 배치로 고친다.
# 바위는 x,y,z 를 글자순으로, 벌레는 생기는 순서대로 x,y,z:종류 다.
const ROCKS: Array[String] = ["0,4,5", "1,1,2", "1,5,1", "1,7,7", "2,2,1", "4,5,0", "5,6,7", "7,4,1"]
const BUGS: Array[String] = ["1,5,0:0", "1,3,1:0", "3,4,5:0", "2,7,1:1", "5,1,6:1", "6,5,6:1", "7,2,5:2", "2,0,5:2", "5,7,4:2"]

func _initialize() -> void:
	_test_same_seed_same_layout()
	_test_layout_snapshot()
	_test_every_bug_is_reachable()
	_test_bugs_spread_over_floors()
	print("test_time_layout: OK")
	quit()

func _game() -> Game:
	return Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)

func _rock_texts(g: Game) -> Array[String]:
	var out: Array[String] = []
	for r in g.field.rocks:
		out.append("%d,%d,%d" % [r.x, r.y, r.z])
	out.sort()
	return out

func _bug_texts(g: Game) -> Array[String]:
	var out: Array[String] = []
	for i in g.field.bugs.size():
		var b: Vector3i = g.field.bugs[i]
		out.append("%d,%d,%d:%d" % [b.x, b.y, b.z, g.field.kinds[i]])
	return out

func _test_same_seed_same_layout() -> void:
	var a := _game()
	var b := _game()
	assert(_rock_texts(a) == _rock_texts(b) and _bug_texts(a) == _bug_texts(b), "같은 시드로 두 번 만들면 배치가 같다")

func _test_layout_snapshot() -> void:
	var g := _game()
	assert(_rock_texts(g) == ROCKS, "바위 배치가 스냅샷과 다르다: %s" % [_rock_texts(g)])
	assert(_bug_texts(g) == BUGS, "벌레 배치가 스냅샷과 다르다: %s" % [_bug_texts(g)])

# 시작 칸에서 바위를 거치지 않고(상자 안의 이웃 칸으로 이어져) 모든 벌레에 닿는다.
func _test_every_bug_is_reachable() -> void:
	var g := _game()
	var seen := {g.worm.head(): true}
	var queue: Array[Vector3i] = [g.worm.head()]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_front()
		for d in DIRS:
			var n := c + d
			if g.field.in_bounds(n) and not g.field.has_rock(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for b in g.field.bugs:
		assert(seen.has(b), "벌레 %s 에 바위를 거치지 않고는 닿을 수 없다" % [b])

func _test_bugs_spread_over_floors() -> void:
	var g := _game()
	assert(g.height == 8 and g.field.bugs.size() == 9 and g.field.rocks.size() == 8, "레벨 8 판: 8층, 벌레 9마리, 바위 8개")
	var floors := {}
	for b in g.field.bugs:
		floors[b.y] = true
	assert(floors.size() >= 5, "벌레가 서로 다른 층 5개 이상에 퍼져 있다(세로 이동이 필요하다): %d" % floors.size())
```

- [ ] **Step 2: 실패 확인(RED)**

Run: `전체 테스트`
Expected: `SCRIPT ERROR` 줄들(`elapsed`, `TIME_SEED`, `time_layout` 을 찾을 수 없다는 뜻)과 마지막 줄 `테스트 실패`.

- [ ] **Step 3: 구현**

```bash
cd ~/games/cube-worm && python3 - <<'PY'
def patch(p, pairs):
    s=open(p,encoding='utf-8').read()
    for o,n in pairs:
        assert s.count(o)==1,(p,o)
        s=s.replace(o,n,1)
    open(p,'w',encoding='utf-8').write(s)
patch('scripts/tuning.gd',[
 ('const BUG_COUNT :=','''# 타임어택: 레벨 TIME_LEVEL 한 판을 고정 배치(시드가 같으면 바위·벌레 배치가 늘 같다)로 한다.
const TIME_LEVEL := 8
# 시드 1 이 조건(모든 벌레가 바위를 거치지 않고 닿는다, 벌레가 서로 다른 층 5개 이상)을 처음 만족해서 골랐다(7개 층).
const TIME_SEED := 1
# 판 생성 규칙(Field·Game 의 배치 코드)을 일부러 바꾸면 올린다. 시간 기록은 이 값이 같은 판끼리만 비교한다.
const TIME_LAYOUT_VERSION := 1
const BUG_COUNT :='''),
])
patch('scripts/game.gd',[
 ('var score := 0\n','var score := 0\nvar elapsed := 0.0            # 실행 중(맵 회전 중 제외)에 흐른 시간(초). 타임어택 기록이 쓴다\n'),
 ('	if state != State.RUNNING or paused:\n		return\n	alpha += minf(speed * delta, Tuning.MAX_STEP_PER_FRAME)\n',
  '	if state != State.RUNNING or paused:\n		return\n	elapsed += delta\n	alpha += minf(speed * delta, Tuning.MAX_STEP_PER_FRAME)\n'),
])
PY
cat >> scripts/records.gd <<'EOF'

# 타임어택 판 배치 이름. 레벨·시드·생성 규칙 버전이 바뀌면 달라져, 옛 시간 기록은 다른 판의 기록으로 숨겨진다.
static func time_layout() -> String:
	return "%d-%d-%d" % [Tuning.TIME_LEVEL, Tuning.TIME_SEED, Tuning.TIME_LAYOUT_VERSION]
EOF
git diff --stat
```

- [ ] **Step 4: 통과 확인(GREEN)**

Run: `전체 테스트` 그리고 `grep -x -e "test_game: OK" -e "test_time_layout: OK" -e "test_records: OK" .superpowers/t.txt`
Expected: 마지막 줄 `전체 통과`, 세 줄이 모두 나온다.
스냅샷 테스트가 실패하면 생성 코드가 이 계획을 쓴 뒤 바뀐 것이다 — 실제 배치를 `Game.new(1, false, 8)` 로 확인해 원인을 찾는다(스냅샷 값을 실제에 맞추기 전에 왜 달라졌는지부터 본다).

- [ ] **Step 5: 커밋**

```bash
cd ~/games/cube-worm
git add scripts/tuning.gd scripts/records.gd scripts/game.gd tests/test_game.gd tests/test_records.gd tests/test_time_layout.gd tests/test_time_layout.gd.uid
git commit -m "타임어택 시계(Game.elapsed)와 레벨 8 고정 판

- Game.elapsed: 실행 중(맵 회전 중 제외)에만 흐르고 클리어·죽음 뒤에는 멈춘다
- 타임어택 판은 레벨 8, 시드 1 로 고정하고 판 배치 이름(8-1-1)을 기록과 함께 저장할 수 있게 한다
- 고정 배치 스냅샷, 모든 벌레 도달 가능, 벌레가 5개 층 이상에 퍼짐을 테스트로 묶는다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: HUD 표시(타이머·최고·남은 벌레·메뉴 버튼)

**Files:**
- Modify: `scripts/title.gd`(`Mode` 열거만), `scripts/hud.gd`
- Modify: `tests/test_hud.gd`

**Interfaces:**
- Consumes: Task 1 의 `Records.format_time`, `Records.to_ms`.
- Produces(Task 4·5 가 쓴다):
  - `Title.Mode { CLASSIC, TIME_ATTACK }`
  - `Hud.menu_pressed` 신호, `Hud.menu_button`(`Hud.HomeButton`), `Hud.timer_label`, `Hud.best_label`, `Hud.bugs_label`
  - `Hud.set_mode(mode: int)`, `set_timer(seconds: float)`, `set_bugs_left(n: int)`, `set_best_score(best: int)`, `set_best_time(ms: int)`, `set_clear_text(text: String)`
  - 상수 `Hud.HEADER_X`(190.0), `Hud.HEADER_W`(180.0), `Hud.CLEAR_TEXT`

- [ ] **Step 1: 실패하는 테스트**

`tests/test_hud.gd` 의 `_initialize` 에 호출을 등록하고 함수를 붙인다.

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='tests/test_hud.gd'
s=open(p,encoding='utf-8').read()
o='	_test_sound_button()\n	print("test_hud: OK")\n'
assert s.count(o)==1
s=s.replace(o,'	_test_sound_button()\n	_test_mode_display()\n	_test_menu_button()\n	print("test_hud: OK")\n',1)
open(p,'w',encoding='utf-8').write(s)
PY
cat >> tests/test_hud.gd <<'EOF'

# 방식별 표시: 기존 방식은 점수와 레벨, 타임어택은 타이머·남은 벌레·최고 시간.
func _test_mode_display() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_mode(Title.Mode.CLASSIC)
	assert(hud.score_label.visible and not hud.timer_label.visible and not hud.bugs_label.visible, "기존 방식은 점수만 보인다")
	hud.set_level(3)
	assert(hud.level_label.text == "레벨 3", "레벨 글자")
	hud.set_best_score(128)
	assert(hud.best_label.text == "최고 128", "최고 점수")
	hud.set_best_score(0)
	assert(hud.best_label.text == "최고 --", "기록이 없으면 최고 --")
	hud.set_mode(Title.Mode.TIME_ATTACK)
	assert(not hud.score_label.visible and hud.timer_label.visible and hud.bugs_label.visible, "타임어택은 타이머와 남은 벌레가 보이고 점수는 숨는다")
	assert(hud.level_label.text == "타임어택", "가운데 글자")
	hud.set_timer(12.34)
	assert(hud.timer_label.text == "12.3", "타이머는 소수 첫째 자리: %s" % hud.timer_label.text)
	hud.set_timer(0.0)
	assert(hud.timer_label.text == "0.0", "출발 전 타이머")
	hud.set_bugs_left(6)
	assert(hud.bugs_label.text == "남은 벌레 6", "남은 벌레")
	hud.set_best_time(42310)
	assert(hud.best_label.text == "최고 42.31초", "최고 시간은 소수 둘째 자리")
	hud.set_best_time(0)
	assert(hud.best_label.text == "최고 --", "기록이 없으면 최고 --")
	hud.set_clear_text("a\nb")
	assert(hud.clear_label.text == "a\nb", "클리어 문구를 바꾼다")
	hud.set_mode(Title.Mode.CLASSIC)
	assert(hud.clear_label.text == Hud.CLEAR_TEXT and hud.score_label.visible and not hud.timer_label.visible, "기존 방식으로 돌아오면 클리어 문구와 점수가 돌아온다")
	assert(hud.level_label.position.x == Hud.HEADER_X and hud.best_label.position.x == Hud.HEADER_X, "가운데 글자는 점수·타이머와 오른쪽 버튼 사이에 놓는다")
	hud.queue_free()

func _test_menu_button() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	var got := [0]
	hud.menu_pressed.connect(func() -> void: got[0] += 1)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	hud.menu_button._gui_input(tap)
	assert(got[0] == 1, "메뉴 버튼을 누르면 신호가 온다")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	hud.menu_button._gui_input(release)
	assert(got[0] == 1, "손가락을 뗄 때는 신호가 없다")
	assert(hud.menu_button.position.x < 100.0 and hud.menu_button.position.y > hud.score_label.position.y + 100.0, "메뉴 버튼은 왼쪽 위, 점수 아래에 있다")
	hud.queue_free()
EOF
```

- [ ] **Step 2: 실패 확인(RED)**

Run: `전체 테스트`
Expected: `SCRIPT ERROR`(`Title.Mode` 또는 `Hud.set_mode` 를 찾을 수 없다) 비슷한 줄과 마지막 줄 `테스트 실패`.

- [ ] **Step 3: 구현**

(a) `Title` 에 방식 열거를 먼저 넣는다(화면 동작은 Task 5).

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='scripts/title.gd'
s=open(p,encoding='utf-8').read()
o='signal started\n'
assert s.count(o)==1
s=s.replace(o,o+'\n# 게임 방식. 방식 선택 화면의 버튼 순서와 같다.\nenum Mode { CLASSIC, TIME_ATTACK }\n',1)
open(p,'w',encoding='utf-8').write(s)
PY
```

(b) `Hud` 를 고친다.

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='scripts/hud.gd'
s=open(p,encoding='utf-8').read()
def r(o,n):
    global s
    assert s.count(o)==1,o
    s=s.replace(o,n,1)
r('# 위쪽: 점수, 빌드 버전과 fps, 맵 회전 버튼 2개. 죽은 뒤에는 다시 시작 안내.\n',
  '# 위쪽: 점수(타임어택은 타이머), 빌드 버전과 fps, 가운데 레벨·최고 기록, 소리·맵 회전 버튼. 죽은 뒤에는 다시 시작 안내.\n# 왼쪽 위 메뉴 버튼은 방식 선택 화면으로 돌아간다.\n')
r('signal sound_toggled(muted: bool)\n',
  'signal sound_toggled(muted: bool)\nsignal menu_pressed\n\n# 가운데 글자(레벨 또는 타임어택, 그 아래 최고 기록)의 왼쪽 끝과 폭: 왼쪽 점수·타이머와 오른쪽 버튼 사이에 놓는다.\nconst HEADER_X := 190.0\nconst HEADER_W := 180.0\nconst CLEAR_TEXT := "레벨 클리어!\\n탭하면 다음 레벨"\n')
r('var sound_button := SoundButton.new()\n',
  'var sound_button := SoundButton.new()\nvar timer_label := Label.new()   # 타임어택 타이머(점수 자리)\nvar best_label := Label.new()    # 레벨 글자 아래 최고 기록\nvar bugs_label := Label.new()    # 타임어택 남은 벌레\nvar menu_button := HomeButton.new()\n')
r('	level_label.position = Vector2(262, 20)\n	level_label.add_theme_font_size_override("font_size", 40)\n	add_child(level_label)\n',
  '''	level_label.position = Vector2(HEADER_X, 20)
	level_label.custom_minimum_size = Vector2(HEADER_W, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 40)
	add_child(level_label)
	best_label.position = Vector2(HEADER_X, 70)
	best_label.custom_minimum_size = Vector2(HEADER_W, 0)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 26)
	best_label.modulate = Color(1, 1, 1, 0.75)
	add_child(best_label)
	timer_label.position = Vector2(24, 16)
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.visible = false
	add_child(timer_label)
	bugs_label.position = Vector2(24, 108)
	bugs_label.add_theme_font_size_override("font_size", 26)
	bugs_label.visible = false
	add_child(bugs_label)
''')
r('	clear_label.text = "레벨 클리어!\\n탭하면 다음 레벨"\n','	clear_label.text = CLEAR_TEXT\n')
r('	add_child(sound_button)\n','''	add_child(sound_button)
	menu_button.position = Vector2(24, 150)
	menu_button.pressed.connect(menu_pressed.emit)
	add_child(menu_button)
''')
r('func show_clear(on: bool) -> void:\n	clear_label.visible = on\n','''func show_clear(on: bool) -> void:
	clear_label.visible = on

# 클리어 문구(타임어택은 걸린 시간과 기록이 들어간다).
func set_clear_text(text: String) -> void:
	clear_label.text = text

# 방식별 표시: 기존 방식은 점수, 타임어택은 타이머와 남은 벌레.
func set_mode(mode: int) -> void:
	var time_attack := mode == Title.Mode.TIME_ATTACK
	score_label.visible = not time_attack
	timer_label.visible = time_attack
	bugs_label.visible = time_attack
	if time_attack:
		level_label.text = "타임어택"
	else:
		clear_label.text = CLEAR_TEXT

# 타임어택 타이머(초). 소수 첫째 자리까지 보인다.
func set_timer(seconds: float) -> void:
	timer_label.text = Records.format_time(Records.to_ms(seconds), 1)

func set_bugs_left(n: int) -> void:
	bugs_label.text = "남은 벌레 %d" % n

# 기존 방식 최고 점수. 기록이 없으면 --.
func set_best_score(best: int) -> void:
	best_label.text = "최고 %d" % best if best > 0 else "최고 --"

# 타임어택 최고 시간(밀리초). 기록이 없으면 --.
func set_best_time(ms: int) -> void:
	best_label.text = "최고 %s초" % Records.format_time(ms, 2) if ms > 0 else "최고 --"
''')
open(p,'w',encoding='utf-8').write(s)
PY
cat >> scripts/hud.gd <<'EOF'

# 게임 중 방식 선택 화면으로 돌아가는 작은 버튼. 글자는 라벨, 바탕은 직접 그린다.
class HomeButton extends Control:
	signal pressed
	var _label := Label.new()
	var _style := StyleBoxFlat.new()

	func _init() -> void:
		size = Vector2(120.0, 68.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_style.bg_color = Color(1, 1, 1, 0.12)
		_style.set_corner_radius_all(24)
		_label.text = "메뉴"
		_label.add_theme_font_size_override("font_size", 30)
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
EOF
```

- [ ] **Step 4: 통과 확인(GREEN)과 커밋**

Run: `전체 테스트` 그리고 `grep -x "test_hud: OK" .superpowers/t.txt`
Expected: 마지막 줄 `전체 통과`, `test_hud: OK` 한 줄. (`test_font` 가 새 문구를 같이 검사한다.)

```bash
cd ~/games/cube-worm
git add scripts/title.gd scripts/hud.gd tests/test_hud.gd
git commit -m "HUD: 타임어택 타이머, 남은 벌레, 최고 기록, 메뉴 버튼

- 방식별 표시 전환(set_mode): 기존 방식은 점수, 타임어택은 타이머와 남은 벌레
- 가운데 글자(레벨/타임어택)와 그 아래 최고 기록을 점수·타이머와 오른쪽 버튼 사이로 옮긴다
- 왼쪽 위 메뉴 버튼(menu_pressed 신호). Title.Mode 열거를 만든다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `Main` 의 방식 흐름(기존 방식 최고 점수, 타임어택 타이머·죽음·클리어·기록)

**Files:**
- Modify: `scripts/main.gd`
- Create: `tests/test_modes_flow.gd`

**Interfaces:**
- Consumes: Task 1 `Records`, `SaveData`; Task 2 `Tuning.TIME_*`, `Records.time_layout`, `Game.elapsed`; Task 3 `Title.Mode`, `Hud` 의 새 메서드.
- Produces(Task 5 가 쓴다):
  - `Main.mode: int`, `best_score: int`, `best_time_ms: int`, `_record_enabled: bool`
  - `Main.start_mode(m: int, start_level := start_level_requested(), perf := perf_requested())`
  - `Main._on_cleared()`, `_update_best_score()`, `_refresh_records()`
  - 시작 화면(`title.visible`)이 떠 있는 동안 `game.advance` 를 부르지 않는다.

- [ ] **Step 1: 실패하는 테스트 — `tests/test_modes_flow.gd`**

```gdscript
extends SceneTree

# 방식별 흐름(Main): 기존 방식의 최고 점수, 타임어택의 타이머·죽음·클리어·기록.
# Main 하나를 띄워 두고 테스트마다 저장 파일을 비운 뒤 start_mode 로 새 세션을 연다.
# 프레임을 기다리지 않고 _process 를 직접 불러 시간을 정확히 정한다.

var _main: Node

func _initialize() -> void:
	SaveData.PATH = "user://test_modes_flow.cfg"  # 실제 기록을 건드리지 않는다
	_reset()
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	_main = load("res://scenes/main.tscn").instantiate()
	view.add_child(_main)
	await process_frame
	_main.title.visible = false  # 시작 화면은 넘긴 것으로 친다
	_test_classic_best_score()
	_test_classic_first_record_is_quiet()
	_test_classic_debug_start_does_not_record()
	_test_time_attack_setup_and_timer()
	_test_time_attack_death_retries_same_layout()
	_test_time_attack_clear_records()
	_test_game_stops_while_title_is_open()
	_test_rotation_pauses_timer()  # 회전 애니메이션이 끝나지 않은 채 남으므로 마지막에 둔다
	_reset()
	print("test_modes_flow: OK")
	quit()

func _reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))

# HUD 에 떠 있는 라벨 중 글자가 text 인 것의 수(떠오르는 문구를 센다).
func _count(text: String) -> int:
	return _main.hud.get_children().filter(func(n: Node) -> bool: return n is Label and n.text == text).size()

# 마지막 벌레를 먹고 seconds 초 만에 클리어한 상태로 만든다(실제 플레이를 건너뛴다).
func _clear_with(seconds: float) -> void:
	var g: Game = _main.game
	g.field.bugs.clear()
	g.field.kinds.clear()
	g.elapsed = seconds
	g.state = Game.State.CLEARED
	g.cleared.emit()

func _test_classic_best_score() -> void:
	_reset()
	SaveData.save_best_score(5)
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main.mode == Title.Mode.CLASSIC and _main.best_score == 5, "기존 방식으로 시작하고 저장된 최고 점수를 읽는다")
	assert(_main.hud.best_label.text == "최고 5", "HUD 에 최고 점수")
	assert(_main.hud.score_label.visible and not _main.hud.timer_label.visible and not _main.hud.bugs_label.visible, "기존 방식은 점수를 보인다")
	assert(_main.level == 1 and _main.hud.level_label.text == "레벨 1", "레벨 1 에서 시작")
	var cell := Vector3i(3, 4, 4)
	var pops := _count("신기록!")
	_main.game.score = 3
	_main._on_ate(0, 1, cell)
	assert(_main.best_score == 5 and SaveData.load_best_score() == 5 and _count("신기록!") == pops, "최고 아래에서는 아무 일 없다")
	_main.game.score = 6
	_main._on_ate(0, 1, cell)
	assert(_main.best_score == 6 and SaveData.load_best_score() == 6, "최고를 넘는 순간 갱신하고 바로 저장한다")
	assert(_main.hud.best_label.text == "최고 6", "HUD 최고 점수도 바뀐다")
	assert(_count("신기록!") == pops + 1, "이전 기록이 있었으니 신기록을 한 번 알린다")
	_main.game.score = 7
	_main._on_ate(0, 1, cell)
	assert(_main.best_score == 7 and SaveData.load_best_score() == 7 and _count("신기록!") == pops + 1, "계속 넘어도 신기록 알림은 한 번뿐")
	_main.game.state = Game.State.DEAD
	_main._dead_time = Tuning.DEATH_DELAY + 1.0
	_main._restart_if_ready()
	assert(_main.game.score == 0 and _main.best_score == 7 and SaveData.load_best_score() == 7, "죽어서 점수가 돌아가도 최고는 내려가지 않는다")

func _test_classic_first_record_is_quiet() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main.best_score == 0 and _main.hud.best_label.text == "최고 --", "기록이 없으면 최고 --")
	var pops := _count("신기록!")
	_main.game.score = 2
	_main._on_ate(0, 1, Vector3i(3, 4, 4))
	assert(_main.best_score == 2 and SaveData.load_best_score() == 2, "첫 기록도 저장된다")
	assert(_count("신기록!") == pops, "기록이 없던 첫 플레이에서는 신기록을 알리지 않는다")

func _test_classic_debug_start_does_not_record() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 5, false)
	assert(_main.level == 5 and not _main._record_enabled, "확인용 시작 레벨(?level=5)에서는 기록을 쓰지 않는다")
	_main.game.score = 9
	_main._on_ate(0, 1, Vector3i(3, 4, 4))
	assert(_main.best_score == 0 and SaveData.load_best_score() == 0, "점수를 올려도 저장되지 않는다")
	_main.start_mode(Title.Mode.CLASSIC, 1, true)
	assert(not _main._record_enabled, "?perf 로 시작한 판도 기록하지 않는다")
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main._record_enabled, "평소 시작은 기록한다")

func _test_time_attack_setup_and_timer() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK, 5, true)  # 확인용 주소 값이 와도 무시한다
	var g: Game = _main.game
	var ref := Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)
	assert(_main.mode == Title.Mode.TIME_ATTACK and _main.level == Tuning.TIME_LEVEL and g.height == Tuning.TIME_LEVEL, "타임어택은 레벨 8 판이다(확인용 주소는 무시)")
	assert(g.field.bugs == ref.field.bugs and g.field.rocks == ref.field.rocks, "고정 시드 배치다")
	assert(_main._record_enabled, "타임어택은 늘 기록한다")
	assert(_main.hud.timer_label.visible and _main.hud.bugs_label.visible and not _main.hud.score_label.visible, "타이머와 남은 벌레를 보이고 점수는 숨긴다")
	assert(_main.hud.level_label.text == "타임어택" and _main.hud.best_label.text == "최고 --", "가운데 글자")
	_main._process(0.2)
	assert(g.elapsed == 0.0 and _main.hud.timer_label.text == "0.0", "출발 전에는 타이머가 0")
	assert(_main.hud.bugs_label.text == "남은 벌레 9", "벌레 9마리")
	assert(g.press(Worm.Steer.LEFT), "첫 방향 입력으로 출발한다")
	_main._process(0.3)
	assert(is_equal_approx(g.elapsed, 0.3) and _main.hud.timer_label.text == "0.3", "출발하면 타이머가 흐른다: %f" % g.elapsed)

# 죽으면 그 시도는 끝: 타이머가 멈추고, 탭하면 같은 배치로 처음부터(타이머 0). 죽은 시도는 기록이 되지 않는다.
func _test_time_attack_death_retries_same_layout() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var g: Game = _main.game
	g.press(Worm.Steer.LEFT)
	_main._process(0.3)
	g.state = Game.State.DEAD  # 막다른 길을 찾아가는 대신 죽은 상태로 만든다
	var at_death := g.elapsed
	_main._process(0.5)
	assert(g.elapsed == at_death, "죽으면 타이머가 멈춘다")
	_main._dead_time = Tuning.DEATH_DELAY + 1.0
	_main._restart_if_ready()
	var ref := Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)
	assert(_main.game != g and _main.game.elapsed == 0.0 and _main.game.state == Game.State.WAITING, "탭하면 새 판, 타이머는 0")
	assert(_main.game.field.bugs == ref.field.bugs and _main.game.field.rocks == ref.field.rocks, "같은 배치로 다시 한다")
	assert(SaveData.load_best_time_ms(Records.time_layout()) == 0, "죽은 시도는 기록이 되지 않는다")

func _test_time_attack_clear_records() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var layout := Records.time_layout()
	_clear_with(42.31)
	assert(_main.best_time_ms == 42310 and SaveData.load_best_time_ms(layout) == 42310, "첫 클리어가 기록이 된다")
	assert(_main.hud.clear_label.text == "클리어!\n42.31초\n첫 기록!\n탭하면 다시 도전", "첫 기록 문구: %s" % _main.hud.clear_label.text)
	assert(_main.hud.best_label.text == "최고 42.31초", "HUD 최고 시간")
	assert(_main.sfx.last_id == "clear", "클리어 소리")
	_main._dead_time = Tuning.CLEAR_DELAY + 0.1
	_main._restart_if_ready()
	assert(_main.level == Tuning.TIME_LEVEL and _main.game.state == Game.State.WAITING and _main.game.elapsed == 0.0, "클리어 뒤 탭하면 같은 판을 다시 한다(다음 레벨로 가지 않는다)")
	_clear_with(50.0)
	assert(SaveData.load_best_time_ms(layout) == 42310 and _main.best_time_ms == 42310, "더 느린 시간은 기록을 바꾸지 않는다")
	assert(_main.hud.clear_label.text == "클리어!\n50.00초\n최고 42.31초\n탭하면 다시 도전", "느린 기록 문구: %s" % _main.hud.clear_label.text)
	_main._dead_time = Tuning.CLEAR_DELAY + 0.1
	_main._restart_if_ready()
	_clear_with(42.31)
	assert(SaveData.load_best_time_ms(layout) == 42310, "같은 시간은 기록을 바꾸지 않는다")
	assert(_main.hud.clear_label.text == "클리어!\n42.31초\n최고 42.31초\n탭하면 다시 도전", "같은 시간 문구: %s" % _main.hud.clear_label.text)
	_main._dead_time = Tuning.CLEAR_DELAY + 0.1
	_main._restart_if_ready()
	_clear_with(41.8)
	assert(_main.best_time_ms == 41800 and SaveData.load_best_time_ms(layout) == 41800, "더 빠르면 신기록")
	assert(_main.hud.clear_label.text == "클리어!\n41.80초\n신기록!\n탭하면 다시 도전", "신기록 문구: %s" % _main.hud.clear_label.text)
	assert(_main.hud.best_label.text == "최고 41.80초", "HUD 최고 시간도 바뀐다")

func _test_game_stops_while_title_is_open() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	_main.game.press(Worm.Steer.LEFT)
	_main._process(0.2)
	var t: float = _main.game.elapsed
	assert(t > 0.0, "달리는 중에는 시계가 흐른다")
	_main.title.visible = true
	_main._process(1.0)
	assert(_main.game.elapsed == t and _main.game.state == Game.State.RUNNING, "시작·선택 화면이 떠 있는 동안 게임이 멈춘다")
	_main.title.visible = false

func _test_rotation_pauses_timer() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var g: Game = _main.game
	g.press(Worm.Steer.LEFT)
	_main._process(0.3)
	var t := g.elapsed
	_main.rig.turn(1)
	_main._process(0.1)
	assert(g.elapsed == t, "맵이 도는 동안에는 타이머가 멈춘다")
```

- [ ] **Step 2: 실패 확인(RED)**

Run: `전체 테스트`
Expected: `SCRIPT ERROR: Invalid call. Nonexistent function 'start_mode' in base 'Node3D (main.gd)'.` 비슷한 줄과 마지막 줄 `테스트 실패`(또는 20초 `TIMEOUT`).

- [ ] **Step 3: 구현 — `scripts/main.gd`**

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='scripts/main.gd'
s=open(p,encoding='utf-8').read()
def r(o,n):
    global s
    assert s.count(o)==1,o
    s=s.replace(o,n,1)
r('var _dead_time := 0.0\n','''var mode: int = Title.Mode.CLASSIC  # 지금 방식(Title.Mode)
var best_score := 0     # 기존 방식 최고 점수(저장된 값)
var best_time_ms := 0   # 타임어택 최고 시간(밀리초, 저장된 값)
var _record_enabled := true    # 확인용 주소(?level, ?perf)로 시작한 기존 방식 판은 기록을 쓰지 않는다
var _celebrate_best := false   # 기존 방식: 시작 때 기록이 있었고 아직 신기록을 알리지 않았다
var _dead_time := 0.0
''')
r('	level = start_level_requested()\n	new_game()\n','	start_mode(Title.Mode.CLASSIC)\n')
r('func new_game() -> void:\n	game = Game.new(randi(), perf_requested(), level)\n	game.score = base_score\n	game.ate.connect(_on_ate)\n	game.cleared.connect(func() -> void: sfx.play("clear"))\n','''# 방식을 정하고 새 판을 준비한다. 기존 방식은 새 세션(시작 레벨, 점수 0)이다.
# start_level, perf 는 확인용 주소(?level=N, ?perf)의 값이다. 그렇게 시작한 판은 기록을 쓰지 않는다. 테스트가 바꿔 끼울 수 있게 인자로 둔다.
func start_mode(m: int, start_level := start_level_requested(), perf := perf_requested()) -> void:
	mode = m
	hud.set_mode(mode)
	if mode == Title.Mode.CLASSIC:
		level = start_level
		_record_enabled = start_level == 1 and not perf
	else:
		level = Tuning.TIME_LEVEL  # 타임어택은 확인용 주소를 무시한다
		_record_enabled = true
	base_score = 0
	_refresh_records()
	_celebrate_best = mode == Title.Mode.CLASSIC and best_score > 0
	new_game()

func new_game() -> void:
	if mode == Title.Mode.TIME_ATTACK:
		game = Game.new(Tuning.TIME_SEED, false, Tuning.TIME_LEVEL)  # 늘 같은 배치
	else:
		game = Game.new(randi(), perf_requested(), level)
	game.score = base_score
	game.ate.connect(_on_ate)
	game.cleared.connect(_on_cleared)
''')
r('	hud.set_level(game.level)\n','	if mode == Title.Mode.CLASSIC:\n		hud.set_level(game.level)\n')
r('	game.paused = rig.is_turning()\n	game.advance(delta)\n	hud.set_score(game.score)\n','''	game.paused = rig.is_turning()
	if not title.visible:
		game.advance(delta)  # 시작·방식 선택 화면이 떠 있는 동안 게임은 멈춘다
	hud.set_score(game.score)
	if mode == Title.Mode.TIME_ATTACK:
		hud.set_timer(game.elapsed)
		hud.set_bugs_left(game.field.bugs.size())
''')
r('	hud.pop("+%d" % points, at, Skins.BUGS[kind]["color"])\n','	hud.pop("+%d" % points, at, Skins.BUGS[kind]["color"])\n	if mode == Title.Mode.CLASSIC:\n		_update_best_score()\n')
r('''		if _dead_time >= Tuning.CLEAR_DELAY:
			base_score = game.score  # 클리어한 점수는 이어진다
			level = mini(level + 1, Tuning.LEVEL_MAX)
			new_game()
''','''		if _dead_time >= Tuning.CLEAR_DELAY:
			if mode == Title.Mode.CLASSIC:
				base_score = game.score  # 클리어한 점수는 이어진다
				level = mini(level + 1, Tuning.LEVEL_MAX)
			new_game()  # 타임어택은 같은 판을 다시 한다
''')
s=s.rstrip("\n")+'''

# 판의 벌레를 전부 먹었다. 타임어택이면 걸린 시간을 기록과 비교해 저장하고 결과 문구를 정한다.
func _on_cleared() -> void:
	sfx.play("clear")
	if mode != Title.Mode.TIME_ATTACK:
		return
	var ms := Records.to_ms(game.elapsed)
	var verdict := Records.judge_time(ms, best_time_ms)
	if verdict != Records.Verdict.NONE:
		best_time_ms = ms
		SaveData.save_best_time_ms(ms, Records.time_layout())
	hud.set_best_time(best_time_ms)
	hud.set_clear_text(Records.time_result_text(ms, verdict, best_time_ms))

# 기존 방식: 점수가 저장된 최고를 넘으면 바로 갱신·저장한다. 시작 때 기록이 있었으면 처음 넘는 순간 한 번 신기록을 알린다.
func _update_best_score() -> void:
	if not _record_enabled or game.score <= best_score:
		return
	var verdict := Records.judge_score(game.score, best_score)
	best_score = game.score
	SaveData.save_best_score(best_score)
	hud.set_best_score(best_score)
	if verdict == Records.Verdict.NEW_BEST and _celebrate_best:
		_celebrate_best = false
		hud.pop("신기록!", Vector2(360.0, 300.0))

# 저장된 최고 기록을 다시 읽어 HUD 에 보인다.
func _refresh_records() -> void:
	best_score = SaveData.load_best_score()
	best_time_ms = SaveData.load_best_time_ms(Records.time_layout())
	if mode == Title.Mode.CLASSIC:
		hud.set_best_score(best_score)
	else:
		hud.set_best_time(best_time_ms)
'''
open(p,'w',encoding='utf-8').write(s)
PY
git diff --stat scripts/main.gd
```

- [ ] **Step 4: 통과 확인(GREEN)**

Run: `전체 테스트` 그리고 `grep -x -e "test_modes_flow: OK" -e "test_main_smoke: OK" -e "test_levels_flow: OK" .superpowers/t.txt`
Expected: 마지막 줄 `전체 통과`, 세 줄이 모두 나온다. 기존 `test_main_smoke`·`test_levels_flow` 는 이 작업에서 고치지 않았는데도 통과해야 한다(시작 그림 터치로 게임이 시작되는 지금 동작이 그대로라서).

- [ ] **Step 5: 커밋**

```bash
cd ~/games/cube-worm
git add scripts/main.gd tests/test_modes_flow.gd tests/test_modes_flow.gd.uid
git commit -m "Main: 방식별 흐름(기존 방식 최고 점수, 타임어택 기록)

- start_mode 로 방식을 정하고 새 세션을 연다(확인용 주소로 시작한 판은 기록하지 않는다)
- 기존 방식: 점수가 최고를 넘는 순간 저장, 이전 기록이 있었으면 신기록을 한 번 알린다
- 타임어택: 레벨 8 고정 판, 타이머·남은 벌레 표시, 죽으면 같은 배치로 다시, 클리어하면 시간을 기록과 비교해 저장
- 시작·선택 화면이 떠 있는 동안 게임은 멈춘다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 방식 선택 화면(Title)과 연결(메뉴 버튼 포함)

**Files:**
- Modify: `scripts/title.gd`(전체 교체), `scripts/main.gd`
- Modify: `tests/test_title.gd`(전체 교체), `tests/test_main_smoke.gd`, `tests/test_levels_flow.gd`, `tests/test_modes_flow.gd`

**Interfaces:**
- Consumes: Task 1 `Records.format_time`; Task 3 `Title.Mode`, `Hud.menu_pressed`; Task 4 `Main.start_mode`, `Main._refresh_records`.
- Produces:
  - `Title.started`(첫 터치, TAP → MENU), `Title.mode_chosen(mode: int)`
  - `Title.in_menu: bool`, `Title.buttons: Array[ModeButton]`(`Mode` 순서), `Title.box`, `Title.shade`, `Title.image`
  - `Title.set_records(best_score: int, best_time_ms: int)`, `Title.show_menu()`
  - `Main._on_mode_chosen(m: int)`, `Main._on_menu_pressed()`

- [ ] **Step 1: 실패하는 테스트**

(a) `tests/test_title.gd` 전체를 다음으로 바꾼다.

```gdscript
extends SceneTree

# 시작 화면: 첫 터치로 방식 선택이 열리고, 버튼을 누르면 방식이 정해지며 사라진다.
func _initialize() -> void:
	assert(Title.Mode.CLASSIC == 0 and Title.Mode.TIME_ATTACK == 1, "버튼 순서가 열거 값과 같다")
	var title := Title.new()
	root.add_child(title)
	assert(title.visible and not title.in_menu and title.image.texture != null, "처음에는 그림만 보인다")
	assert(title.image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "그림이 화면을 채운다(비율 유지)")
	assert(title.buttons.size() == 2 and not title.box.visible and not title.shade.visible, "버튼과 어두운 띠는 아직 숨어 있다")
	var started := [0]
	var chosen: Array[int] = []
	title.started.connect(func() -> void: started[0] += 1)
	title.mode_chosen.connect(func(m: int) -> void: chosen.append(m))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	title.image._gui_input(release)
	assert(started[0] == 0 and not title.in_menu, "손가락을 뗄 때는 시작하지 않는다")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	title.image._gui_input(tap)
	assert(title.visible and title.in_menu and started[0] == 1, "첫 터치로 방식 선택이 열리고 시작 신호가 한 번 온다")
	assert(title.box.visible and title.shade.visible, "방식 버튼과 어두운 띠가 보인다")
	title.image._gui_input(tap)
	assert(started[0] == 1 and chosen.is_empty(), "방식 선택 중 그림을 다시 터치해도 아무 일 없다")
	title.buttons[Title.Mode.TIME_ATTACK]._gui_input(release)
	assert(chosen.is_empty(), "버튼도 손가락을 뗄 때는 반응하지 않는다")
	title.buttons[Title.Mode.TIME_ATTACK]._gui_input(tap)
	assert(chosen == [Title.Mode.TIME_ATTACK] and not title.visible, "버튼을 누르면 그 방식이 정해지고 화면이 사라진다")
	title.show_menu()
	assert(title.visible and title.in_menu and started[0] == 1, "메뉴로 돌아오면 방식 선택이 다시 열린다(시작 신호는 다시 오지 않는다)")
	title.buttons[Title.Mode.CLASSIC]._gui_input(tap)
	assert(chosen == [Title.Mode.TIME_ATTACK, Title.Mode.CLASSIC], "다시 고를 수 있다")
	title.set_records(128, 42310)
	assert(title.buttons[Title.Mode.CLASSIC].record.text == "최고 점수 128", "기존 방식 버튼에 최고 점수")
	assert(title.buttons[Title.Mode.TIME_ATTACK].record.text == "최고 기록 42.31초", "타임어택 버튼에 최고 기록")
	title.set_records(0, 0)
	assert(title.buttons[Title.Mode.CLASSIC].record.text == "기록 없음" and title.buttons[Title.Mode.TIME_ATTACK].record.text == "기록 없음", "기록이 없으면 기록 없음")
	print("test_title: OK")
	quit()
```

(b) 시작 그림 다음에 방식을 고르도록 기존 두 테스트를 고친다.

```bash
cd ~/games/cube-worm && grep -ln 'scenes/main.tscn' tests/*.gd && python3 - <<'PY'
def patch(p, pairs):
    s=open(p,encoding='utf-8').read()
    for o,n in pairs:
        assert s.count(o)==1,(p,o)
        s=s.replace(o,n,1)
    open(p,'w',encoding='utf-8').write(s)
patch('tests/test_main_smoke.gd',[
 ('''	main.title.image._gui_input(title_tap)
	assert(not main.title.visible and game.state == Game.State.WAITING, "터치하면 시작 화면이 사라지고 게임은 출발을 기다린다")
	assert(main.sfx.music_active, "시작 화면을 터치하면 BGM 이 시작된다(웹은 이 터치에서 소리가 풀린다)")
''','''	main.title.image._gui_input(title_tap)
	assert(main.title.visible and main.title.in_menu and game.state == Game.State.WAITING, "첫 터치로 방식 선택이 열린다(아직 시작 화면 위)")
	assert(main.sfx.music_active, "시작 화면을 터치하면 BGM 이 시작된다(웹은 이 터치에서 소리가 풀린다)")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(game.state == Game.State.WAITING, "방식 선택 중에도 입력이 게임에 닿지 않는다")
	main.title.buttons[Title.Mode.CLASSIC]._gui_input(title_tap)
	assert(not main.title.visible and main.game != game and main.game.state == Game.State.WAITING, "기존 방식을 고르면 새 판이 출발을 기다린다")
	game = main.game
'''),
 ('	quiet.title.image._gui_input(title_tap)  # 시작 화면을 넘긴다(꺼진 상태라 BGM 이 시작되지 않아야 한다)\n',
  '	quiet.title.image._gui_input(title_tap)  # 시작 화면을 넘긴다(꺼진 상태라 BGM 이 시작되지 않아야 한다)\n	quiet.title.buttons[Title.Mode.CLASSIC]._gui_input(title_tap)\n'),
])
patch('tests/test_levels_flow.gd',[
 ('	main.title.image.tapped.emit()  # 시작 화면을 넘긴다\n',
  '	main.title.image.tapped.emit()  # 시작 그림을 넘긴다(방식 선택이 열린다)\n	main.title.buttons[Title.Mode.CLASSIC].chosen.emit()  # 기존 방식\n'),
])
PY
```
Expected: `grep -ln` 이 `tests/test_levels_flow.gd`, `tests/test_main_smoke.gd`, `tests/test_modes_flow.gd` 세 개를 낸다(메인 장면을 띄우는 테스트가 이 셋뿐이라는 확인).

(c) `tests/test_modes_flow.gd` 에 화면 흐름 테스트를 더한다.

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='tests/test_modes_flow.gd'
s=open(p,encoding='utf-8').read()
o='	_test_game_stops_while_title_is_open()\n'
assert s.count(o)==1
s=s.replace(o,o+'	_test_menu_flow()\n',1)
open(p,'w',encoding='utf-8').write(s)
PY
cat >> tests/test_modes_flow.gd <<'EOF'

# 시작 그림 → 방식 선택 → 판 → 메뉴 버튼 → 다시 선택: 화면 흐름과 최고 기록 표시.
func _test_menu_flow() -> void:
	_reset()
	SaveData.save_best_score(128)
	SaveData.save_best_time_ms(42310, Records.time_layout())
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(main)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	assert(main.title.visible and not main.title.in_menu, "처음에는 시작 그림")
	main.title.image._gui_input(tap)
	assert(main.title.in_menu and main.sfx.music_active, "첫 터치로 방식 선택이 열리고 BGM 이 시작된다")
	assert(main.title.buttons[Title.Mode.CLASSIC].record.text == "최고 점수 128", "방식 선택에 최고 점수")
	assert(main.title.buttons[Title.Mode.TIME_ATTACK].record.text == "최고 기록 42.31초", "방식 선택에 최고 시간")
	main.title.buttons[Title.Mode.TIME_ATTACK]._gui_input(tap)
	assert(not main.title.visible and main.mode == Title.Mode.TIME_ATTACK and main.game.height == Tuning.TIME_LEVEL, "타임어택을 고르면 레벨 8 판이 준비된다")
	assert(main.sfx.last_id == "start" and main.hud.best_label.text == "최고 42.31초", "시작 소리, HUD 에 최고 시간")
	# 게임 중 메뉴 버튼: 최신 기록을 읽어 선택 화면으로 돌아오고, 그동안 게임은 멈춘다.
	var running: Game = main.game
	running.press(Worm.Steer.LEFT)
	main._process(0.2)
	var t := running.elapsed
	SaveData.save_best_score(200)
	main.hud.menu_button._gui_input(tap)
	assert(main.title.visible and main.title.in_menu, "메뉴 버튼으로 방식 선택 화면에 돌아온다")
	assert(main.title.buttons[Title.Mode.CLASSIC].record.text == "최고 점수 200", "돌아오면 최신 기록을 다시 읽는다")
	main._process(1.0)
	assert(running.elapsed == t, "선택 화면이 떠 있는 동안 게임이 멈춘다")
	main.controller.steer_pressed.emit(Worm.Steer.LEFT)
	assert(main.game == running, "선택 화면 뒤에서는 입력이 게임에 닿지 않는다")
	# 같은 방식을 다시 골라도 새 판이다.
	main.title.buttons[Title.Mode.TIME_ATTACK]._gui_input(tap)
	assert(main.game != running and main.game.elapsed == 0.0 and main.game.state == Game.State.WAITING, "같은 방식을 다시 골라도 새 판이다")
	main.hud.menu_button._gui_input(tap)
	main.title.buttons[Title.Mode.CLASSIC]._gui_input(tap)
	assert(main.mode == Title.Mode.CLASSIC and main.level == 1 and main.game.score == 0, "기존 방식은 새 세션(레벨 1, 점수 0)")
	assert(main.hud.level_label.text == "레벨 1" and main.hud.score_label.visible and not main.hud.timer_label.visible, "기존 방식 HUD 로 돌아온다")
	view.queue_free()
EOF
```

- [ ] **Step 2: 실패 확인(RED)**

Run: `전체 테스트`
Expected: `SCRIPT ERROR`(`Title` 에 `in_menu`·`buttons`·`show_menu` 가 없다는 뜻) 비슷한 줄들과 마지막 줄 `테스트 실패`(또는 `TIMEOUT`).

- [ ] **Step 3: 구현 — `scripts/title.gd` 를 다음으로 통째로 바꾼다**

```gdscript
class_name Title
extends CanvasLayer

# 시작 화면(TAP): 그림 한 장이 화면을 채운다. 어디든 터치하면 방식 선택(MENU)이 열린다.
# MENU: 같은 그림 위에 방식 버튼 둘이 뜬다. 그림 아래쪽에 박힌 TAP TO START 글자는 어두운 띠로 덮는다.
# 버튼을 누르면 mode_chosen 신호를 내고 사라진다. 게임 중 HUD 의 메뉴 버튼은 show_menu() 로 MENU 를 다시 연다.

signal started                 # 첫 터치(TAP → MENU). 웹은 첫 터치 뒤에야 소리가 풀리므로 밖에서 이때 BGM 을 시작한다
signal mode_chosen(mode: int)  # 고른 방식(Mode)

# 게임 방식. 방식 선택 화면의 버튼 순서와 같다.
enum Mode { CLASSIC, TIME_ATTACK }

const IMAGE := "res://assets/title.jpg"
const SHADE_H := 620.0         # MENU 에서 화면 아래쪽을 덮는 어두운 띠의 높이
const BOX_GAP := 130.0         # 버튼 묶음 아래와 화면 아래 가장자리 사이
const BUTTON_W := 560.0
const BUTTON_H := 160.0
const BUTTON_GAP := 36.0

var image := Picture.new()
var shade := TextureRect.new()
var box := VBoxContainer.new()
var buttons: Array[ModeButton] = []
var in_menu := false           # 방식 선택이 열려 있는가(첫 터치 뒤 true)

func _init() -> void:
	layer = 10  # HUD(1) 위
	add_child(image)
	image.tapped.connect(_on_tapped)
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -SHADE_H
	shade.visible = false
	add_child(shade)
	var box_h := BUTTON_H * 2.0 + BUTTON_GAP
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -BUTTON_W * 0.5
	box.offset_right = BUTTON_W * 0.5
	box.offset_top = -(BOX_GAP + box_h)
	box.offset_bottom = -BOX_GAP
	box.add_theme_constant_override("separation", int(BUTTON_GAP))
	box.visible = false
	add_child(box)
	for m in [Mode.CLASSIC, Mode.TIME_ATTACK]:
		var b := ModeButton.new("기존 방식" if m == Mode.CLASSIC else "타임어택")
		b.chosen.connect(_on_chosen.bind(m))
		box.add_child(b)
		buttons.append(b)
	set_records(0, 0)

# 위는 투명, 아래로 갈수록 배경색으로 짙어지는 세로 그라데이션.
static func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4])
	g.colors = PackedColorArray([Color(0.11, 0.07, 0.05, 0.0), Color(0.11, 0.07, 0.05, 0.96)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	t.width = 8
	t.height = 256
	return t

# 방식 선택 버튼에 내 최고 기록을 적는다(0 = 기록 없음).
func set_records(best_score: int, best_time_ms: int) -> void:
	buttons[Mode.CLASSIC].record.text = ("최고 점수 %d" % best_score) if best_score > 0 else "기록 없음"
	buttons[Mode.TIME_ATTACK].record.text = ("최고 기록 %s초" % Records.format_time(best_time_ms, 2)) if best_time_ms > 0 else "기록 없음"

# 방식 선택을 다시 연다(게임 중 HUD 메뉴 버튼). 시작 신호는 내지 않는다.
func show_menu() -> void:
	visible = true
	_open_menu()

func _open_menu() -> void:
	in_menu = true
	shade.visible = true
	box.visible = true

func _on_tapped() -> void:
	if not visible or in_menu:
		return
	_open_menu()
	started.emit()

func _on_chosen(m: int) -> void:
	visible = false
	mode_chosen.emit(m)

class Picture extends TextureRect:
	signal tapped

	func _init() -> void:
		texture = load(IMAGE)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 버튼이 터치를 받지 않게 막는다

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			tapped.emit()
			accept_event()

# 방식 선택 버튼: 둥근 사각형, 위에 이름, 아래에 한 줄 기록.
class ModeButton extends Control:
	signal chosen
	var title := Label.new()
	var record := Label.new()
	var _style := StyleBoxFlat.new()

	func _init(text: String) -> void:
		custom_minimum_size = Vector2(BUTTON_W, BUTTON_H)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_style.bg_color = Color(0.22, 0.13, 0.08, 0.94)
		_style.border_color = Color(0.98, 0.78, 0.45)
		_style.set_border_width_all(4)
		_style.set_corner_radius_all(44)
		title.text = text
		title.add_theme_font_size_override("font_size", 56)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title.offset_top = 20.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
		record.add_theme_font_size_override("font_size", 32)
		record.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		record.offset_top = 98.0
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(record)

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			chosen.emit()
			accept_event()

	func _draw() -> void:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
```

- [ ] **Step 4: 구현 — `scripts/main.gd` 연결**

```bash
cd ~/games/cube-worm && python3 - <<'PY'
p='scripts/main.gd'
s=open(p,encoding='utf-8').read()
def r(o,n):
    global s
    assert s.count(o)==1,o
    s=s.replace(o,n,1)
r('	title.started.connect(_on_title_started)\n','	title.started.connect(_on_title_started)\n	title.mode_chosen.connect(_on_mode_chosen)\n')
r('	hud.sound_toggled.connect(_on_sound_toggled)\n','	hud.sound_toggled.connect(_on_sound_toggled)\n	hud.menu_pressed.connect(_on_menu_pressed)\n')
r('func _on_title_started() -> void:\n	sfx.start_music()  # 사용자의 첫 터치라서 웹에서도 소리가 풀린다\n','''func _on_title_started() -> void:
	sfx.start_music()  # 사용자의 첫 터치라서 웹에서도 소리가 풀린다

# 방식 선택 화면에서 방식 버튼을 눌렀다.
func _on_mode_chosen(m: int) -> void:
	sfx.play("start")
	start_mode(m)

# 게임 중 HUD 의 메뉴 버튼: 최신 기록을 읽어 방식 선택 화면으로 돌아간다(게임은 그 동안 멈춘다).
func _on_menu_pressed() -> void:
	_refresh_records()
	title.show_menu()
''')
r('	best_time_ms = SaveData.load_best_time_ms(Records.time_layout())\n	if mode == Title.Mode.CLASSIC:\n','	best_time_ms = SaveData.load_best_time_ms(Records.time_layout())\n	title.set_records(best_score, best_time_ms)\n	if mode == Title.Mode.CLASSIC:\n')
open(p,'w',encoding='utf-8').write(s)
PY
git diff --stat scripts/main.gd
```

- [ ] **Step 5: 통과 확인(GREEN)**

Run: `전체 테스트` 그리고 `grep -x -e "test_title: OK" -e "test_modes_flow: OK" -e "test_main_smoke: OK" -e "test_levels_flow: OK" -e "test_font: OK" .superpowers/t.txt`
Expected: 마지막 줄 `전체 통과`, 다섯 줄이 모두 나온다.
실패하면 어느 단언인지 `SCRIPT ERROR` 로 나온다. `test_font` 가 실패하면 그 글자를 쓰는 문구를 폰트에 있는 글자로 바꾼다.
`TIMEOUT` 이 나오면(특히 `test_modes_flow`, `test_main_smoke`) 파일당 20초 제한에 걸린 것이다 — `Main` 을 만드는 횟수를 줄이거나 기다림을 줄인다.

- [ ] **Step 6: 커밋**

```bash
cd ~/games/cube-worm
git add scripts/title.gd scripts/main.gd tests/test_title.gd tests/test_main_smoke.gd tests/test_levels_flow.gd tests/test_modes_flow.gd
git commit -m "시작 화면 터치 뒤 방식 선택(기존 방식 / 타임어택)

- 시작 그림을 터치하면 같은 그림 위에 방식 버튼 둘이 뜬다(각 버튼에 내 최고 기록)
- 버튼을 누르면 그 방식의 새 판이 준비되고 시작 소리가 난다
- HUD 메뉴 버튼으로 선택 화면에 돌아온다(최신 기록을 다시 읽고, 그동안 게임은 멈춘다)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: 배포와 웹 확인, 기록 유지 확인

**Files:** 없음(푸시와 확인만). 화면이 어긋나면 `scripts/title.gd` 의 상수(`SHADE_H`, `BOX_GAP`, `BUTTON_*`)와 `scripts/hud.gd` 의 위치 값만 조정한다(조정하면 테스트를 다시 돌리고 같은 브랜치에 커밋한다).

- [ ] **Step 1: 푸시와 배포 확인**

```bash
cd ~/games/cube-worm
git push -u origin game-modes 2>&1 | tail -1
sleep 100; gh run list --branch game-modes --limit 1
```
Expected: `completed success`. 실패하면 `gh run view --log-failed` 로 읽고 고친다(CI 도 같은 테스트를 돌린다).

- [ ] **Step 2: 시작 그림과 방식 선택 화면**

Chrome 모바일 에뮬레이션(390×844, 배율 3, 모바일, 터치)으로 `https://kjw5541a-hash.github.io/cube-worm/?v=<번호>` 를 연다(`v=` 는 캐시를 피하는 아무 숫자). 화면 왼쪽 위의 빌드 문구가 `game-modes` 브랜치인지 확인한다.
캔버스에 터치를 보내는 스니펫(분수 fx, fy 는 화면 비율 좌표, 첫 확인은 그림 한가운데):

```js
() => { const c = document.querySelector('iframe').contentDocument.querySelector('canvas'); const r = c.getBoundingClientRect(); const fx = 0.5, fy = 0.5; const x = r.left + r.width * fx, y = r.top + r.height * fy; const t = new Touch({identifier: 1, target: c, clientX: x, clientY: y}); c.dispatchEvent(new TouchEvent('touchstart', {bubbles: true, cancelable: true, touches: [t], changedTouches: [t]})); c.dispatchEvent(new TouchEvent('touchend', {bubbles: true, cancelable: true, touches: [], changedTouches: [t]})); return [r.width, r.height, x, y]; }
```
확인(스크린샷):
1. 처음 화면은 시작 그림(TAP TO START)이다.
2. 터치하면 같은 그림 위에 두 버튼(`기존 방식`/`타임어택`, 각각 `기록 없음`)이 뜨고, 그림 아래쪽의 TAP TO START 글자는 어두운 띠에 가려져 있다. 버튼이 그림 글자나 가장자리에 겹치거나 잘리지 않는다. 어긋나면 상수를 조정한다.

- [ ] **Step 3: 두 방식 시작과 HUD**

버튼 위치를 스크린샷에서 읽어 터치한다.
1. `타임어택`: 가운데 `타임어택` 과 `최고 --`, 왼쪽 위 `0.0`(큰 글자), 그 아래 `남은 벌레 9`, 왼쪽 위 `메뉴` 버튼, 점수 숫자는 없다. 글자가 오른쪽 소리·회전 버튼과 겹치지 않는다.
2. **판 배치가 웹에서도 같은가:** 층 눈금(왼쪽 아래)의 층별 점이 아래와 같아야 한다(헤드리스 스냅샷과 같은 배치라는 증거다). 지렁이가 있는 5층(맨 아래가 1층)이 노란 테두리다.

| 층 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| 벌레(색) | 주황 1 | 노랑 1 | 주황 1 | 크림 1 | 크림 1 | 크림 1 + 노랑 1 | 없음 | 노랑 1 + 주황 1 |
| 바위(네모) | 0 | 1 | 1 | 0 | 2 | 2 | 1 | 1 |

(층 번호는 1부터이고 스냅샷 `BUGS`/`ROCKS` 의 y 값 + 1 이다. 벌레 색은 종류 0 크림, 1 노랑, 2 주황이다. 표와 다르면 판 생성이 웹에서 다르다는 뜻이니 멈추고 원인을 찾는다.)

3. 왼쪽 방향 버튼(◀)을 터치하면 출발하고 타이머가 올라간다. 몇 초 두면 벽에 부딪혀 죽고 `탭하면 다시 시작` 이 뜬다. 화면을 터치하면 타이머 `0.0`, 같은 배치(층 눈금이 같다)로 다시 준비된다.
4. `메뉴` 버튼을 누르면 방식 선택이 다시 열린다. `기존 방식` 을 고르면 `레벨 1`, 점수, `최고 --` 가 보이고 타이머는 사라진다.

- [ ] **Step 4: 기록이 읽히는지, 재배포 뒤에도 남는지**

웹의 `user://` 는 IndexedDB(`/userfs`)에 있다. 먼저 저장 파일이 생기도록 지렁이 선택 줄의 오른쪽 화살표를 한 번 터치해 스킨을 바꾼다(대기 중에만 보인다). 그 뒤 저장 파일 키를 찾는다.

```js
async () => { const db = await new Promise((res, rej) => { const r = indexedDB.open('/userfs'); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); const name = db.objectStoreNames[0]; const keys = await new Promise((res) => { const q = db.transaction(name).objectStore(name).getAllKeys(); q.onsuccess = () => res(q.result); }); db.close(); return keys.filter(k => String(k).includes('cube_worm_save')); }
```
찾은 키(`<KEY>`)의 파일 끝에 기록 세 줄을 덧붙이고 되돌려 쓴다(저장 형식과 키 이름이 웹에서 읽히는지 보는 것이다).

```js
async () => { const key = '<KEY>'; const db = await new Promise((res, rej) => { const r = indexedDB.open('/userfs'); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); const name = db.objectStoreNames[0]; const entry = await new Promise((res) => { const q = db.transaction(name).objectStore(name).get(key); q.onsuccess = () => res(q.result); }); const text = new TextDecoder().decode(entry.contents).replace(/\s*$/, '\n') + 'best_score=128\nbest_time_ms=42310\nbest_time_layout="8-1-1"\n'; entry.contents = new TextEncoder().encode(text); entry.timestamp = new Date(); await new Promise((res) => { const q = db.transaction(name, 'readwrite').objectStore(name).put(entry, key); q.onsuccess = () => res(); }); db.close(); return text; }
```
페이지를 새로고침(`navigate_page` 로 같은 주소, 캐시 무시)하고 시작 그림을 터치한다.
Expected: 방식 선택 버튼에 `최고 점수 128` 과 `최고 기록 42.31초` 가 보인다. `기존 방식` 을 고르면 HUD 에 `최고 128`, `타임어택` 을 고르면 `최고 42.31초` 가 보인다.

재배포 뒤에도 남는지(업데이트해도 기록이 유지되는지) 본다: 새 빌드를 만든다.

```bash
cd ~/games/cube-worm && gh workflow run deploy.yml --ref game-modes && sleep 100 && gh run list --branch game-modes --limit 1
```
Expected: `completed success`. 화면 왼쪽 위 빌드 번호가 바뀐 새 빌드를 같은 브라우저 프로필로 다시 열고(캐시 무시) 시작 그림을 터치한다.
Expected: 방식 선택 버튼의 `최고 점수 128`, `최고 기록 42.31초` 가 그대로 남아 있다.
확인이 끝나면 위 키를 실제 사용자의 기록으로 오해하지 않도록 이 브라우저 프로필의 저장 파일에서 기록 세 줄을 되돌린다(이 프로필은 자동화 전용이다).

- [ ] **Step 5: 프로젝트 메모리 갱신과 사용자 보고**

`~/.claude/projects/-Users-kjw5541/memory/project_3d_worm_game.md` 에 한 문단을 더하고(`game-modes` 브랜치, 스펙·계획서 경로, 방식 선택·타임어택·기록 저장 요지, 기록 유지 조건과 한계, 사용자 판단 대기 항목) `MEMORY.md` 의 3D 지렁이 줄을 갱신한다.
사용자에게 한국어로 보고한다: 주소와 빌드 번호, 확인한 것과 못 한 것(클리어·신기록 화면은 흐름 테스트로만 확인, 실제 화면은 폰), 폰에서 볼 것:
- 방식 선택 화면 모양과 글자 크기.
- 타임어택 타이머·`남은 벌레` 글자가 잘 보이는지, 레벨 8 고정 판의 난이도와 재미.
- 기록이 앱을 껐다 켜도, 업데이트 뒤에도 남는지(홈 화면 웹앱과 브라우저 탭은 저장소가 따로일 수 있다).
- `메뉴` 버튼이 실수로 눌리지 않는지(필요하면 확인창을 넣는다).
`main` 병합은 사용자가 말할 때만 한다.

---

## 스펙 대비 정리

- **`Records.time_result_text`:** 스펙 5절 표에 없는 함수 하나를 더했다. 결과 문구를 순수 함수로 두어 `Main` 없이 문구를 검사하려는 것이다.
- **`Records.judge_score`:** 스펙 6절 문구대로 기록이 없으면 `NONE` 을 돌려준다. 첫 기록 저장은 `Main._update_best_score` 가 `game.score <= best_score` 로 따로 한다.
- **작업 순서:** 스펙 7절은 `Title` 을 `Hud` 보다 먼저 두었지만, 각 작업이 끝날 때마다 전체 테스트가 통과하도록 `Hud` → `Main`(방식 로직) → `Title`(화면 + 연결) 순서로 바꿨다. `Title.Mode` 열거만 Task 3 에서 먼저 만든다.
- **HUD 가운데 글자 위치:** 레벨 글자의 왼쪽 끝을 262 에서 190(폭 180, 가운데 맞춤)으로 옮겼다. `타임어택` 네 글자가 오른쪽 소리 버튼과 겹치지 않게 하려는 것이고, 기존 방식의 `레벨 N` 도 같이 옮겨진다.
- **오디오 `.import` 정리:** 소리 작업 때 빠뜨린 파일을 Task 1 첫머리에서 따로 커밋한다(스펙 외 정리).
- 스펙의 나머지(방식 선택 흐름, 타임어택 규칙, 기존 방식 최고 점수, 기록 저장 형식과 유지 조건, 구조, 테스트, 확인할 것, 뺀 것)는 Task 1~6 이 모두 구현·확인한다.
