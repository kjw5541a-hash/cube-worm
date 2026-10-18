# 콤보 배율과 황금 벌레 구현 계획

> **실행하는 쪽에게:** REQUIRED SUB-SKILL: 사용자가 고른 방식에 따라 `superpowers:executing-plans`(인라인) 또는 `superpowers:subagent-driven-development` 로 작업을 하나씩 구현한다. 단계는 체크박스(`- [ ]`)로 추적한다. 서브에이전트는 사용자가 시킬 때만 쓴다.

**Goal:** 기존 방식(레벨 진행)의 점수에 연속 먹기 배율(콤보)과, 콤보 ×3 보상으로 잠깐 나타나는 황금 벌레를 넣는다.

**Architecture:** 규칙은 전부 `Game`(RefCounted, 노드 없음) 안에 둔다. 콤보·황금 벌레의 남은 시간은 `elapsed` 와 같은 규칙(실행 중이고 맵 회전 중이 아닐 때만)으로 줄어든다. `FieldView`·`FloorGauge`·`Hud`·`Sfx` 는 `Game` 상태를 읽기만 하고, `Main` 이 기존 방식 판에서만 `game.golden` 을 켠다. 타임어택은 황금 벌레도 콤보 줄도 없다.

**Tech Stack:** Godot 4.7.2 GDScript(헤드리스 테스트 `./run_tests.sh`), Blender 헤드리스(모델 GLB), Python 3 + ffmpeg(효과음 합성), GitHub Pages 배포.

**Spec:** `docs/superpowers/specs/2026-10-18-cube-worm-combo-gold-design.md`

**검증:** 이 계획의 편집 블록은 저장소 복사본(저장소 밖)에 글자 그대로 적용해, 작업 1~6 마다 단일 테스트와 전체 테스트(21개)가 통과하는 것을 확인했다(2026-10-18). 실패 확인(RED)도 작업마다 봤다. Task 7 의 스크린샷 스크립트도 그 복사본에서 돌려 PNG 를 확인했다.

## Global Constraints

- Godot 4.7.2, GDScript(탭 들여쓰기), Compatibility 렌더러, 웹 내보내기. 테스트는 헤드리스 `SceneTree` 스크립트이고 `./run_tests.sh` 가 돌린다. 통과 조건: `<이름>: OK` 한 줄이 있고 `SCRIPT ERROR` 가 하나도 없다.
- `Game`·`Field`·`Worm` 은 노드 없는 `RefCounted` 다. `Game` 은 방식(기존/타임어택)을 모른다. 방식 구분은 `Main` 이 한다.
- 조정값은 전부 `scripts/tuning.gd` 에 둔다. 다른 파일은 읽기만 한다.
- 코드 주석과 화면 글자는 한국어. 화면에 나가는 글자는 프로젝트 폰트(`assets/fonts/NotoSansKR-hangul.ttf`)에 있어야 한다(`tests/test_font.gd` 가 지킨다). `×` 는 폰트에 있다.
- 기존 효과음 `.ogg` 11개와 `bgm.ogg`, 기존 모델 `.glb` 10개는 바꾸지 않는다. `SaveData`·저장 형식·`best_score` 키·`TIME_LAYOUT_VERSION`(2)도 바꾸지 않는다.
- 타임어택의 판 생성·속도 규칙은 바꾸지 않는다.
- `git add` 는 파일 이름을 하나씩 적는다(`git add -A`, `git add .` 금지). 커밋 메시지는 한국어이고, 끝에 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` 를 붙인다.
- 작업은 브랜치 `combo-gold`(time-attack-random 의 2522fa7 위)에서 한다. main 에 병합하지 않는다.
- 편집·쓰기·Bash 첫 호출에서 GateGuard 훅이 사실 진술을 요구하면 진술하고 같은 호출을 다시 한다.

## Review Focus

스펙이 암시하지만 기본 테스트로는 안 드러나는 입력·실패 방식. 줄마다 그 코드를 가진 작업이 테스트로 고정한다.

- 빈 칸이 하나도 없는 판에서 연속 3 이 되면: 오류 없이 황금 벌레만 안 나온다. (Task 1 `_test_gold_limits`)
- 앞의 황금 벌레가 남아 있는데 새 콤보가 3 이 되면: 하나 더 나오지 않는다. (Task 1 `_test_gold_limits`)
- 맵 회전 중(`paused`)과 출발 전에는: 콤보·황금 벌레 시간이 흐르지 않는다. (Task 1 `_test_combo_timer`, `_test_gold_appears`)
- 클리어하면 남은 황금 벌레가 사라지고, 죽으면 그 자리에 멈춘다. 두 경우 모두 HUD 콤보 줄은 숨는다. (Task 1 `_test_gold_limits`, Task 6)
- 소리를 끈 상태에서 벌레를 먹거나 황금 벌레가 나타나면: 소리도 오류도 없다. (Task 2 `_test_play_and_mute`, Task 6)
- 연속 수가 `COMBO_MAX` 를 넘는 값, 남은 시간 비율이 1 을 넘는 값이 와도: 음높이·배율·막대가 상한에서 멈춘다. (Task 2, 5, 6)
- 타임어택에서는: 황금 벌레도 콤보 줄도 없다. (Task 6)

## 공통 명령

- 전체 테스트: 저장소 루트에서 `./run_tests.sh`. 마지막 줄이 `전체 통과` 여야 한다.
- 테스트 하나(`test_game` 은 예):

```bash
perl -e 'alarm 40; exec @ARGV' /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_game.gd 2>&1 | grep -E -A1 "SCRIPT ERROR|test_game: OK" | head -30
```

  통과하면 `test_game: OK` 한 줄만 나온다. 실패하면 `SCRIPT ERROR` 줄이 나온다. 종료할 때 찍히는 `leaked`·`still in use` 경고는 무시한다(grep 에 안 걸린다).
- 에셋(`.ogg`, `.glb`)을 새로 만든 뒤에는 Godot 임포트를 한 번 돌린다: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`. `./run_tests.sh` 도 첫머리에서 같은 일을 한다. `.import` 파일이 새로 생기면 에셋과 같이 커밋한다.

## 시작 전

- [ ] 브랜치와 바탕을 확인한다.

```bash
git branch --show-current && git status --short && git log --oneline -3
```

  기대: `combo-gold`, `?? .superpowers/` 한 줄만, 로그 맨 위에 `계획: 콤보 배율과 황금 벌레 구현 계획서` 커밋과 그 아래 `b726371 스펙: 콤보 배율과 황금 벌레(기존 방식)`.
- [ ] `./run_tests.sh` 가 `전체 통과` 인지 확인한다(바탕이 초록이어야 이후 실패가 내 것이다).

## 파일 구조

| 파일 | 변경 | 작업 |
|---|---|---|
| `scripts/tuning.gd` | 콤보·황금 규칙 상수, 황금 연출 상수 | 1, 4 |
| `scripts/game.gd` | `GOLD`, `gold_appeared`, `golden`·`combo`·`combo_left`·`gold_cell`·`gold_left`, 두 타이머, 먹기·나타남 | 1 |
| `scripts/audio.gd` | 실제 시간 콤보 삭제, `play_eat(kind, combo)`, `combo_pitch(combo)`, 소리 이름 둘 | 2 |
| `tools/audio/synth.py` | `eat_3`·`gold` 합성, 이름을 주면 그 소리만 쓰기 | 2 |
| `assets/audio/eat_3.ogg`, `gold.ogg` (+`.import`) | 새 파일 | 2 |
| `assets/blender/bugs.py`, `build_all.py` | `KINDS["gold"]`, 설명 글 | 3 |
| `assets/models/grub_gold.glb` (+`.import`) | 새 파일 | 3 |
| `scripts/skins.gd` | `GOLD` | 3 |
| `scripts/field_view.gd` | 황금 벌레·고리·기둥·유령, 깜빡임·회전·발광, 고리·기둥 도우미 | 4 |
| `scripts/floor_gauge.gd` | `gold_layer`, 금색 점 | 4 |
| `scripts/hud.gd` | `set_combo`, 콤보 글자·막대 | 5 |
| `scripts/main.gd` | `play_eat(kind, game.combo)`(2), `golden`·`gold_appeared`·콤보 줄·황금 색(6) | 2, 6 |
| `tests/test_game.gd`, `test_audio.gd`, `test_models.gd`, `test_skins.gd`, `test_field_view.gd`, `test_floor_gauge.gd`, `test_hud.gd`, `test_modes_flow.gd` | 각 작업의 테스트 | 1~6 |

### Task 1: 조정값과 Game 규칙(콤보·황금 벌레)

**Files:**
- Modify: `scripts/tuning.gd`, `scripts/game.gd`
- Test: `tests/test_game.gd`

**Interfaces:**
- Produces(뒤 작업이 쓴다):
  - `Tuning.COMBO_WINDOW`(3.0), `COMBO_MAX`(5), `GOLD_AT`(3), `GOLD_TIME`(5.0), `GOLD_SCORE`(5)
  - `Game.GOLD`(= `Tuning.BUG_COUNT` = 3), 신호 `gold_appeared(cell: Vector3i)`
  - `Game.golden: bool`, `combo: int`, `combo_left: float`, `gold_cell: Vector3i`, `gold_left: float`
  - 신호 `ate(kind, points, cell)` 의 `points` 는 연속 배율을 곱한 값이고, 황금 벌레면 `kind == Game.GOLD`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

**편집 `tests/test_game.gd`**

바꿀 곳:

```gdscript
	_test_elapsed()
	_test_new_game_layout()
```

바꾼 뒤:

```gdscript
	_test_elapsed()
	_test_combo_multiplies()
	_test_combo_timer()
	_test_gold_appears()
	_test_gold_eat()
	_test_gold_limits()
	_test_new_game_layout()
```

**편집 `tests/test_game.gd`**

기존 `_test_clear` 는 벌레 둘을 잇달아 먹으므로 둘째가 ×2 가 된다.

바꿀 곳:

```gdscript
	assert(g.score == Tuning.BUG_SCORES[0] + Tuning.BUG_SCORES[1], "점수는 종류별 그대로")
```

바꾼 뒤:

```gdscript
	assert(g.score == Tuning.BUG_SCORES[0] + Tuning.BUG_SCORES[1] * 2, "점수는 종류별 점수 × 연속 수(둘째는 ×2)")
```

**편집 `tests/test_game.gd`**

바꿀 곳:

```gdscript
	var at_death := d.elapsed
	d.advance(1.0)
	assert(d.elapsed == at_death, "죽은 뒤에는 시계가 멈춘다")
```

바꾼 뒤:

```gdscript
	var at_death := d.elapsed
	d.advance(1.0)
	assert(d.elapsed == at_death, "죽은 뒤에는 시계가 멈춘다")

# 콤보: COMBO_WINDOW 안에 이어 먹으면 연속 수가 오르고, 점수는 벌레 점수 × 연속 수다. 연속 수는 COMBO_MAX 에서 멈춘다.
func _test_combo_multiplies() -> void:
	var g := _clean()
	_bugs(g, [[Vector3i(3, 4, 4), 0], [Vector3i(2, 4, 4), 1], [Vector3i(1, 4, 4), 2], [Vector3i(7, 7, 7), 0]])
	var got := []
	g.ate.connect(func(_kind: int, points: int, _cell: Vector3i) -> void: got.append(points))
	assert(g.combo == 0 and g.combo_left == 0.0, "새 판에는 콤보가 없다")
	_go(g, -X)
	_one_step(g)
	assert(g.combo == 1 and is_equal_approx(g.combo_left, Tuning.COMBO_WINDOW), "첫 벌레: 연속 1, 시간이 꽉 찬다")
	_one_step(g)
	_one_step(g)
	assert(g.combo == 3, "이어 먹으면 연속 수가 오른다: %d" % g.combo)
	assert(got == [1, 4, 9], "점수 = 벌레 점수(1·2·3) × 연속 수(1·2·3): %s" % [got])
	assert(g.score == 14, "크림→더듬이→반딧불 순서로 이어 먹으면 14점: %d" % g.score)
	var m := _clean()
	_bugs(m, [[Vector3i(3, 4, 4), 2], [Vector3i(7, 7, 7), 0]])
	m.combo = Tuning.COMBO_MAX
	m.combo_left = Tuning.COMBO_WINDOW
	_go(m, -X)
	_one_step(m)
	assert(m.combo == Tuning.COMBO_MAX and m.score == Tuning.BUG_SCORES[2] * Tuning.COMBO_MAX, "연속 수와 배율은 COMBO_MAX 에서 멈춘다: %d" % m.score)

# 콤보 시간은 실행 중에만 흐른다: 대기 중·맵 회전 중(paused)에는 서 있고, 다하면 연속 수가 0 이 되어 다음 벌레는 1부터 센다.
func _test_combo_timer() -> void:
	var g := _clean()
	_bugs(g, [[Vector3i(3, 4, 4), 0], [Vector3i(1, 4, 4), 2], [Vector3i(7, 7, 7), 0]])
	_go(g, -X)
	_one_step(g)
	assert(g.combo == 1, "첫 벌레")
	g.paused = true
	g.advance(2.0)
	assert(g.combo == 1 and is_equal_approx(g.combo_left, Tuning.COMBO_WINDOW), "맵이 도는 동안(paused)에는 콤보 시간이 멈춘다")
	g.paused = false
	g.advance(2.9)
	assert(g.combo == 1 and is_equal_approx(g.combo_left, Tuning.COMBO_WINDOW - 2.9), "시간이 줄어도 남아 있는 동안 연속 수는 그대로: %f" % g.combo_left)
	g.advance(0.2)
	assert(g.combo == 0 and g.combo_left == 0.0, "시간이 다하면 콤보가 끊긴다")
	_one_step(g)
	_one_step(g)
	assert(g.combo == 1 and g.score == 1 + Tuning.BUG_SCORES[2], "끊긴 뒤 먹으면 다시 연속 1(×1): 점수 %d" % g.score)
	var w := _clean()
	w.combo = 2
	w.combo_left = 1.0
	w.advance(0.5)
	assert(w.combo_left == 1.0, "출발 전(대기 중)에는 시간이 흐르지 않는다")

# 황금 벌레: golden 판에서 연속 수가 GOLD_AT 이 되는 순간 빈 칸 하나에 나온다. 같은 시드면 같은 칸이고, GOLD_TIME 뒤 사라진다.
func _test_gold_appears() -> void:
	var row := [[Vector3i(3, 4, 4), 0], [Vector3i(2, 4, 4), 1], [Vector3i(1, 4, 4), 2], [Vector3i(7, 7, 7), 0]]
	var off := _clean()
	_bugs(off, row)
	_go(off, -X)
	for i in 3:
		_one_step(off)
	assert(off.combo == Tuning.GOLD_AT and off.gold_left == 0.0, "golden 이 꺼진 판에는 황금 벌레가 없다")
	var g := _clean()
	g.golden = true
	_bugs(g, row)
	var events := []
	g.ate.connect(func(_kind: int, _points: int, _cell: Vector3i) -> void: events.append("ate"))
	g.gold_appeared.connect(func(cell: Vector3i) -> void: events.append(cell))
	_go(g, -X)
	_one_step(g)
	_one_step(g)
	assert(events == ["ate", "ate"] and g.gold_left == 0.0, "연속 %d 이 되기 전에는 나오지 않는다" % Tuning.GOLD_AT)
	_one_step(g)
	assert(events.size() == 4 and events[2] == "ate" and events[3] == g.gold_cell, "연속 %d 이 되면 ate 신호 다음에 한 번 나온다: %s" % [Tuning.GOLD_AT, events])
	assert(g.gold_left == Tuning.GOLD_TIME, "GOLD_TIME 동안 머문다")
	var c := g.gold_cell
	assert(g.field.in_bounds(c) and not g.field.has_rock(c) and not g.field.has_bug(c) and not g.worm.cell_set().has(c), "빈 칸에 나온다: %s" % [c])
	assert(g.field.bugs.size() == 1, "황금 벌레는 field.bugs 에 넣지 않는다")
	var same := _clean()
	same.golden = true
	_bugs(same, row)
	_go(same, -X)
	for i in 3:
		_one_step(same)
	assert(same.gold_cell == c, "같은 시드면 같은 칸에 나온다")
	g.advance(Tuning.GOLD_TIME - 0.1)
	assert(is_equal_approx(g.gold_left, 0.1), "황금 벌레 시간이 줄어든다: %f" % g.gold_left)
	g.paused = true
	g.advance(1.0)
	assert(is_equal_approx(g.gold_left, 0.1), "맵이 도는 동안에는 시간이 멈춘다")
	g.paused = false
	g.advance(0.2)
	assert(g.gold_left == 0.0, "GOLD_TIME 이 지나면 사라진다")

# 황금 벌레를 먹으면 GOLD_SCORE × 연속 수, 일반 벌레처럼 자라고 빨라지고 콤보가 이어진다. 클리어 조건에는 세지 않는다.
func _test_gold_eat() -> void:
	var g := _clean()
	_bugs(g, [[Vector3i(7, 7, 7), 0]])
	g.gold_cell = Vector3i(3, 4, 4)
	g.gold_left = Tuning.GOLD_TIME
	g.combo = 3
	g.combo_left = Tuning.COMBO_WINDOW
	var got := []
	g.ate.connect(func(kind: int, points: int, cell: Vector3i) -> void: got.append([kind, points, cell]))
	_go(g, -X)
	_one_step(g)
	assert(got == [[Game.GOLD, Tuning.GOLD_SCORE * 4, Vector3i(3, 4, 4)]], "황금 벌레는 연속 4번째라 ×4: %s" % [got])
	assert(g.score == Tuning.GOLD_SCORE * 4 and g.combo == 4 and g.gold_left == 0.0, "점수가 오르고 콤보가 이어지고 황금 벌레가 사라진다")
	assert(g.worm.length() == 4 and g.just_grew, "한 마디 자란다")
	assert(is_equal_approx(g.speed, Tuning.SPEED_START + Tuning.SPEED_STEP), "속도도 오른다")
	assert(g.eaten_kind == Game.GOLD and g.eaten_cell == Vector3i(3, 4, 4), "먹은 연출 기록")
	assert(g.state == Game.State.RUNNING and g.field.bugs.size() == 1, "클리어 조건에는 세지 않는다")
	var late := _clean()
	_bugs(late, [[Vector3i(7, 7, 7), 0]])
	late.gold_cell = Vector3i(3, 4, 4)
	late.gold_left = Tuning.GOLD_TIME
	_go(late, -X)
	_one_step(late)
	assert(late.score == Tuning.GOLD_SCORE and late.combo == 1, "콤보가 끊긴 뒤에 먹으면 ×1: %d" % late.score)

# 황금 벌레가 못 나오는 때와 사라지는 때: 앞의 황금 벌레가 남아 있을 때, 빈 칸이 없을 때(오류 없이),
# 연속 수를 만든 벌레가 마지막일 때. 클리어하면 남은 황금 벌레도 사라지고, 죽으면 그 자리에 남는다.
func _test_gold_limits() -> void:
	var row := [[Vector3i(3, 4, 4), 0], [Vector3i(7, 7, 7), 0]]
	var fired := [0]
	var busy := _clean()
	busy.golden = true
	_bugs(busy, row)
	busy.gold_cell = Vector3i(6, 6, 6)
	busy.gold_left = 4.0
	busy.combo = Tuning.GOLD_AT - 1
	busy.combo_left = Tuning.COMBO_WINDOW
	busy.gold_appeared.connect(func(_cell: Vector3i) -> void: fired[0] += 1)
	_go(busy, -X)
	_one_step(busy)
	assert(busy.combo == Tuning.GOLD_AT and fired[0] == 0 and busy.gold_cell == Vector3i(6, 6, 6), "앞의 황금 벌레가 남아 있으면 하나 더 나오지 않는다")
	var full := _clean()
	full.golden = true
	_bugs(full, row)
	for cell in full.field.empty_cells(full.worm.cell_set()):
		full.field.rocks[cell] = true
	full.combo = Tuning.GOLD_AT - 1
	full.combo_left = Tuning.COMBO_WINDOW
	full.gold_appeared.connect(func(_cell: Vector3i) -> void: fired[0] += 1)
	_go(full, -X)
	_one_step(full)
	assert(full.combo == Tuning.GOLD_AT and full.gold_left == 0.0 and fired[0] == 0, "빈 칸이 없으면 오류 없이 나오지 않는다")
	var last := _clean()
	last.golden = true
	_bugs(last, [[Vector3i(3, 4, 4), 0], [Vector3i(2, 4, 4), 1], [Vector3i(1, 4, 4), 2]])
	last.gold_appeared.connect(func(_cell: Vector3i) -> void: fired[0] += 1)
	_go(last, -X)
	for i in 3:
		_one_step(last)
	assert(last.state == Game.State.CLEARED and last.combo == Tuning.GOLD_AT and fired[0] == 0 and last.gold_left == 0.0, "연속 수를 만든 벌레가 마지막이면 클리어이고 황금 벌레는 나오지 않는다")
	var rest := _clean()
	_bugs(rest, [[Vector3i(3, 4, 4), 0]])
	rest.gold_cell = Vector3i(6, 6, 6)
	rest.gold_left = 4.0
	_go(rest, -X)
	_one_step(rest)
	assert(rest.state == Game.State.CLEARED and rest.gold_left == 0.0, "클리어하면 남은 황금 벌레도 사라진다")
	var dead := _clean(Vector3i(0, 4, 4))
	dead.gold_cell = Vector3i(6, 6, 6)
	dead.gold_left = 4.0
	_go(dead, -X)
	_one_step(dead)
	assert(dead.state == Game.State.DEAD, "벽에 부딪혀 죽었다")
	var left := dead.gold_left
	dead.advance(1.0)
	assert(dead.gold_left == left and dead.gold_cell == Vector3i(6, 6, 6), "죽은 뒤에는 시간이 서고 황금 벌레는 그 자리에 남는다")
```

- [ ] **Step 2: 실패를 확인한다**

공통 명령의 "테스트 하나" 를 `test_game` 으로 돌린다.

기대: `SCRIPT ERROR` 줄이 나온다(`combo`·`golden` 같은 속성이 아직 없다). `test_game: OK` 는 없다.

- [ ] **Step 3: 구현한다**

**편집 `scripts/tuning.gd`**

바꿀 곳:

```gdscript
const QUEUE_MAX := 2
```

바꾼 뒤:

```gdscript
const QUEUE_MAX := 2

# 콤보와 황금 벌레(기존 방식의 점수). 둘 다 실행 중(맵 회전 중 제외)에만 시간이 흐른다.
const COMBO_WINDOW := 3.0                   # 벌레를 먹고 이 시간(초) 안에 다음 벌레를 먹으면 연속
const COMBO_MAX := 5                        # 연속 수(= 점수 배율)의 상한
const GOLD_AT := 3                          # 연속 수가 이 값이 되는 순간 황금 벌레가 나온다
const GOLD_TIME := 5.0                      # 황금 벌레가 머무는 시간(초)
const GOLD_SCORE := 5                       # 황금 벌레의 기본 점수(연속 수를 곱한다)
```

**편집 `scripts/game.gd`**

바꿀 곳:

```gdscript
# 규칙 전부: 입력 큐, 진행률, 걸음, 먹기, 죽음. 노드를 쓰지 않아 헤드리스로 검사한다.
```

바꾼 뒤:

```gdscript
# 규칙 전부: 입력 큐, 진행률, 걸음, 먹기(콤보·황금 벌레), 죽음. 노드를 쓰지 않아 헤드리스로 검사한다.
```

**편집 `scripts/game.gd`**

바꿀 곳:

```gdscript
enum State { WAITING, RUNNING, DEAD, CLEARED }

# 벌레를 먹은 순간(걸음 이벤트 안). 종류, 얻은 점수, 먹은 칸.
signal ate(kind: int, points: int, cell: Vector3i)
# 판의 벌레를 전부 먹었다.
signal cleared
```

바꾼 뒤:

```gdscript
enum State { WAITING, RUNNING, DEAD, CLEARED }

# 황금 벌레의 종류 번호: 일반 종류(0 ~ BUG_COUNT-1) 다음 번호다. ate 신호의 kind 로 온다.
const GOLD := Tuning.BUG_COUNT

# 벌레를 먹은 순간(걸음 이벤트 안). 종류, 얻은 점수(연속 배율을 곱한 값), 먹은 칸.
signal ate(kind: int, points: int, cell: Vector3i)
# 판의 일반 벌레를 전부 먹었다(황금 벌레는 세지 않는다).
signal cleared
# 황금 벌레가 나타났다(같은 걸음의 ate 신호 다음). 나타난 칸.
signal gold_appeared(cell: Vector3i)
```

**편집 `scripts/game.gd`**

바꿀 곳:

```gdscript
var eaten_kind := -1            # 가장 최근에 먹은 벌레의 종류
```

바꾼 뒤:

```gdscript
var eaten_kind := -1            # 가장 최근에 먹은 벌레의 종류
var golden := false             # 황금 벌레를 쓰는 판인가(기존 방식 판만 Main 이 켠다)
var combo := 0                  # 이어지는 연속 먹기 수(0 = 없음). 연속 n 번째로 먹은 벌레의 점수 배율이 n 이다
var combo_left := 0.0           # 콤보를 이을 수 있는 남은 시간(초). 0 이 되면 combo 도 0
var gold_cell := Vector3i.ZERO  # 황금 벌레의 칸(gold_left > 0 일 때만 뜻이 있다). field.bugs 에는 넣지 않는다
var gold_left := 0.0            # 황금 벌레가 사라지기까지 남은 시간(초). 0 = 없음
```

**편집 `scripts/game.gd`**

바꿀 곳:

```gdscript
	elapsed += delta
	alpha += minf(speed * delta, Tuning.MAX_STEP_PER_FRAME)
```

바꾼 뒤:

```gdscript
	elapsed += delta
	_tick_timers(delta)
	alpha += minf(speed * delta, Tuning.MAX_STEP_PER_FRAME)
```

**편집 `scripts/game.gd`**

바꿀 곳:

```gdscript
	just_grew = field.has_bug(next)
	var kind := -1
	var points := 0
	if just_grew:
		kind = field.kind_at(next)
		points = Tuning.BUG_SCORES[kind]
		field.remove_bug(next)
		score += points
		speed = minf(speed + Tuning.SPEED_STEP, Tuning.SPEED_MAX)
		eat_steps.append(steps)
		eaten_cell = next
		eaten_kind = kind
	worm.step(just_grew)
	if just_grew:
		ate.emit(kind, points, next)
		if field.bugs.is_empty():
			state = State.CLEARED
			cleared.emit()
```

바꾼 뒤:

```gdscript
	var at_gold := gold_left > 0.0 and next == gold_cell
	just_grew = at_gold or field.has_bug(next)
	var kind := -1
	var points := 0
	if just_grew:
		kind = GOLD if at_gold else field.kind_at(next)
		# 콤보: 시간이 남아 있으면 연속 수가 오르고, 아니면 1부터 다시 센다. 점수는 기본 점수 × 연속 수.
		combo = mini(combo + 1, Tuning.COMBO_MAX) if combo_left > 0.0 else 1
		combo_left = Tuning.COMBO_WINDOW
		if at_gold:
			points = Tuning.GOLD_SCORE * combo
			gold_left = 0.0
		else:
			points = Tuning.BUG_SCORES[kind] * combo
			field.remove_bug(next)
		score += points
		speed = minf(speed + Tuning.SPEED_STEP, Tuning.SPEED_MAX)
		eat_steps.append(steps)
		eaten_cell = next
		eaten_kind = kind
	worm.step(just_grew)
	if just_grew:
		ate.emit(kind, points, next)
		if field.bugs.is_empty():
			gold_left = 0.0
			state = State.CLEARED
			cleared.emit()
		elif golden and combo == Tuning.GOLD_AT and gold_left == 0.0:
			_spawn_gold()
```

**편집 `scripts/game.gd`**

바꿀 곳:

```gdscript
	worm.head_exit = Worm.turned(queue.pop_front(), worm.entries[0], worm.refs[0]) if not queue.is_empty() else worm.entries[0]
```

바꾼 뒤:

```gdscript
	worm.head_exit = Worm.turned(queue.pop_front(), worm.entries[0], worm.refs[0]) if not queue.is_empty() else worm.entries[0]

# 콤보와 황금 벌레의 남은 시간을 줄인다(실행 중이고 맵 회전 중이 아닐 때만 부른다).
# 콤보 시간이 다하면 연속 수가 0 이 되고, 황금 벌레 시간이 다하면 황금 벌레가 사라진다.
func _tick_timers(delta: float) -> void:
	if combo_left > 0.0:
		combo_left = maxf(combo_left - delta, 0.0)
		if combo_left == 0.0:
			combo = 0
	if gold_left > 0.0:
		gold_left = maxf(gold_left - delta, 0.0)

# 빈 칸(바위·벌레·지렁이 몸이 없는 칸) 하나에 황금 벌레를 놓는다. 빈 칸이 없으면 놓지 않는다.
func _spawn_gold() -> void:
	var free := field.empty_cells(worm.cell_set())
	if free.is_empty():
		return
	gold_cell = free[field.rng.randi_range(0, free.size() - 1)]
	gold_left = Tuning.GOLD_TIME
	gold_appeared.emit(gold_cell)
```

- [ ] **Step 4: 통과를 확인한다**

공통 명령의 "테스트 하나" 를 `test_game` 으로 돌린다. 기대: `test_game: OK` 한 줄.

- [ ] **Step 5: 전체 테스트**

`./run_tests.sh` → 마지막 줄 `전체 통과`.

- [ ] **Step 6: 커밋한다**

```bash
git add scripts/tuning.gd scripts/game.gd tests/test_game.gd
git commit -m "콤보 배율과 황금 벌레 규칙을 Game 에 넣는다(기존 방식 점수)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 2: 먹는 소리를 게임 콤보에 맞추고 새 소리 둘을 더한다

**Files:**
- Modify: `scripts/audio.gd`, `scripts/main.gd`(한 줄), `tools/audio/synth.py`
- Create: `assets/audio/eat_3.ogg`, `assets/audio/gold.ogg`(+ 임포트가 만드는 `.import`)
- Test: `tests/test_audio.gd`

**Interfaces:**
- Consumes: `Game.combo`, `Game.GOLD`, `Tuning.COMBO_MAX`(Task 1)
- Produces:
  - `Sfx.play_eat(kind: int, combo: int) -> void`(둘째 인자 필수), `Sfx.combo_pitch(combo: int) -> float`(`Sfx.COMBO_WINDOW`·`Sfx.COMBO_MAX`는 없어진다)
  - 소리 이름 `eat_3`(황금 벌레를 먹는 소리), `gold`(황금 벌레가 나타나는 소리)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

**편집 `tests/test_audio.gd`**

바꿀 곳:

```gdscript
	assert(names.size() == 12, "효과음 11개 + BGM")
```

바꾼 뒤:

```gdscript
	assert(names.size() == 14, "효과음 13개 + BGM")
```

**편집 `tests/test_audio.gd`**

바꿀 곳:

```gdscript
func _test_combo_pitch() -> void:
	assert(Sfx.combo_pitch(0) == 1.0, "0 단계는 원래 음")
	assert(is_equal_approx(Sfx.combo_pitch(1), pow(2.0, 2.0 / 12.0)), "한 단계는 온음(반음 두 개) 위")
	assert(Sfx.combo_pitch(2) > Sfx.combo_pitch(1), "단계가 오를수록 높다")
	assert(Sfx.combo_pitch(99) == Sfx.combo_pitch(Sfx.COMBO_MAX), "최대 단계에서 멈춘다")
	assert(Sfx.combo_pitch(-3) == 1.0, "음수 단계는 원래 음")
```

바꾼 뒤:

```gdscript
func _test_combo_pitch() -> void:
	assert(Sfx.combo_pitch(1) == 1.0, "연속 1번째는 원래 음")
	assert(Sfx.combo_pitch(0) == 1.0 and Sfx.combo_pitch(-3) == 1.0, "연속 수가 없거나 음수여도 원래 음")
	assert(is_equal_approx(Sfx.combo_pitch(2), pow(2.0, 2.0 / 12.0)), "한 번 이을 때마다 온음(반음 두 개) 위")
	assert(Sfx.combo_pitch(3) > Sfx.combo_pitch(2), "연속 수가 오를수록 높다")
	assert(Sfx.combo_pitch(99) == Sfx.combo_pitch(Tuning.COMBO_MAX), "COMBO_MAX 에서 멈춘다")
```

**편집 `tests/test_audio.gd`**

바꿀 곳:

```gdscript
	s.play_eat(0)
```

바꾼 뒤:

```gdscript
	s.play_eat(0, 1)
```

**편집 `tests/test_audio.gd`**

바꿀 곳:

```gdscript
func _test_eat_combo() -> void:
	var s := _sfx()
	s.play_eat(1, 100.0)
	assert(s.last_id == "eat_1" and s.last_pitch == 1.0, "첫 먹기는 원래 음")
	s.play_eat(1, 101.0)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(1)), "2초 안에 이어 먹으면 한 단계 위")
	s.play_eat(2, 102.5)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(2)) and s.last_id == "eat_2", "계속 이으면 한 단계 더(종류는 그대로 따른다)")
	for i in 10:
		s.play_eat(0, 103.0 + i)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(Sfx.COMBO_MAX)), "최대 단계를 넘지 않는다")
	s.play_eat(0, 200.0)
	assert(s.last_pitch == 1.0, "2초 넘게 쉬면 처음으로 돌아간다")
	s.queue_free()
```

바꾼 뒤:

```gdscript
# 먹는 소리: 종류가 소리를 고르고, 게임이 알려 준 연속 수가 음높이를 정한다(화면의 점수 배율과 같이 오른다).
func _test_eat_combo() -> void:
	var s := _sfx()
	s.play_eat(1, 1)
	assert(s.last_id == "eat_1" and s.last_pitch == 1.0, "연속 1번째는 원래 음")
	s.play_eat(1, 2)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(2)), "연속 2번째는 한 단계 위")
	s.play_eat(2, 3)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(3)) and s.last_id == "eat_2", "계속 이으면 한 단계 더(종류는 그대로 따른다)")
	s.play_eat(0, Tuning.COMBO_MAX + 7)
	assert(is_equal_approx(s.last_pitch, Sfx.combo_pitch(Tuning.COMBO_MAX)), "COMBO_MAX 를 넘지 않는다")
	s.play_eat(Game.GOLD, 1)
	assert(s.last_id == "eat_3", "황금 벌레는 eat_3 소리")
	s.play("gold")
	assert(s.last_id == "gold", "황금 벌레가 나타나는 소리")
	s.queue_free()
```

- [ ] **Step 2: 실패를 확인한다**

공통 명령의 "테스트 하나" 를 `test_audio` 로 돌린다. 기대: `SCRIPT ERROR` 줄이 나온다(`play_eat` 인자·소리 파일이 아직 안 맞는다). `test_audio: OK` 는 없다.

- [ ] **Step 3: 새 소리를 합성한다**

**편집 `tools/audio/synth.py`**

바꿀 곳:

```python
"""소리를 합성해 assets/audio/*.ogg 로 쓴다. 사용: python3 tools/audio/synth.py"""
```

바꾼 뒤:

```python
"""소리를 합성해 assets/audio/*.ogg 로 쓴다. 사용: python3 tools/audio/synth.py [소리 이름 ...]
이름을 주면 그 소리만 쓴다(다른 .ogg 는 건드리지 않는다). 없으면 전부 쓴다."""
```

**편집 `tools/audio/synth.py`**

바꿀 곳:

```python
SOUNDS = {
    "eat_0": eat(392),
```

바꾼 뒤:

```python
def gold_eat():
    # 반짝: 높은 두 음이 이어 울린다 + 아주 짧은 쩝
    return mix(seq([tone(1047, 0.07, 0.45, decay=4), tone(1568, 0.18, 0.5, decay=5)]), noise(0.03, 0.08))

def gold_appear():
    # 띠링: 빠르게 올라가는 세 음
    return seq([tone(784, 0.07, 0.4, "tri", decay=3), tone(988, 0.07, 0.4, "tri", decay=3), tone(1319, 0.22, 0.45, "tri", decay=3)])

SOUNDS = {
    "eat_0": eat(392),
```

**편집 `tools/audio/synth.py`**

바꿀 곳:

```python
    "bgm": bgm(),
}
```

바꾼 뒤:

```python
    "bgm": bgm(),
    # 새 소리는 표 끝에 붙인다: 앞 소리들이 쓰는 노이즈 순서(random.seed(7))가 바뀌지 않는다
    "eat_3": gold_eat(),
    "gold": gold_appear(),
}
```

**편집 `tools/audio/synth.py`**

바꿀 곳:

```python
        for name, samples in SOUNDS.items():
            wav = os.path.join(tmp, name + ".wav")
```

바꾼 뒤:

```python
        for name in sys.argv[1:] or SOUNDS:  # 이름을 주면 그 소리만 쓴다
            samples = SOUNDS[name]
            wav = os.path.join(tmp, name + ".wav")
```

**편집 `tools/audio/synth.py`**

바꿀 곳:

```python
    print("ok:", ", ".join(SOUNDS))
```

바꾼 뒤:

```python
    print("ok:", ", ".join(sys.argv[1:] or SOUNDS))
```

그다음 새 소리 둘만 만든다.

```bash
python3 tools/audio/synth.py eat_3 gold && git status --short assets/audio tools
```

기대: `ok: eat_3, gold`. 상태는 `M tools/audio/synth.py` 와 `?? assets/audio/eat_3.ogg`, `?? assets/audio/gold.ogg` 뿐이다(기존 `.ogg` 는 그대로).

- [ ] **Step 4: 소리 코드를 고친다**

**편집 `scripts/audio.gd`**

바꿀 곳:

```gdscript
const NAMES: Array[String] = ["eat_0", "eat_1", "eat_2", "turn", "up", "down", "rotate", "die", "clear", "start", "skin"]
```

바꾼 뒤:

```gdscript
const NAMES: Array[String] = ["eat_0", "eat_1", "eat_2", "eat_3", "turn", "up", "down", "rotate", "die", "clear", "start", "skin", "gold"]
```

**편집 `scripts/audio.gd`**

바꿀 곳:

```gdscript
const POOL := 6                # 한꺼번에 겹쳐 울릴 수 있는 효과음 수
const COMBO_WINDOW := 2.0      # 이 시간(초) 안에 이어 먹으면 연속
const COMBO_MAX := 4           # 연속 먹기 음 상승의 최대 단계(온음 단위)
const SFX_DB := -4.0
```

바꾼 뒤:

```gdscript
const POOL := 6                # 한꺼번에 겹쳐 울릴 수 있는 효과음 수
const SFX_DB := -4.0
```

**편집 `scripts/audio.gd`**

바꿀 곳:

```gdscript
var _next := 0
var _combo := 0
var _last_eat := -1000.0
var _music_wanted := false
```

바꾼 뒤:

```gdscript
var _next := 0
var _music_wanted := false
```

**편집 `scripts/audio.gd`**

바꿀 곳:

```gdscript
# 연속 먹기 step 단계의 음높이 배율: 단계마다 반음 두 개(온음)씩 올라간다.
static func combo_pitch(step: int) -> float:
	return pow(2.0, 2.0 * clampi(step, 0, COMBO_MAX) / 12.0)
```

바꾼 뒤:

```gdscript
# 연속 먹기 수 combo 의 음높이 배율: 연속 1번째는 원래 음, 이을 때마다 반음 두 개(온음)씩 올라 Tuning.COMBO_MAX 에서 멈춘다.
static func combo_pitch(combo: int) -> float:
	return pow(2.0, 2.0 * (clampi(combo, 1, Tuning.COMBO_MAX) - 1) / 12.0)
```

**편집 `scripts/audio.gd`**

바꿀 곳:

```gdscript
# 벌레 종류 kind 를 먹는 소리. 2초 안에 이어 먹으면 한 단계씩 높아진다. now 는 테스트가 시간을 바꿔 끼우려고 둔 값이다.
func play_eat(kind: int, now := Time.get_ticks_msec() / 1000.0) -> void:
	if now - _last_eat <= COMBO_WINDOW:
		_combo = mini(_combo + 1, COMBO_MAX)
	else:
		_combo = 0
	_last_eat = now
	play("eat_%d" % kind, combo_pitch(_combo))
```

바꾼 뒤:

```gdscript
# 벌레 종류 kind 를 먹는 소리. combo 는 게임이 센 연속 먹기 수라서, 화면의 점수 배율과 음이 같이 올라간다.
func play_eat(kind: int, combo: int) -> void:
	play("eat_%d" % kind, combo_pitch(combo))
```

**편집 `scripts/main.gd`**

바꿀 곳:

```gdscript
	sfx.play_eat(kind)
```

바꾼 뒤:

```gdscript
	sfx.play_eat(kind, game.combo)
```

- [ ] **Step 5: 임포트하고 통과를 확인한다**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import >/dev/null 2>&1; git status --short assets/audio
```

기대: 위 Step 3 의 `.ogg` 둘에 더해 `?? assets/audio/eat_3.ogg.import`, `?? assets/audio/gold.ogg.import`.

공통 명령의 "테스트 하나" 를 `test_audio` 로 돌린다. 기대: `test_audio: OK` 한 줄.

- [ ] **Step 6: 전체 테스트**

`./run_tests.sh` → 마지막 줄 `전체 통과`(`test_main_smoke` 의 `eat_1` 소리 검사 포함).

- [ ] **Step 7: 커밋한다**

```bash
git add scripts/audio.gd scripts/main.gd tools/audio/synth.py tests/test_audio.gd assets/audio/eat_3.ogg assets/audio/eat_3.ogg.import assets/audio/gold.ogg assets/audio/gold.ogg.import
git commit -m "먹는 소리의 연속 음 상승을 게임의 콤보와 합치고 황금 벌레 소리 둘을 더한다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 3: 황금 벌레 모델과 Skins.GOLD

**Files:**
- Modify: `assets/blender/bugs.py`, `assets/blender/build_all.py`(설명 글), `scripts/skins.gd`
- Create: `assets/models/grub_gold.glb`(+ 임포트가 만드는 `.import`)
- Test: `tests/test_models.gd`, `tests/test_skins.gd`

**Interfaces:**
- Consumes: `Game.GOLD`(Task 1)
- Produces: `Skins.GOLD`(Dictionary: `id`, `name`, `model`, `color`), `res://assets/models/grub_gold.glb`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

**편집 `tests/test_models.gd`**

바꿀 곳:

```gdscript
# 에셋 10개의 계약:
```

바꾼 뒤:

```gdscript
# 에셋 11개의 계약:
```

**편집 `tests/test_models.gd`**

바꿀 곳:

```gdscript
const GRUBS := ["cream", "antenna", "glow"]
```

바꾼 뒤:

```gdscript
const GRUBS := ["cream", "antenna", "glow", "gold"]
```

**편집 `tests/test_models.gd`**

바꿀 곳:

```gdscript
	assert((box.position + box.size * 0.5).length() < 0.02, "원점은 칸 중심: %s" % kind)
```

바꾼 뒤:

```gdscript
	assert((box.position + box.size * 0.5).length() < 0.02, "원점은 칸 중심: %s" % kind)
	if kind == "gold":
		assert(_has_color(m["colors"], "#FFC21A") and _has_color(m["colors"], "#FFE680"), "황금 벌레는 금색 몸·머리")
```

**편집 `tests/test_skins.gd`**

바꿀 곳:

```gdscript
	_test_bug_kinds()
	_test_worm_index()
```

바꾼 뒤:

```gdscript
	_test_bug_kinds()
	_test_gold_bug()
	_test_worm_index()
```

**편집 `tests/test_skins.gd`**

바꿀 곳:

```gdscript
	assert(colors.size() == Skins.BUGS.size(), "종류마다 색이 달라야 구별된다")
```

바꾼 뒤:

```gdscript
	assert(colors.size() == Skins.BUGS.size(), "종류마다 색이 달라야 구별된다")

# 황금 벌레는 일반 종류 목록에 없고, 번호는 그다음(Game.GOLD)이며, 색이 일반 벌레 셋과 다르다.
func _test_gold_bug() -> void:
	assert(Game.GOLD == Skins.BUGS.size(), "황금 벌레 번호는 일반 종류 다음이다")
	assert(Skins.GOLD["name"] != "" and ResourceLoader.exists(Skins.GOLD["model"]), "황금 벌레 이름과 에셋")
	for b in Skins.BUGS:
		assert(b["color"] != Skins.GOLD["color"], "황금 벌레 색이 일반 벌레와 겹친다: %s" % b["id"])
```

- [ ] **Step 2: 실패를 확인한다**

공통 명령의 "테스트 하나" 를 `test_models` 와 `test_skins` 로 각각 돌린다. 기대: 둘 다 `SCRIPT ERROR` 줄이 나온다(`grub_gold.glb` 가 없고 `Skins.GOLD` 가 없다).

- [ ] **Step 3: 모델 스크립트와 Skins 를 고친다**

**편집 `assets/blender/bugs.py`**

바꿀 곳:

```python
"""벌레(굼벵이) 3종: 작은 둥근 정육면체를 C 자로 이은 모양. 바운딩 박스 중심을 원점(칸 중심)에 둔다."""
```

바꾼 뒤:

```python
"""벌레(굼벵이) 4종(일반 3종 + 황금): 작은 둥근 정육면체를 C 자로 이은 모양. 바운딩 박스 중심을 원점(칸 중심)에 둔다."""
```

**편집 `assets/blender/bugs.py`**

바꿀 곳:

```python
    "glow": ([0.17, 0.22, 0.26, 0.29], [-95, -32, 32, 95], 0.26, "#FFF3D1", "#FFF3D1", "#FF9B3D", False),
}
```

바꾼 뒤:

```python
    "glow": ([0.17, 0.22, 0.26, 0.29], [-95, -32, 32, 95], 0.26, "#FFF3D1", "#FFF3D1", "#FF9B3D", False),
    # 황금 벌레: 크림과 같은 모양, 몸과 머리만 금색. 게임에서 Tuning.GOLD_SCALE 배로 키워 쓴다.
    "gold": ([0.21, 0.26, 0.30, 0.32], [-120, -40, 40, 120], 0.20, "#FFC21A", "#FFE680", None, False),
}
```

**편집 `assets/blender/build_all.py`**

바꿀 곳:

```python
"""에셋 10개를 만들어 assets/models/*.glb 로 내보낸다.
```

바꾼 뒤:

```python
"""에셋 11개를 만들어 assets/models/*.glb 로 내보낸다.
```

**편집 `scripts/skins.gd`**

바꿀 곳:

```gdscript
	{"id": "glow", "name": "반딧불", "model": DIR + "grub_glow.glb", "color": Color("#FF9B3D")},
]
```

바꾼 뒤:

```gdscript
	{"id": "glow", "name": "반딧불", "model": DIR + "grub_glow.glb", "color": Color("#FF9B3D")},
]

# 황금 벌레(콤보 보상으로 잠깐 나오는 큰 점수). 종류 번호는 Game.GOLD 다. color 는 고리·기둥·층 눈금 점·점수 글자의 색.
const GOLD := {"id": "gold", "name": "황금", "model": DIR + "grub_gold.glb", "color": Color("#FFE14A")}
```

- [ ] **Step 4: 모델을 만들고 임포트한다**

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python assets/blender/build_all.py 2>&1 | grep -E "grub_|BUILD_OK|Error" ; git status --short assets
```

기대: `grub_gold: 삼각형 1328, 재질 3` 줄과 `BUILD_OK`. 상태에는 새 `?? assets/models/grub_gold.glb`, 빌드가 남긴 캐시 `?? assets/blender/__pycache__/`, 그리고 기존 모델 `.glb` 몇 개의 ` M` 이 뜬다. Blender 는 같은 모양을 실행마다 바이트만 다르게 내보내서 ` M` 이 뜨는 파일은 실행마다 다르다(검증 때는 3~5개).

기존 모델은 바뀌면 안 되고 캐시는 커밋하지 않으므로 둘 다 정리한다. 새 `grub_gold.glb` 는 추적 전이라 `git checkout` 에 영향이 없다.

```bash
git checkout -- $(git diff --name-only -- assets/models)
rm -rf assets/blender/__pycache__
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import >/dev/null 2>&1; git status --short assets
```

기대: `?? assets/models/grub_gold.glb`, `?? assets/models/grub_gold.glb.import` 둘만.

- [ ] **Step 5: 통과를 확인한다**

공통 명령의 "테스트 하나" 를 `test_models` 와 `test_skins` 로 각각 돌린다. 기대: `test_models: OK`, `test_skins: OK`.

- [ ] **Step 6: 전체 테스트**

`./run_tests.sh` → 마지막 줄 `전체 통과`.

- [ ] **Step 7: 커밋한다**

```bash
git add assets/blender/bugs.py assets/blender/build_all.py assets/models/grub_gold.glb assets/models/grub_gold.glb.import scripts/skins.gd tests/test_models.gd tests/test_skins.gd
git commit -m "황금 벌레 모델과 Skins.GOLD 를 더한다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 4: 판과 층 눈금에 황금 벌레를 그린다

**Files:**
- Modify: `scripts/tuning.gd`, `scripts/field_view.gd`, `scripts/floor_gauge.gd`
- Test: `tests/test_field_view.gd`, `tests/test_floor_gauge.gd`

**Interfaces:**
- Consumes: `Game.gold_cell`·`gold_left`·`eaten_kind`, `Game.GOLD`(Task 1), `Skins.GOLD`(Task 3)
- Produces:
  - `Tuning.GOLD_SCALE`(1.3), `GOLD_SPIN`(3.0), `GOLD_BLINK`(1.5)
  - `FieldView.gold`, `gold_ring`, `gold_stem`(`MeshInstance3D`), `ghosts[Game.GOLD]`, 정적 함수 `FieldView.gold_shown(left: float) -> bool`
  - `FloorGauge.gold_layer: int`(없으면 -1)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

**편집 `tests/test_field_view.gd`**

바꿀 곳:

```gdscript
	_test_ghost_is_pulled_into_the_head()
	print("test_field_view: OK")
```

바꾼 뒤:

```gdscript
	_test_ghost_is_pulled_into_the_head()
	_test_gold_bug()
	_test_gold_blink()
	_test_gold_ghost()
	print("test_field_view: OK")
```

**편집 `tests/test_field_view.gd`**

바꿀 곳:

```gdscript
	all.append_array(fv.rock_stems)
```

바꾼 뒤:

```gdscript
	all.append_array(fv.rock_stems)
	all.append(fv.gold_ring)
	all.append(fv.gold_stem)
```

**편집 `tests/test_field_view.gd`**

바꿀 곳:

```gdscript
	g.alpha = 0.1
	g.just_grew = false
	fv._update()
	assert(not fv.ghosts[1].visible, "자라는 걸음이 아니면 숨긴다")
	fv.queue_free()
```

바꾼 뒤:

```gdscript
	g.alpha = 0.1
	g.just_grew = false
	fv._update()
	assert(not fv.ghosts[1].visible, "자라는 걸음이 아니면 숨긴다")
	fv.queue_free()

# 황금 벌레: 있을 때만 보이고, 제 크기·고리·기둥을 갖고, 제자리에서 돈다.
func _test_gold_bug() -> void:
	var g := _game()
	var fv := _view(g)
	assert(not fv.gold.visible and not fv.gold_ring.visible and not fv.gold_stem.visible, "황금 벌레가 없으면 숨는다")
	g.gold_cell = Vector3i(6, 1, 2)
	g.gold_left = Tuning.GOLD_TIME
	fv._update()
	assert(fv.gold.visible and fv.gold_ring.visible and fv.gold_stem.visible, "있으면 벌레·고리가 보이고, 다른 층이라 기둥도 있다")
	assert(fv.gold.scale.is_equal_approx(Vector3.ONE * Tuning.GOLD_SCALE), "일반 벌레보다 크다")
	assert(fv.gold_ring.scale.is_equal_approx(Vector3.ONE * Tuning.GOLD_SCALE), "고리도 벌레만큼 커서, 같은 층에서 벌레에 가려지지 않는다")
	assert(absf(fv.gold.position.x - 6.5) < 1e-4 and absf(fv.gold.position.z - 2.5) < 1e-4 and absf(fv.gold.position.y - 1.5) < 0.07, "자기 칸에 있다: %s" % fv.gold.position)
	assert(fv.gold_ring.position.distance_to(Vector3(6.5, 4.5, 2.5)) < 1e-4, "고리는 머리 층 높이, 벌레와 같은 (x, z): %s" % fv.gold_ring.position)
	var marker := fv.gold_ring.material_override as StandardMaterial3D
	assert(marker.albedo_color == Skins.GOLD["color"] and fv.gold_stem.material_override == marker, "고리·기둥은 황금 색")
	assert(fv.gold.mesh != fv.bugs[0].mesh, "황금 벌레 모양")
	var turn := fv.gold.rotation.y
	fv._process(0.1)
	assert(not is_equal_approx(fv.gold.rotation.y, turn), "제자리에서 돈다")
	g.gold_cell = Vector3i(6, 4, 2)
	fv._update()
	assert(fv.gold_ring.visible and not fv.gold_stem.visible, "머리와 같은 층이면 고리만")
	g.gold_left = 0.0
	fv._update()
	assert(not fv.gold.visible and not fv.gold_ring.visible and not fv.gold_stem.visible, "사라지면 모두 숨는다")
	fv.queue_free()

# 사라지기 직전 GOLD_BLINK 초에는 0.1초마다 숨었다 보였다 한다. 그 전에는 늘 보인다.
func _test_gold_blink() -> void:
	assert(not FieldView.gold_shown(0.0), "시간이 다하면 안 보인다")
	assert(FieldView.gold_shown(Tuning.GOLD_TIME) and FieldView.gold_shown(Tuning.GOLD_BLINK + 0.01), "깜빡이기 전에는 늘 보인다")
	var seen := {}
	for i in 15:
		seen[FieldView.gold_shown(Tuning.GOLD_BLINK - 0.05 - 0.1 * i)] = true
	assert(seen.size() == 2, "마지막 GOLD_BLINK 초에는 숨었다 보였다 한다")
	var g := _game()
	var fv := _view(g)
	g.gold_cell = Vector3i(6, 1, 2)
	for left in [Tuning.GOLD_BLINK - 0.05, Tuning.GOLD_BLINK - 0.15]:
		g.gold_left = left
		fv._update()
		assert(fv.gold.visible == FieldView.gold_shown(left) and fv.gold_ring.visible == fv.gold.visible, "벌레와 고리가 같이 깜빡인다")
	fv.queue_free()

# 먹힌 황금 벌레도 머리로 빨려 들며 작아진다(황금 크기에서 시작).
func _test_gold_ghost() -> void:
	var g := _game()
	g.state = Game.State.RUNNING
	g.worm.head_exit = Vector3i(-1, 0, 0)
	var fv := _view(g)
	assert(fv.ghosts.size() == Tuning.BUG_COUNT + 1 and not fv.ghosts[Game.GOLD].visible, "먹히는 벌레 자리는 일반 종류마다 하나와 황금 하나")
	g.just_grew = true
	g.eaten_cell = Vector3i(4, 4, 4)
	g.eaten_kind = Game.GOLD
	g.alpha = 0.0
	fv._update()
	assert(fv.ghosts[Game.GOLD].visible and not fv.ghosts[0].visible, "황금 벌레만 보인다")
	assert(is_equal_approx(fv.ghosts[Game.GOLD].scale.x, Tuning.GOLD_SCALE), "처음에는 황금 벌레 제 크기로")
	g.alpha = Tuning.EAT_PULL * 0.5
	fv._update()
	var mid := fv.ghosts[Game.GOLD].scale.x
	assert(mid > 0.0 and mid < Tuning.GOLD_SCALE, "빨려 들며 작아진다: %f" % mid)
	fv.queue_free()
```

**편집 `tests/test_floor_gauge.gd`**

바꿀 곳:

```gdscript
	assert(gauge.bug_layers == ([0, 3, 3] as Array[int]) and gauge.rock_layers == ([0, 2] as Array[int]), "층별 벌레·바위")
```

바꾼 뒤:

```gdscript
	assert(gauge.bug_layers == ([0, 3, 3] as Array[int]) and gauge.rock_layers == ([0, 2] as Array[int]), "층별 벌레·바위")
	assert(gauge.gold_layer == -1, "황금 벌레가 없으면 -1")
	g.gold_cell = Vector3i(2, 2, 2)
	g.gold_left = Tuning.GOLD_TIME
	gauge.update_from(g)
	assert(gauge.gold_layer == 2, "황금 벌레가 있는 층")
	g.gold_left = 0.0
	gauge.update_from(g)
	assert(gauge.gold_layer == -1, "사라지면 다시 -1")
```

- [ ] **Step 2: 실패를 확인한다**

공통 명령의 "테스트 하나" 를 `test_field_view` 와 `test_floor_gauge` 로 각각 돌린다. 기대: 둘 다 `SCRIPT ERROR` 줄이 나온다(`gold`·`gold_layer` 가 아직 없다).

- [ ] **Step 3: 구현한다**

**편집 `scripts/tuning.gd`**

바꿀 곳:

```gdscript
const POP_TIME := 0.9                       # 점수 +N 이 떠올라 사라지는 시간(초)
```

바꾼 뒤:

```gdscript
const POP_TIME := 0.9                       # 점수 +N 이 떠올라 사라지는 시간(초)
const GOLD_SCALE := 1.3                     # 황금 벌레의 크기 배율(일반 벌레보다 크게)
const GOLD_SPIN := 3.0                      # 황금 벌레가 제자리에서 도는 속도(라디안/초)
const GOLD_BLINK := 1.5                     # 황금 벌레가 사라지기 이 시간(초) 전부터 0.1초마다 깜빡인다
```

**편집 `scripts/field_view.gd`**

바꿀 곳:

```gdscript
# 흙 상자, 바위, 벌레(종류 3가지), 머리 층의 아래·위 판, 벌레 고리·기둥, 머리로 빨려 드는 벌레.
```

바꾼 뒤:

```gdscript
# 흙 상자, 바위, 벌레(종류 3가지)와 황금 벌레, 머리 층의 아래·위 판, 벌레 고리·기둥, 머리로 빨려 드는 벌레.
```

**편집 `scripts/field_view.gd`**

바꿀 곳:

```gdscript
var ghosts: Array[MeshInstance3D] = []  # 먹히는 중인 벌레(종류마다 하나)
```

바꾼 뒤:

```gdscript
var ghosts: Array[MeshInstance3D] = []  # 먹히는 중인 벌레(종류마다 하나, 번호 Game.GOLD 는 황금 벌레)
var gold: MeshInstance3D                # 황금 벌레
var gold_ring: MeshInstance3D
var gold_stem: MeshInstance3D
```

**편집 `scripts/field_view.gd`**

바꿀 곳:

```gdscript
		ghosts[k].visible = false
```

바꾼 뒤:

```gdscript
		ghosts[k].visible = false
	var gold_model := Models.load_model(Skins.GOLD["model"])
	gold = _bug_node(gold_model, true)
	var gold_marker := _marker_material(Skins.GOLD["color"])
	gold_ring = _mesh(ring_mesh, gold_marker)
	gold_stem = _mesh(stem_mesh, gold_marker)
	ghosts.append(_bug_node(gold_model, false))  # 번호가 Game.GOLD 다
	ghosts[Game.GOLD].visible = false
```

**편집 `scripts/field_view.gd`**

바꿀 곳:

```gdscript
			_flicker(bugs[b], c)
			rings[b].position = Vector3(p.x, head_y, p.z)
			# 기둥은 꼼지락을 뺀 칸 중심으로 잰다. 같은 층에서 기둥이 깜빡이지 않게.
			var gap := p.y - head_y
			if absf(gap) > 0.05:
				stems[b].visible = true
				stems[b].position = Vector3(p.x, head_y + gap * 0.5, p.z)
				stems[b].scale = Vector3(1, absf(gap), 1)
	var rock_cells := game.field.rocks.keys()
	for i in rock_rings.size():
		var has := i < rock_cells.size()
		rock_rings[i].visible = has
		rock_stems[i].visible = false
		if not has:
			continue
		var p := WormPath.center(rock_cells[i])
		rock_rings[i].position = Vector3(p.x, head_y, p.z)
		var gap := p.y - head_y
		if absf(gap) > 0.05:
			rock_stems[i].visible = true
			rock_stems[i].position = Vector3(p.x, head_y + gap * 0.5, p.z)
			rock_stems[i].scale = Vector3(1, absf(gap), 1)
	_update_ghost()
```

바꾼 뒤:

```gdscript
			_flicker(bugs[b], c)
			_place_marker(rings[b], stems[b], p, head_y)
	_update_gold(head_y)
	var rock_cells := game.field.rocks.keys()
	for i in rock_rings.size():
		var has := i < rock_cells.size()
		rock_rings[i].visible = has
		rock_stems[i].visible = false
		if not has:
			continue
		_place_marker(rock_rings[i], rock_stems[i], WormPath.center(rock_cells[i]), head_y)
	_update_ghost()
```

**편집 `scripts/field_view.gd`**

바꿀 곳:

```gdscript
# 벌레의 은은한 발광이 느리게 깜빡인다.
func _flicker(bug: MeshInstance3D, c: Vector3i) -> void:
	var e := 0.5 + 0.2 * sin(_time * 1.6 + c.x * 0.9 + c.z * 1.3)
```

바꾼 뒤:

```gdscript
# 칸 중심 p 의 고리·기둥을 머리 층 높이 head_y 에 맞춘다. 높이 차가 있으면 기둥이 고리까지 이어진다.
# 기둥은 꼼지락을 뺀 칸 중심으로 잰다. 같은 층에서 기둥이 깜빡이지 않게.
func _place_marker(ring: MeshInstance3D, stem: MeshInstance3D, p: Vector3, head_y: float) -> void:
	ring.position = Vector3(p.x, head_y, p.z)
	var gap := p.y - head_y
	stem.visible = absf(gap) > 0.05
	if stem.visible:
		stem.position = Vector3(p.x, head_y + gap * 0.5, p.z)
		stem.scale = Vector3(1, absf(gap), 1)

# 황금 벌레가 지금 보이는가: 남은 시간 left 가 있고, 사라지기 직전 GOLD_BLINK 초는 0.1초마다 숨었다 보였다 한다.
static func gold_shown(left: float) -> bool:
	if left <= 0.0:
		return false
	return left > Tuning.GOLD_BLINK or int(left * 10.0) % 2 == 0

# 황금 벌레: 있으면 제자리에서 돌며 세게 빛난다. 고리·기둥도 같이 깜빡인다.
func _update_gold(head_y: float) -> void:
	var on := gold_shown(game.gold_left)
	gold.visible = on
	gold_ring.visible = on
	gold_stem.visible = false
	if not on:
		return
	var c := game.gold_cell
	var p := WormPath.center(c)
	gold.position = p + Vector3(0, 0.06 * sin(_time * 3.0 + c.x + c.z * 1.7), 0)
	gold.rotation.y = _time * Tuning.GOLD_SPIN
	gold.scale = Vector3.ONE * Tuning.GOLD_SCALE
	_flicker(gold, c, 0.9, 0.4, 5.0)
	_place_marker(gold_ring, gold_stem, p, head_y)
	gold_ring.scale = Vector3.ONE * Tuning.GOLD_SCALE  # 고리도 벌레만큼 크게: 같은 층에서 벌레에 가려지지 않는다

# 벌레의 은은한 발광이 느리게 깜빡인다. 황금 벌레는 더 세고 빠르게 넘긴다.
func _flicker(bug: MeshInstance3D, c: Vector3i, base := 0.5, amp := 0.2, rate := 1.6) -> void:
	var e := base + amp * sin(_time * rate + c.x * 0.9 + c.z * 1.3)
```

**편집 `scripts/field_view.gd`**

바꿀 곳:

```gdscript
	ghost.scale = Vector3.ONE * (1.0 - e)
```

바꾼 뒤:

```gdscript
	ghost.scale = Vector3.ONE * (1.0 - e) * (Tuning.GOLD_SCALE if game.eaten_kind == Game.GOLD else 1.0)
```

**편집 `scripts/floor_gauge.gd`**

바꿀 곳:

```gdscript
# 칸 안의 점은 그 층의 벌레(종류 색)와 바위(회색)다. 1층짜리 판에서는 숨긴다.
```

바꾼 뒤:

```gdscript
# 칸 안의 점은 그 층의 벌레(종류 색)와 바위(회색)다. 황금 벌레는 맨 앞의 큰 금색 점이다. 1층짜리 판에서는 숨긴다.
```

**편집 `scripts/floor_gauge.gd`**

바꿀 곳:

```gdscript
var rock_layers: Array[int] = []
```

바꾼 뒤:

```gdscript
var rock_layers: Array[int] = []
var gold_layer := -1              # 황금 벌레가 있는 층(없으면 -1)
```

**편집 `scripts/floor_gauge.gd`**

바꿀 곳:

```gdscript
	for r in g.field.rocks:
		rock_layers.append(r.y)
	visible = height > 1
```

바꾼 뒤:

```gdscript
	for r in g.field.rocks:
		rock_layers.append(r.y)
	gold_layer = g.gold_cell.y if g.gold_left > 0.0 else -1
	visible = height > 1
```

**편집 `scripts/floor_gauge.gd`**

바꿀 곳:

```gdscript
		var x := rc.position.x + 40.0
		for i in bug_layers.size():
```

바꾼 뒤:

```gdscript
		var x := rc.position.x + 40.0
		if gold_layer == y:  # 황금 벌레: 큰 금색 점이 맨 앞
			draw_circle(Vector2(x, rc.position.y + CELL.y * 0.5), DOT * 1.4, Skins.GOLD["color"])
			x += DOT * 1.4 + DOT + 4.0
		for i in bug_layers.size():
```

- [ ] **Step 4: 통과를 확인한다**

공통 명령의 "테스트 하나" 를 `test_field_view` 와 `test_floor_gauge` 로 각각 돌린다. 기대: `test_field_view: OK`, `test_floor_gauge: OK`.

- [ ] **Step 5: 전체 테스트**

`./run_tests.sh` → 마지막 줄 `전체 통과`.

- [ ] **Step 6: 커밋한다**

```bash
git add scripts/tuning.gd scripts/field_view.gd scripts/floor_gauge.gd tests/test_field_view.gd tests/test_floor_gauge.gd
git commit -m "황금 벌레를 판과 층 눈금에 그린다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 5: HUD 콤보 줄

**Files:**
- Modify: `scripts/hud.gd`
- Test: `tests/test_hud.gd`

**Interfaces:**
- Consumes: `Skins.GOLD`(Task 3)
- Produces: `Hud.COMBO_BAR_W`(120.0), `Hud.combo_label: Label`, `Hud.combo_bar: ColorRect`, `Hud.set_combo(mult: int, frac: float) -> void`(`frac <= 0` 이면 숨김, `set_mode` 도 숨김으로 시작)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

**편집 `tests/test_hud.gd`**

바꿀 곳:

```gdscript
	_test_menu_button()
	_test_header_layout()
	print("test_hud: OK")
```

바꾼 뒤:

```gdscript
	_test_menu_button()
	_test_header_layout()
	_test_combo_line()
	print("test_hud: OK")
```

**편집 `tests/test_hud.gd`**

바꿀 곳:

```gdscript
	assert(hud.menu_button.position.y >= bugs_bottom - 4.0, "메뉴 버튼(위 %f)은 남은 벌레(아래 끝 %f) 아래" % [hud.menu_button.position.y, bugs_bottom])
	hud.queue_free()
```

바꾼 뒤:

```gdscript
	assert(hud.menu_button.position.y >= bugs_bottom - 4.0, "메뉴 버튼(위 %f)은 남은 벌레(아래 끝 %f) 아래" % [hud.menu_button.position.y, bugs_bottom])
	hud.set_mode(Title.Mode.CLASSIC)
	hud.set_combo(5, 1.0)
	var combo_size: Vector2 = hud.combo_label.get_combined_minimum_size()
	var combo_bottom: float = hud.combo_label.position.y + combo_size.y
	assert(hud.combo_label.position.y >= info_bottom - 4.0, "콤보 줄(위 %f)은 빌드 문구(아래 끝 %f) 아래" % [hud.combo_label.position.y, info_bottom])
	assert(hud.menu_button.position.y >= combo_bottom - 4.0, "메뉴 버튼(위 %f)은 콤보 줄(아래 끝 %f) 아래" % [hud.menu_button.position.y, combo_bottom])
	assert(hud.combo_bar.position.y >= hud.combo_label.position.y and hud.combo_bar.position.y + hud.combo_bar.size.y <= combo_bottom, "막대는 글자 높이 안에 들어간다")
	assert(hud.combo_bar.position.x >= hud.combo_label.position.x + combo_size.x, "막대는 글자 오른쪽에 있다")
	hud.queue_free()

# 콤보 줄: 다음 벌레에 붙을 배율 글자와 남은 시간 막대. 시간이 없으면 숨고, 방식을 바꿀 때도 숨은 채로 시작한다.
func _test_combo_line() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "처음에는 콤보 줄이 숨어 있다")
	assert(hud.combo_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "막대는 터치를 막지 않는다")
	hud.set_combo(2, 1.0)
	assert(hud.combo_label.visible and hud.combo_bar.visible and hud.combo_label.text == "×2", "배율 글자: %s" % hud.combo_label.text)
	assert(is_equal_approx(hud.combo_bar.size.x, Hud.COMBO_BAR_W), "시간이 꽉 차면 막대도 꽉 찬다")
	hud.set_combo(5, 0.25)
	assert(hud.combo_label.text == "×5" and is_equal_approx(hud.combo_bar.size.x, Hud.COMBO_BAR_W * 0.25), "막대 폭이 남은 시간을 따른다")
	hud.set_combo(3, 1.7)
	assert(is_equal_approx(hud.combo_bar.size.x, Hud.COMBO_BAR_W), "비율이 1 을 넘어도 막대는 넘치지 않는다")
	hud.set_combo(3, 0.0)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "시간이 다하면 숨긴다")
	hud.set_combo(2, 0.5)
	hud.set_mode(Title.Mode.TIME_ATTACK)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "타임어택으로 바꾸면 숨긴 채로 시작한다")
	hud.set_combo(2, 0.5)
	hud.set_mode(Title.Mode.CLASSIC)
	assert(not hud.combo_label.visible and not hud.combo_bar.visible, "기존 방식으로 바꿔도 숨긴 채로 시작한다")
	hud.queue_free()
```

- [ ] **Step 2: 실패를 확인한다**

공통 명령의 "테스트 하나" 를 `test_hud` 로 돌린다. 기대: `SCRIPT ERROR` 줄이 나온다(`combo_label`·`set_combo` 가 아직 없다).

- [ ] **Step 3: 구현한다**

**편집 `scripts/hud.gd`**

바꿀 곳:

```gdscript
# 위쪽: 점수(타임어택은 타이머), 빌드 버전과 fps, 가운데 레벨·최고 기록, 소리·맵 회전 버튼. 죽은 뒤에는 다시 시작 안내.
```

바꾼 뒤:

```gdscript
# 위쪽: 점수(타임어택은 타이머), 빌드 버전과 fps, 가운데 레벨·최고 기록, 소리·맵 회전 버튼. 기존 방식은 점수 아래에 콤보 줄. 죽은 뒤에는 다시 시작 안내.
```

**편집 `scripts/hud.gd`**

바꿀 곳:

```gdscript
const CLEAR_TEXT := "레벨 클리어!\n탭하면 다음 레벨"
```

바꾼 뒤:

```gdscript
const CLEAR_TEXT := "레벨 클리어!\n탭하면 다음 레벨"
const COMBO_BAR_W := 120.0   # 콤보 막대가 꽉 찼을 때의 폭
```

**편집 `scripts/hud.gd`**

바꿀 곳:

```gdscript
var bugs_label := Label.new()    # 타임어택 남은 벌레
```

바꾼 뒤:

```gdscript
var bugs_label := Label.new()    # 타임어택 남은 벌레
var combo_label := Label.new()   # 기존 방식: 다음 벌레에 붙을 배율 ×N
var combo_bar := ColorRect.new() # 남은 콤보 시간(폭이 줄어든다)
```

**편집 `scripts/hud.gd`**

바꿀 곳:

```gdscript
	bugs_label.visible = false
	add_child(bugs_label)
```

바꾼 뒤:

```gdscript
	bugs_label.visible = false
	add_child(bugs_label)
	combo_label.position = Vector2(24, 112)  # 타임어택의 남은 벌레와 같은 자리: 두 방식이 나눠 쓴다
	combo_label.add_theme_font_size_override("font_size", 28)
	combo_label.add_theme_color_override("font_color", Skins.GOLD["color"])
	combo_label.visible = false
	add_child(combo_label)
	combo_bar.position = Vector2(80, 124)  # 글자 오른쪽, 세로로는 글자 가운데
	combo_bar.size = Vector2(COMBO_BAR_W, 12)
	combo_bar.color = Skins.GOLD["color"]
	combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 막대 위를 눌러도 게임 입력을 막지 않는다
	combo_bar.visible = false
	add_child(combo_bar)
```

**편집 `scripts/hud.gd`**

바꿀 곳:

```gdscript
func set_mode(mode: int) -> void:
	var time_attack := mode == Title.Mode.TIME_ATTACK
```

바꾼 뒤:

```gdscript
func set_mode(mode: int) -> void:
	set_combo(1, 0.0)  # 방식을 바꿀 때마다 콤보 줄은 숨긴 채로 시작한다
	var time_attack := mode == Title.Mode.TIME_ATTACK
```

**편집 `scripts/hud.gd`**

바꿀 곳:

```gdscript
func set_bugs_left(n: int) -> void:
	bugs_label.text = "남은 벌레 %d" % n
```

바꾼 뒤:

```gdscript
func set_bugs_left(n: int) -> void:
	bugs_label.text = "남은 벌레 %d" % n

# 콤보 줄(기존 방식): mult 는 다음 벌레에 붙을 배율, frac 은 남은 콤보 시간의 비율. frac 이 0 이하면 숨긴다.
func set_combo(mult: int, frac: float) -> void:
	var on := frac > 0.0
	combo_label.visible = on
	combo_bar.visible = on
	if on:
		combo_label.text = "×%d" % mult
		combo_bar.size.x = COMBO_BAR_W * minf(frac, 1.0)
```

- [ ] **Step 4: 통과를 확인한다**

공통 명령의 "테스트 하나" 를 `test_hud` 로 돌린다. 기대: `test_hud: OK` 한 줄.

레이아웃 단언(`콤보 줄(위 …)은 …`)이 실패하면 글자가 빌드 문구나 메뉴 버튼과 겹치는 것이다: `combo_label` 의 `font_size` 를 28 에서 24 로 줄이고 다시 돌린다(스펙 3절의 대비책).

- [ ] **Step 5: 전체 테스트**

`./run_tests.sh` → 마지막 줄 `전체 통과`(`test_font` 가 `×` 를 확인한다).

- [ ] **Step 6: 커밋한다**

```bash
git add scripts/hud.gd tests/test_hud.gd
git commit -m "HUD 에 콤보 줄(배율과 남은 시간 막대)을 더한다

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 6: Main 연결(기존 방식만)과 흐름 테스트

**Files:**
- Modify: `scripts/main.gd`
- Test: `tests/test_modes_flow.gd`

**Interfaces:**
- Consumes: `Game.golden`·`combo`·`combo_left`·`gold_appeared`·`GOLD`(Task 1), `Sfx.play_eat(kind, combo)`·소리 `gold`(Task 2), `Skins.GOLD`(Task 3), `Hud.set_combo`(Task 5)
- Produces: 기존 방식 판은 `game.golden == true`, 타임어택 판은 `false`. 먹을 때 `+N` 이 점수(배율 포함)로 뜨고, 황금 벌레면 금색. `gold_appeared` 가 오면 `gold` 소리와 `황금!` 글자. 기존 방식에서 매 프레임 콤보 줄 갱신.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

**편집 `tests/test_modes_flow.gd`**

바꿀 곳:

```gdscript
	_test_classic_debug_start_does_not_record()
	_test_time_attack_setup_and_timer()
```

바꾼 뒤:

```gdscript
	_test_classic_debug_start_does_not_record()
	_test_classic_combo_and_gold()
	_test_time_attack_setup_and_timer()
```

**편집 `tests/test_modes_flow.gd`**

바꿀 곳:

```gdscript
	_test_time_attack_clear_records()
	_test_game_stops_while_title_is_open()
```

바꾼 뒤:

```gdscript
	_test_time_attack_clear_records()
	_test_time_attack_has_no_gold_or_combo_line()
	_test_game_stops_while_title_is_open()
```

**편집 `tests/test_modes_flow.gd`**

바꿀 곳:

```gdscript
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main._record_enabled, "평소 시작은 기록한다")
```

바꾼 뒤:

```gdscript
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	assert(_main._record_enabled, "평소 시작은 기록한다")

# 기존 방식: 황금 벌레를 쓰고, 먹는 소리는 게임의 연속 수를 따르고, 콤보 줄은 달리는 동안만 뜬다.
func _test_classic_combo_and_gold() -> void:
	_reset()
	_main.start_mode(Title.Mode.CLASSIC, 1, false)
	var g: Game = _main.game
	assert(g.golden, "기존 방식 판은 황금 벌레를 쓴다")
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible, "콤보가 없으면 줄이 숨어 있다")
	var cell := Vector3i(3, 4, 4)
	g.combo = 3
	_main._on_ate(0, 3, cell)
	assert(_main.sfx.last_id == "eat_0" and is_equal_approx(_main.sfx.last_pitch, Sfx.combo_pitch(3)), "먹는 소리 음높이는 게임의 연속 수를 따른다")
	var pops := _count("+20")
	_main._on_ate(Game.GOLD, 20, cell)
	assert(_main.sfx.last_id == "eat_3" and _count("+20") == pops + 1, "황금 벌레는 eat_3 소리와 +N")
	var gold_pops: Array = _main.hud.get_children().filter(func(n: Node) -> bool: return n is Label and n.text == "+20")
	assert(gold_pops[0].get_theme_color("font_color") == Skins.GOLD["color"], "황금 벌레 점수는 금색")
	var found := _count("황금!")
	g.gold_appeared.emit(cell)
	assert(_main.sfx.last_id == "gold" and _count("황금!") == found + 1, "황금 벌레가 나타나면 소리와 황금! 글자")
	_main.sfx.set_muted(true)
	var plays: int = _main.sfx.plays
	g.gold_appeared.emit(cell)
	_main._on_ate(0, 1, cell)
	assert(_main.sfx.plays == plays, "소리를 끈 동안에는 소리가 없다(글자만 뜬다)")
	_main.sfx.set_muted(false)
	g.state = Game.State.RUNNING
	g.combo = 1
	g.combo_left = Tuning.COMBO_WINDOW * 0.5
	_main._process(0.0)
	assert(_main.hud.combo_label.visible and _main.hud.combo_label.text == "×2", "달리는 중에는 다음 벌레의 배율: %s" % _main.hud.combo_label.text)
	assert(is_equal_approx(_main.hud.combo_bar.size.x, Hud.COMBO_BAR_W * 0.5), "막대는 남은 시간 비율")
	g.combo = Tuning.COMBO_MAX
	_main._process(0.0)
	assert(_main.hud.combo_label.text == "×%d" % Tuning.COMBO_MAX, "배율은 COMBO_MAX 를 넘지 않는다")
	g.state = Game.State.CLEARED
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible, "클리어하면 콤보 줄이 사라진다")
	g.state = Game.State.DEAD
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible, "죽으면 콤보 줄이 사라진다")

# 타임어택: 황금 벌레를 쓰지 않고 콤보 줄도 없다(콤보는 소리 음높이에만 드러난다).
func _test_time_attack_has_no_gold_or_combo_line() -> void:
	_reset()
	_main.start_mode(Title.Mode.TIME_ATTACK)
	var g: Game = _main.game
	assert(not g.golden, "타임어택 판은 황금 벌레를 쓰지 않는다")
	g.state = Game.State.RUNNING
	g.combo = 2
	g.combo_left = Tuning.COMBO_WINDOW
	_main._process(0.0)
	assert(not _main.hud.combo_label.visible and not _main.hud.combo_bar.visible, "타임어택에는 콤보 줄이 없다")
```

- [ ] **Step 2: 실패를 확인한다**

공통 명령의 "테스트 하나" 를 `test_modes_flow` 로 돌린다. 기대: `SCRIPT ERROR` 줄이 나온다(`golden` 이 안 켜져 있고 `_on_gold_appeared` 가 없다). `test_modes_flow: OK` 는 없다.

- [ ] **Step 3: 구현한다**

**편집 `scripts/main.gd`**

바꿀 곳:

```gdscript
	game.score = base_score
	game.ate.connect(_on_ate)
	game.cleared.connect(_on_cleared)
```

바꾼 뒤:

```gdscript
	game.score = base_score
	game.golden = mode == Title.Mode.CLASSIC  # 황금 벌레는 기존 방식만
	game.ate.connect(_on_ate)
	game.cleared.connect(_on_cleared)
	game.gold_appeared.connect(_on_gold_appeared)
```

**편집 `scripts/main.gd`**

바꿀 곳:

```gdscript
		hud.set_bugs_left(game.field.bugs.size())
	floors.update_from(game)
```

바꾼 뒤:

```gdscript
		hud.set_bugs_left(game.field.bugs.size())
	else:  # 콤보 줄: 다음 벌레에 붙을 배율과 남은 시간. 달리는 동안만 보인다
		var running := game.state == Game.State.RUNNING
		hud.set_combo(mini(game.combo + 1, Tuning.COMBO_MAX), game.combo_left / Tuning.COMBO_WINDOW if running else 0.0)
	floors.update_from(game)
```

**편집 `scripts/main.gd`**

바꿀 곳:

```gdscript
# 벌레를 먹으면 먹은 칸 위에 점수가 떠오른다. 색은 벌레 종류 색이다.
func _on_ate(kind: int, points: int, cell: Vector3i) -> void:
	sfx.play_eat(kind, game.combo)
	var at := rig.camera.unproject_position(WormPath.center(cell)) - Vector2(0, 40)
	hud.pop("+%d" % points, at, Skins.BUGS[kind]["color"])
	if mode == Title.Mode.CLASSIC:
		_update_best_score()
```

바꾼 뒤:

```gdscript
# 벌레를 먹으면 먹은 칸 위에 점수가 떠오른다(연속 배율을 곱한 값). 색은 벌레 종류 색, 황금 벌레는 금색이다.
func _on_ate(kind: int, points: int, cell: Vector3i) -> void:
	sfx.play_eat(kind, game.combo)
	var color: Color = Skins.GOLD["color"] if kind == Game.GOLD else Skins.BUGS[kind]["color"]
	hud.pop("+%d" % points, _screen_above(cell), color)
	if mode == Title.Mode.CLASSIC:
		_update_best_score()

# 황금 벌레가 나타났다: 소리와, 그 칸 위에 금색 "황금!".
func _on_gold_appeared(cell: Vector3i) -> void:
	sfx.play("gold")
	hud.pop("황금!", _screen_above(cell), Skins.GOLD["color"])

# 칸 위쪽의 화면 위치(뷰포트 좌표): 떠오르는 글자를 놓는 자리.
func _screen_above(cell: Vector3i) -> Vector2:
	return rig.camera.unproject_position(WormPath.center(cell)) - Vector2(0, 40)
```

- [ ] **Step 4: 통과를 확인한다**

공통 명령의 "테스트 하나" 를 `test_modes_flow` 로 돌린다. 기대: `test_modes_flow: OK` 한 줄.

- [ ] **Step 5: 전체 테스트**

`./run_tests.sh` → 마지막 줄 `전체 통과`(`test_main_smoke`·`test_levels_flow` 포함).

- [ ] **Step 6: 커밋한다**

```bash
git add scripts/main.gd tests/test_modes_flow.gd
git commit -m "Main 이 황금 벌레와 콤보 줄을 연결한다(기존 방식만)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 7: 푸시·배포와 확인

코드를 더 고치지 않는다. 배포하고 화면을 확인한다. 푸시는 이 계획서를 사용자가 승인한 범위 안이다. main 병합은 하지 않는다.

- [ ] **Step 1: 마지막 전체 확인**

```bash
./run_tests.sh | tail -3 && git status --short && git log --oneline -9
```

기대: `전체 통과`, 상태는 `?? .superpowers/` 뿐, 로그 위쪽에 이 계획의 커밋 여섯.

- [ ] **Step 2: 황금 벌레 모습을 눈으로 확인한다(일회용 스크립트)**

저장소 밖 임시 폴더(예: 세션의 scratchpad)에 `gold_shot.gd` 를 만든다. 저장소에는 넣지 않는다.

```gdscript
extends SceneTree

# 일회용 비교 샷: 기존 방식 8층 판의 머리 층에 크림·더듬이·황금·반딧불·더듬이를 나란히 놓고, 콤보 줄까지 한 장에 담아 PNG 로 저장한다.
# 사용: Godot --path <저장소> --resolution 540x960 --script <이 파일> -- <출력 PNG 경로>
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	SaveData.PATH = "user://gold_shot.cfg"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.title.visible = false
	main.start_mode(Title.Mode.CLASSIC, 8, false)
	var g: Game = main.game
	g.golden = true
	g.field.rocks.clear()
	var y: int = g.worm.head().y
	g.field.bugs.assign([Vector3i(1, y, 1), Vector3i(2, y, 1), Vector3i(4, y, 1), Vector3i(5, y, 1)])
	g.field.kinds.assign([0, 1, 2, 1])
	g.gold_cell = Vector3i(3, y, 1)
	main.field_view.setup(g)
	for i in 6:
		await process_frame
	# 창이 느려도(프레임이 길어도) 콤보·황금 시간이 줄지 않게, 찍기 직전 프레임에 값을 넣는다.
	g.gold_left = Tuning.GOLD_TIME
	g.combo = 2
	g.combo_left = Tuning.COMBO_WINDOW * 0.6
	g.state = Game.State.RUNNING
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 540x960 --script <gold_shot.gd 경로> -- <출력 PNG 경로>
```

Mac 화면에 Godot 창이 잠깐 뜬다(이 창은 2~6fps 로 느리게 돈다). PNG 를 열어 본다. 확대해서 보려면 `sips -c 110 220 --cropOffset 225 215 <PNG> --out <자른 PNG>` 로 벌레 줄만 잘라 `sips -z 440 880 <자른 PNG>` 로 키운다. 볼 것:

- 가운데 황금 벌레가 양옆 더듬이 벌레와 구분되는가(검증 때는 더 크고 선명한 노랑이었고 안테나가 없었다).
- 층 눈금 5층 칸 맨 앞에 큰 금색 점이 있는가.
- 점수 아래에 금색 `×3` 글자와 막대가 있고, 빌드 문구·메뉴 버튼과 겹치지 않는가.

헷갈리면 `bugs.py` 의 색, `Skins.GOLD["color"]`, `Tuning.GOLD_SCALE` 을 고치고 해당 테스트(`test_models` 의 색 단언 포함)를 다시 돌려 따로 커밋한다.

- [ ] **Step 3: 푸시한다**

```bash
git push origin time-attack-random
git push -u origin combo-gold
```

앞 줄은 time-attack-random 에 아직 안 올린 문서 커밋(2522fa7) 하나를 올린다. 배포 워크플로는 차례로 돌고, 나중에 푸시한 `combo-gold` 가 라이브가 된다.

- [ ] **Step 4: 배포를 기다리고 빌드 번호를 읽는다**

```bash
gh run list --branch combo-gold --limit 1
```

그 실행이 `completed success` 가 될 때까지 기다린다(`gh run watch <id>`). 라이브 주소 https://kjw5541a-hash.github.io/cube-worm/ 를 크롬 자동화로 열어 왼쪽 위 빌드 문구(`build N 날짜 combo-gold sha`)를 읽는다. N 을 사용자에게 보고한다.

- [ ] **Step 5: 웹에서 확인한다**

- 기존 방식을 고르고 첫 벌레를 먹으면 점수 아래에 `×2` 와 줄어드는 막대가 뜬다(자동 조작으로 어려우면 폰 확인으로 넘긴다).
- 타임어택에는 콤보 줄이 없다.
- 시작 그림, 방식 선택, HUD 글자가 겹치지 않는다.

- [ ] **Step 6: 사용자에게 보고한다**

빌드 번호, 브랜치(`combo-gold`), 확인한 것과 못 한 것(폰 실기 확인은 사용자 몫)을 말한다. 폰에서 판단할 것은 스펙 9절: 콤보 시간 3초·상한 ×5, 황금 벌레(레벨 4부터 나오는 것, 5초와 5점, 눈에 띄는 정도), 콤보 줄 위치, 새 소리 둘의 크기. main 병합은 사용자가 말할 때만 한다.

## 자체 검토

- **스펙 대응:** 1절 콤보 → Task 1. 2절 황금 벌레 → Task 1. 3절 화면(모델 → Task 3, 판·층 눈금 → Task 4, HUD → Task 5, 점수·`황금!` 글자 → Task 6). 4절 소리 → Task 2(소리 합성·합치기), Task 6(`gold` 소리 호출). 5절 방식과 기록(`golden` 스위치 → Task 6, 저장 형식 불변 → 건드리는 작업 없음). 6절 구조 표 → 위 파일 구조. 7절 테스트 → 각 작업 Step 1. 8절 순서 → Task 1~7. 9절 확인 → Task 7.
- **스펙에 없던 것:** 기존 `_test_clear`(벌레 둘을 잇달아 먹음)의 기대 점수가 ×2 가 되어 Task 1 에서 고친다. 스펙은 이 테스트를 "그대로 통과" 목록에 넣지 않았지만 같은 이유로 바뀌어야 한다. `ColorRect` 막대의 `mouse_filter` 를 무시로 둔다(막대 위 터치를 게임 입력이 받게). 황금 고리를 벌레와 같은 배율(`GOLD_SCALE`)로 키운다(같은 층에서는 큰 황금 벌레 몸이 작은 고리를 덮는다는 것을 스크린샷 검증에서 알았다). Blender 빌드가 기존 모델 `.glb` 를 바이트만 다르게 다시 쓰고 `assets/blender/__pycache__/` 를 남기므로 Task 3 Step 4 가 되돌리고 지운다.
- **이름 일치:** `Game.GOLD`·`gold_appeared`·`golden`·`combo`·`combo_left`·`gold_cell`·`gold_left`(Task 1)를 Task 2~6 이 같은 철자로 쓴다. `Sfx.play_eat(kind, combo)`·`combo_pitch(combo)`(Task 2)를 Task 6 이 쓴다. `Skins.GOLD`(Task 3)를 Task 4~6 이 쓴다. `FieldView.gold`·`gold_ring`·`gold_stem`·`gold_shown`(Task 4), `FloorGauge.gold_layer`(Task 4), `Hud.set_combo`·`combo_label`·`combo_bar`·`COMBO_BAR_W`(Task 5)도 테스트와 구현이 같다.
- **자리표시자 없음:** 모든 단계에 실제 코드와 명령이 있다.
