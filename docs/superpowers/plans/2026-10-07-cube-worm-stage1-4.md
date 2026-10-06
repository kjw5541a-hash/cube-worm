# 큐브 지렁이 1~4단계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 데스크톱과 폰 브라우저에서 플레이할 수 있는 큐브 지렁이 첫 버전을 만든다(규칙, 부드러운 경로, 땅속 보여주기, 컨트롤러, 맵 회전, 웹 배포). 그래픽은 임시 도형이다.

**Architecture:** 규칙(`Tuning`·`Worm`·`Field`·`Game`)은 노드 없는 `RefCounted` 라 헤드리스로 테스트한다. 화면은 순수 수학 `WormPath` 가 칸 기록과 진행률로 마디 변환을 계산하고, `WormView`·`FieldView` 가 매 프레임 그린다. 화면 방향 → 월드 축 변환은 `CameraRig` 하나만 맡고, `Controller` 는 화면 방향 번호(0~5)만 내보낸다.

**Tech Stack:** Godot 4.7.2 / GDScript, Compatibility 렌더러, GitHub Actions + GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-10-06-cube-worm-design.md` (1~4단계만. 5~6단계는 플레이 판단 뒤 별도 계획)

**실행 모델:** 사용자가 Sonnet 5.5 로 바꿔서 실행한다.

## 검증 상태 — 코드를 그대로 옮길 것

이 계획의 코드는 계획을 쓰면서 스크래치 프로젝트에서 글자 그대로 실행했다.

- 테스트 파일 10개 전부 통과. 상자 크기를 7 로 바꿔도 전부 통과(테스트가 조정값을 읽는다).
- 변이 14개(경로 곡선, U턴 자세, 꼬리 통과, 프레임 상한, 반대 입력, 멈춤 위치, 벌레 재생성, 기준 방향, 버튼 좌우, 회전 방향, 키 배치, 마름모 축, 회전 중 정지, 머리 층 판)를 전부 테스트가 잡았다.
- 웹으로 내보내 Chrome(WebGL2)에서 흙 상자, 머리 층 판, 고리·기둥, 비침, 컨트롤러가 그려지는 것을 눈으로 확인했다. 500마디 성능 장면도 120fps.
- 500마디 갱신 비용 0.62 ms/프레임(M4 Pro, 헤드리스).

그러니 **코드를 고치거나 "개선"하지 말고 그대로 옮긴다.** 테스트가 실패하면 먼저 옮긴 내용이 계획과 글자 그대로 같은지 비교한다.

## 1단계 스파이크 결과 (끝남)

스파이크는 계획을 쓰는 중에 끝냈다. 스텐실 대신, 깊이 검사를 뒤집은 두 번째 패스(`render_mode depth_test_inverted`)가 웹 Compatibility 에서 가려진 머리와 벌레를 그린다(spec 5절 5번에 반영). 스파이크 코드는 버렸다. 폰 사파리에서도 보이는지는 Task 8 의 폰 확인에서 본다.

## Global Constraints

- Godot 4.7.2 (`godot` = `/opt/homebrew/bin/godot`, `/Applications/Godot.app/Contents/MacOS/Godot` 와 같은 4.7.2). 렌더러 `gl_compatibility`. 세로 720×1280, stretch `canvas_items`, aspect `expand`.
- 물리 엔진은 쓰지 않는다. 게임 시간은 `_process` 에서만 흐른다.
- 판정은 정수 칸 `Vector3i` 다. 상자는 각 축 0~(BOX−1), 칸 중심 = 칸 + 0.5. 높이는 Y.
- 조정값은 전부 `scripts/tuning.gd` 에 둔다. 다른 파일에 숫자를 새로 박지 않는다.
- 화면 방향 → 월드 축 변환은 `CameraRig` 만 한다. 화면 방향 번호 i 는 화면 각도 30° + 60°·i 다: 0 ↗, 1 ▲, 2 ↖, 3 ↙, 4 ▼, 5 ↘.
- 모델 정면은 −Z(Godot 관례).
- 화면 문자열은 한국어로 쓴다. 프로젝트 폰트(`assets/fonts/NotoSansKR-hangul.ttf`)에 없는 기호(⟲ ⟳ 등)는 문자열에 넣지 않는다(`test_font` 가 막는다). 필요하면 `_draw` 로 그린다.
- 테스트 통과 조건: 출력에 `<파일 이름>: OK` 가 있고 `SCRIPT ERROR` 가 없을 것. `./run_tests.sh` 가 이 둘을 같이 본다.
- 커밋 메시지는 한국어, `feat:`/`test:`/`chore:`/`docs:` 접두. 끝에 실행 세션이 쓰는 Co-Authored-By 줄을 붙인다.
- `git add -A` / `git add .` 는 쓰지 않는다. 파일을 이름으로 추가한다. Godot 이 만든 `*.uid`, `*.import` 는 같이 커밋한다. 커밋 전에 `git status --short` 로 의도하지 않은 파일이 없는지 본다.
- 브랜치는 단계마다 하나다(`stage2-rules`, `stage3-first-play`, `stage4-phone`). 단계가 끝나면 main 에 fast-forward 로 병합하고 브랜치를 바로 지운다.
- 저장소 생성, push 처럼 밖으로 나가는 동작은 Task 8 에서 사용자 승인을 받은 뒤에만 한다.

## Godot 함정 (이 계획을 검증하며 실제로 밟은 것)

1. 실패한 `assert` 는 헤드리스 Godot 을 멈춰 세운다. `run_tests.sh` 가 파일마다 20초 제한을 건다. 한 파일만 돌릴 때도 시간 제한을 건다:
   `perl -e 'alarm 60; exec @ARGV' -- godot --headless --path . --script res://tests/test_x.gd`
2. `class_name` 은 임포트 캐시에서 등록된다. 새 `class_name` 을 만든 뒤 한 파일만 돌리기 전에 `godot --headless --path . --import >/dev/null 2>&1` 을 한 번 돌린다(`run_tests.sh` 는 알아서 한다).
3. 헤드리스 창은 64×64 로 고정이라 크기를 바꿀 수 없다. 화면 좌표가 필요한 테스트는 720×1280 `SubViewport` 안에서 한다.
4. 헤드리스의 `MultiMesh.get_instance_transform` 은 넣은 값을 돌려주지 않는다(더미 렌더러). 그래서 `WormView.body_transform()` 을 정적 함수로 빼서 그걸 검사한다.
5. 타입 추론: `_got == ([0, 1] as Array[int])` 처럼 괄호를 친다. 타입 없는 노드에서 꺼낸 값은 `var yaw: int = main.rig.yaw_step` 처럼 타입을 적는다. `var refs: Array = [...] if ... else [...]` 처럼 조건식 배열은 `Array` 로 받는다. 안 그러면 파스 에러다.
6. Godot 에디터로 프로젝트를 열면 `project.godot` 의 주석이 지워질 수 있다. 커밋 전에 `git diff project.godot` 를 보고, 의도하지 않은 변경은 `git checkout project.godot` 로 되돌린다.
7. 창을 띄우는 Godot 실행(`godot --path .`)은 에이전트 샌드박스 안에서 창 없이 몇 초 만에 조용히 끝난다. 데스크톱 플레이는 사용자에게 직접 실행해 달라고 한다.

## Review Focus

테스트가 없으면 놓치기 쉬운 입력 다섯 가지와, 그걸 고정하는 테스트:

1. 두 손가락으로 거의 동시에 누름 → 닿은 순서대로 둘 다 들어간다. (Task 7 `test_controller.gd` `_test_two_fingers_in_order`)
2. 버튼을 누른 채 미끄러뜨림 → 새 입력이 아니다. (Task 7 `_test_drag_is_not_input`)
3. 탭 전환 뒤 복귀처럼 프레임이 크게 밀림 → 한 프레임에 1/3칸 넘게 가지 않고, 막힌 칸 앞에서 장애물에 박히지 않는다. (Task 3 `_test_alpha_and_frame_clamp`, `_test_stop_before_obstacle_every_frame`)
4. 화면 비율이 다른 기기(긴 폰 720×1560, 가로로 넓은 데스크톱 창) → 상자가 같은 픽셀 크기로 같은 높이에 놓인다. (Task 5 `_test_same_scale_on_other_screens`)
5. 죽은 직후 연타·회전, 플레이 중 상자 탭 → 1초 전에는 다시 시작하지 않고, 죽은 뒤에는 맵이 돌지 않으며, 플레이 중 탭은 무시한다. (Task 7 `test_main_smoke.gd`)

## 파일 구조

| 파일 | 책임 | 작업 |
|---|---|---|
| `project.godot`, `.gitignore`, `run_tests.sh` | 프로젝트 설정, 테스트 러너(blockbox 복사) | 1 |
| `scripts/tuning.gd` | 조정값 전부 | 1 |
| `scripts/worm.gd` | 지렁이가 차지한 칸, 입구 방향, 기준 방향, 걸음, 자람 | 1 |
| `scripts/field.gd` | 상자 경계, 바위, 벌레 생성 | 2 |
| `scripts/game.gd` | 규칙: 입력 큐, 진행률, 걸음, 먹기, 죽음 | 3 |
| `scripts/worm_path.gd` | 순수 수학: 칸 기록 + 진행률 → 마디 위치·자세 | 4 |
| `scripts/camera_rig.gd` | 등각 직교 카메라, 회전, 화면 방향 → 월드 축(단독 소유), 화면 맞춤 | 5 |
| `shaders/worm.gdshader` | 공용 셰이더(높이 색, 발광) | 6 |
| `shaders/xray.gdshader` | 비침 두 번째 패스 | 6 |
| `shaders/soil_box.gdshader` | 흙 상자(지층, 격자, 풀 띠) | 6 |
| `shaders/layer_plane.gdshader` | 머리 층 판 | 6 |
| `scripts/worm_view.gd` | 머리 메시 + 몸 MultiMesh, 꼬리·꿈틀거림·자람·예고 동작 | 6 |
| `scripts/field_view.gd` | 흙 상자, 바위, 벌레, 머리 층 판, 고리·기둥 | 6 |
| `scripts/controller.gd` | 마름모 + 6방향 버튼, 부채꼴 판정, 키보드 | 7 |
| `scripts/hud.gd` | 점수, 버전·fps, 회전 버튼, 다시 시작 안내 | 7 |
| `scripts/main.gd`, `scenes/main.tscn` | 게임 화면 조립, 입력 연결, 다시 시작, 성능 확인 옵션 | 7 |
| `assets/fonts/NotoSansKR-hangul.ttf`, `OFL.txt` | 한글 폰트(bus-driver 복사) | 7 |
| `export_presets.cfg`, `.github/workflows/deploy.yml` | 웹 내보내기, Pages 배포(blockbox 기반) | 8 |

---

## 2단계: 규칙

### Task 1: 프로젝트 뼈대와 지렁이 칸 모델 (`Tuning`, `Worm`)

**Files:**
- Create: `project.godot`, `.gitignore`, `run_tests.sh`(blockbox 복사), `scripts/tuning.gd`, `scripts/worm.gd`
- Test: `tests/test_worm.gd`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `Tuning` 상수(뒤 작업이 쓰는 값까지 처음부터 전부 만든다): `BOX`, `START_HEAD`, `START_DIR`, `START_LENGTH`, `SPEED_START`, `SPEED_STEP`, `SPEED_MAX`, `MAX_STEP_PER_FRAME`, `BUG_COUNT`, `ROCK_COUNT`, `ROCK_CLEAR_RADIUS`, `QUEUE_MAX`, `TURN_TIME`, `DEATH_DELAY`, `PERF_LENGTH`, `HEAD_SIZE`, `DEATH_STOP`, `SEGMENT_SIZE`, `TAIL_TAPER`, `DEPTH_MIN_BRIGHT`, `GLANCE_DEG`, `WOBBLE_AMP`, `WOBBLE_HZ`, `WOBBLE_WAVELENGTH`
  - `Worm`(`RefCounted`): `cells: Array[Vector3i]`, `entries: Array[Vector3i]`, `refs: Array[Vector3i]`, `head_exit: Vector3i`, `static from_cells(path: Array[Vector3i]) -> Worm`, `static straight(head: Vector3i, dir: Vector3i, length: int) -> Worm`, `static serpentine_path(size: int) -> Array[Vector3i]`, `length() -> int`, `head() -> Vector3i`, `exit_of(j: int) -> Vector3i`, `blocks(c: Vector3i) -> bool`, `cell_set() -> Dictionary`, `step(grow: bool) -> void`
  - 뜻: 0번이 머리다. `entries[j]` 는 칸 j 에 들어올 때의 진행 방향이다. 칸 j 의 출구는 `entries[j-1]` 이고, 머리 칸의 출구만 `head_exit` 에 따로 둔다(출발 전에는 `ZERO`). `refs[j]` 는 수직으로 지나는 칸의 자세(윗면 방향)를 정하는 기준 수평 방향이다.

- [ ] **Step 1: 브랜치와 뼈대 만들기**

```bash
cd ~/games/cube-worm
git checkout -b stage2-rules
mkdir -p scripts tests scenes shaders assets/fonts
cp ~/games/blockbox/run_tests.sh . && chmod +x run_tests.sh
```

`project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]

config/name="큐브 지렁이"
; 배포 워크플로가 빌드마다 날짜·브랜치·커밋으로 덮어쓴다. 화면 왼쪽 위에 그대로 나온다.
config/version="dev"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]

window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[input_devices]

; 컨트롤러는 터치 이벤트만 받는다. 데스크톱에서는 마우스 클릭도 터치로 들어오게 한다.
pointing/emulate_touch_from_mouse=true

[rendering]

; 웹은 설정과 무관하게 Compatibility 로 돈다. 데스크톱 화면도 같게 하려고 처음부터 맞춘다.
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

`.gitignore`:

```
.godot/
.DS_Store
build/
*.translation
```

- [ ] **Step 2: 실패하는 테스트 쓰기 — `tests/test_worm.gd`**

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_straight()
	_test_step_moves_head_and_drops_tail()
	_test_step_grow_keeps_tail()
	_test_blocks_skips_only_tail()
	_test_refs_remember_last_horizontal()
	_test_serpentine_is_connected()
	print("test_worm: OK")
	quit()

func _cells(a: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(a)
	return out

func _test_straight() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	assert(w.cells == _cells([Vector3i(4, 4, 4), Vector3i(5, 4, 4), Vector3i(6, 4, 4)]), "몸은 머리 반대쪽으로 뻗는다: %s" % [w.cells])
	for e in w.entries:
		assert(e == Vector3i(-1, 0, 0), "일직선이면 모든 칸의 입구가 같다")
	assert(w.head_exit == Vector3i.ZERO, "출발 전에는 출구가 없다")
	assert(w.exit_of(1) == Vector3i(-1, 0, 0), "몸 칸의 출구는 머리 쪽 이웃 칸의 입구다")

func _test_step_moves_head_and_drops_tail() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	w.head_exit = Vector3i(0, 0, 1)
	w.step(false)
	assert(w.cells == _cells([Vector3i(4, 4, 5), Vector3i(4, 4, 4), Vector3i(5, 4, 4)]), "머리가 출구로 한 칸, 꼬리는 한 칸 줄어든다: %s" % [w.cells])
	assert(w.entries[0] == Vector3i(0, 0, 1), "새 머리 칸의 입구는 방금 출구")
	assert(w.length() == 3)

func _test_step_grow_keeps_tail() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	w.head_exit = Vector3i(-1, 0, 0)
	w.step(true)
	assert(w.length() == 4, "자라면 한 마디 길어진다")
	assert(w.cells[3] == Vector3i(6, 4, 4), "자라는 걸음에는 꼬리가 제자리에 남는다")
	assert(w.entries.size() == 4 and w.refs.size() == 4, "칸마다 입구와 기준 방향이 있어야 한다")

func _test_blocks_skips_only_tail() -> void:
	var w := Worm.straight(Vector3i(2, 4, 4), Vector3i(-1, 0, 0), 4)
	assert(w.blocks(Vector3i(3, 4, 4)), "몸 칸은 막는다")
	assert(not w.blocks(Vector3i(5, 4, 4)), "현재 꼬리 칸은 이번 걸음에 비워지므로 막지 않는다")
	assert(not w.blocks(Vector3i(0, 0, 0)))

func _test_refs_remember_last_horizontal() -> void:
	var w := Worm.straight(Vector3i(4, 4, 4), Vector3i(-1, 0, 0), 3)
	w.head_exit = Vector3i(0, 1, 0)
	w.step(false)
	assert(w.refs[0] == Vector3i(-1, 0, 0), "위로 꺾여도 직전 수평 방향을 기억한다")
	w.head_exit = Vector3i(0, 1, 0)
	w.step(false)
	assert(w.refs[0] == Vector3i(-1, 0, 0), "수직이 이어져도 같은 기준을 물려받는다")
	w.head_exit = Vector3i(0, 0, 1)
	w.step(false)
	assert(w.refs[0] == Vector3i(0, 0, 1), "다시 수평이면 그 방향이 기준")

func _test_serpentine_is_connected() -> void:
	var p := Worm.serpentine_path(8)
	assert(p.size() == 512, "상자 전체를 지난다")
	var seen := {}
	for i in p.size():
		seen[p[i]] = true
		if i > 0:
			var d := p[i] - p[i - 1]
			assert(absi(d.x) + absi(d.y) + absi(d.z) == 1, "이웃한 두 칸이 맞닿아야 한다: %s → %s" % [p[i - 1], p[i]])
	assert(seen.size() == 512, "같은 칸을 두 번 지나면 안 된다")
```

- [ ] **Step 3: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_worm.gd` (`Worm` 을 모른다는 Parse Error, 성공 표식 없음). 마지막 줄 `테스트 실패`.

- [ ] **Step 4: 구현 — `scripts/tuning.gd`**

```gdscript
class_name Tuning
extends RefCounted

# 플레이로 판단할 조정값을 전부 여기 모은다. 다른 파일은 읽기만 한다.

const BOX := 8                              # 상자 한 변의 칸 수
const START_HEAD := Vector3i(4, 4, 4)
const START_DIR := Vector3i(-1, 0, 0)       # 머리가 보는 방향. 몸은 반대쪽으로 뻗는다
const START_LENGTH := 3

const SPEED_START := 3.0                    # 초당 칸
const SPEED_STEP := 0.1                     # 벌레 한 마리마다
const SPEED_MAX := 6.0
const MAX_STEP_PER_FRAME := 1.0 / 3.0       # 한 프레임에 머리가 나아가는 최대 칸

const BUG_COUNT := 3
const ROCK_COUNT := 8
const ROCK_CLEAR_RADIUS := 2                # 시작 지렁이 칸에서 이 체비쇼프 거리 안에는 바위 없음
const QUEUE_MAX := 2

const TURN_TIME := 0.3                      # 맵 회전 시간(초)
const DEATH_DELAY := 1.0                    # 죽고 나서 다시 시작을 받기까지(초)
const PERF_LENGTH := 500                    # ?perf 로 시작할 때 몸 길이

# 화면(3단계 임시 도형). 크기는 칸 = 1 기준
const HEAD_SIZE := 0.96
# 다음 칸이 막혔을 때 머리가 멈추는 진행률. 머리 앞면이 장애물 면에 닿는 자리다(1 이면 반쯤 박힌다).
const DEATH_STOP := 1.0 - HEAD_SIZE * 0.5
const SEGMENT_SIZE := 0.86
const TAIL_TAPER := [0.66, 0.78, 0.9]       # 꼬리 끝에서 0, 1, 2 번째 마디 배율
const DEPTH_MIN_BRIGHT := 0.6               # 맨 아래층 밝기(맨 위 = 1)
const GLANCE_DEG := 15.0                    # 예고 동작: 다음 방향으로 미리 돌리는 고개 각도
const WOBBLE_AMP := 0.05                    # 꿈틀거림: 굵기 진폭
const WOBBLE_HZ := 1.6                      # 꿈틀거림: 초당 파동 수
const WOBBLE_WAVELENGTH := 6.0              # 꿈틀거림: 파동 한 주기의 마디 수
```

- [ ] **Step 5: 구현 — `scripts/worm.gd`**

```gdscript
class_name Worm
extends RefCounted

# 지렁이가 차지한 칸. 0번이 머리다.
# entries[j] 는 칸 j 에 들어올 때의 진행 방향이다. 칸 j 의 출구는 칸 j-1 의 입구와 같고,
# 머리 칸의 출구만 head_exit 로 따로 둔다(출발 전에는 ZERO).
var cells: Array[Vector3i] = []
var entries: Array[Vector3i] = []
# 칸마다 "기준 수평 방향". 수직으로 지나는 칸의 자세(윗면 방향)를 정하는 데 쓴다.
# 입구가 수평이면 입구 방향 그대로, 수직이면 꼬리 쪽 이웃 칸의 값을 물려받는다.
var refs: Array[Vector3i] = []
var head_exit := Vector3i.ZERO

# 머리부터 꼬리까지 이웃한 칸 목록으로 만든다. 꼬리 칸의 입구는 그 앞 칸의 입구와 같다고 본다.
static func from_cells(path: Array[Vector3i]) -> Worm:
	assert(path.size() >= 2, "지렁이는 두 칸 이상이어야 한다")
	var w := Worm.new()
	var n := path.size()
	for i in n:
		w.cells.append(path[i])
		w.entries.append(path[i] - path[i + 1] if i + 1 < n else w.entries[i - 1])
	w.refs.resize(n)
	var r := Vector3i(1, 0, 0)  # 꼬리부터 수직으로만 이어지면 쓰는 기본값
	for i in range(n - 1, -1, -1):
		if w.entries[i].y == 0:
			r = w.entries[i]
		w.refs[i] = r
	return w

# 머리가 dir 쪽을 보고 몸이 반대쪽으로 일직선인 지렁이.
static func straight(head: Vector3i, dir: Vector3i, length: int) -> Worm:
	var path: Array[Vector3i] = []
	for i in length:
		path.append(head - dir * i)
	return from_cells(path)

# 상자 전체를 층마다 지그재그로 지나는 길. 이웃한 두 칸은 늘 맞닿아 있다(성능 확인용).
static func serpentine_path(size: int) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var row := 0
	for y in size:
		for r in size:
			var z := r if y % 2 == 0 else size - 1 - r
			for c in size:
				var x := c if row % 2 == 0 else size - 1 - c
				path.append(Vector3i(x, y, z))
			row += 1
	return path

func length() -> int:
	return cells.size()

func head() -> Vector3i:
	return cells[0]

func exit_of(j: int) -> Vector3i:
	return head_exit if j == 0 else entries[j - 1]

# 머리가 c 로 들어가면 몸에 부딪히는가. 현재 꼬리 칸은 이번 걸음에 비워지므로 빼고 본다.
func blocks(c: Vector3i) -> bool:
	for i in cells.size() - 1:
		if cells[i] == c:
			return true
	return false

func cell_set() -> Dictionary:
	var out := {}
	for c in cells:
		out[c] = true
	return out

# 머리를 출구 방향으로 한 칸 옮긴다. grow 면 꼬리를 남겨 한 마디 길어진다.
func step(grow: bool) -> void:
	var d := head_exit
	cells.push_front(cells[0] + d)
	entries.push_front(d)
	refs.push_front(d if d.y == 0 else refs[0])
	if not grow:
		cells.pop_back()
		entries.pop_back()
		refs.pop_back()
```

- [ ] **Step 6: 통과 확인**

Run: `./run_tests.sh`
Expected: `test_worm: OK`, 마지막 줄 `전체 통과`.

- [ ] **Step 7: 커밋**

```bash
git status --short
git add .gitignore project.godot run_tests.sh scripts/tuning.gd scripts/tuning.gd.uid scripts/worm.gd scripts/worm.gd.uid tests/test_worm.gd tests/test_worm.gd.uid
git commit -m "feat: 조정값과 지렁이 칸 모델"
```

### Task 2: 상자·바위·벌레 (`Field`)

**Files:**
- Create: `scripts/field.gd`
- Test: `tests/test_field.gd`

**Interfaces:**
- Consumes: 없음(상자 크기와 난수를 밖에서 받는다)
- Produces: `Field`(`RefCounted`): `_init(box_size: int, random: RandomNumberGenerator)`, `size: int`, `rocks: Dictionary`(Vector3i → true), `bugs: Array[Vector3i]`, `rng: RandomNumberGenerator`, `in_bounds(c: Vector3i) -> bool`, `has_rock(c: Vector3i) -> bool`, `has_bug(c: Vector3i) -> bool`, `empty_cells(blocked: Dictionary) -> Array[Vector3i]`, `place_rocks(count: int, keep_away: Array[Vector3i], radius: int) -> void`, `spawn_bug(blocked: Dictionary) -> bool`, `remove_bug(c: Vector3i) -> void`

- [ ] **Step 1: 실패하는 테스트 쓰기 — `tests/test_field.gd`**

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_bounds()
	_test_rocks_keep_away_from_start()
	_test_bug_spawns_only_on_empty_cells()
	_test_spawn_fails_when_full()
	print("test_field: OK")
	quit()

func _field(seed: int) -> Field:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return Field.new(8, rng)

func _test_bounds() -> void:
	var f := _field(1)
	assert(f.in_bounds(Vector3i(0, 0, 0)) and f.in_bounds(Vector3i(7, 7, 7)))
	for c in [Vector3i(-1, 0, 0), Vector3i(0, 8, 0), Vector3i(0, 0, -1), Vector3i(8, 7, 7)]:
		assert(not f.in_bounds(c), "상자 밖: %s" % c)

func _test_rocks_keep_away_from_start() -> void:
	var start: Array[Vector3i] = [Vector3i(4, 4, 4), Vector3i(5, 4, 4), Vector3i(6, 4, 4)]
	for seed in 50:
		var f := _field(seed)
		f.place_rocks(8, start, 2)
		assert(f.rocks.size() == 8, "바위는 정확히 8개")
		for r in f.rocks:
			for s in start:
				var d := maxi(maxi(absi(r.x - s.x), absi(r.y - s.y)), absi(r.z - s.z))
				assert(d > 2, "시작 지렁이 근처에 바위: %s" % r)

func _test_bug_spawns_only_on_empty_cells() -> void:
	var f := _field(7)
	f.place_rocks(8, [] as Array[Vector3i], 0)
	var blocked := {Vector3i(1, 1, 1): true}
	for i in 400:
		assert(f.spawn_bug(blocked))
	var seen := {}
	for b in f.bugs:
		assert(not f.rocks.has(b) and not blocked.has(b), "벌레가 막힌 칸에 생겼다: %s" % b)
		assert(not seen.has(b), "같은 칸에 벌레 두 마리")
		seen[b] = true

func _test_spawn_fails_when_full() -> void:
	var f := _field(3)
	var all := {}
	for c in f.empty_cells({}):
		all[c] = true
	assert(not f.spawn_bug(all), "빈 칸이 없으면 벌레를 못 둔다")
	assert(f.bugs.is_empty())
```

- [ ] **Step 2: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_field.gd`, `test_worm: OK`.

- [ ] **Step 3: 구현 — `scripts/field.gd`**

```gdscript
class_name Field
extends RefCounted

# 상자 경계, 바위, 벌레. 난수는 시드를 고정할 수 있게 밖에서 받는다.
var size: int
var rocks := {}                     # Vector3i -> true
var bugs: Array[Vector3i] = []
var rng: RandomNumberGenerator

func _init(box_size: int, random: RandomNumberGenerator) -> void:
	size = box_size
	rng = random

func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size and c.y < size and c.z < size

func has_rock(c: Vector3i) -> bool:
	return rocks.has(c)

func has_bug(c: Vector3i) -> bool:
	return bugs.has(c)

# 바위·벌레·blocked(지렁이 등, Vector3i -> true) 어느 것도 없는 칸.
func empty_cells(blocked: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in size:
		for y in size:
			for z in size:
				var c := Vector3i(x, y, z)
				if not rocks.has(c) and not bugs.has(c) and not blocked.has(c):
					out.append(c)
	return out

# keep_away 칸들에서 체비쇼프 거리 radius 안에는 두지 않는다.
func place_rocks(count: int, keep_away: Array[Vector3i], radius: int) -> void:
	var allowed: Array[Vector3i] = []
	for c in empty_cells({}):
		if not _near(c, keep_away, radius):
			allowed.append(c)
	for i in mini(count, allowed.size()):
		var k := rng.randi_range(i, allowed.size() - 1)
		var t := allowed[i]
		allowed[i] = allowed[k]
		allowed[k] = t
		rocks[allowed[i]] = true

static func _near(c: Vector3i, cells: Array[Vector3i], radius: int) -> bool:
	for o in cells:
		if maxi(maxi(absi(c.x - o.x), absi(c.y - o.y)), absi(c.z - o.z)) <= radius:
			return true
	return false

# 빈 칸 하나에 벌레를 둔다. 빈 칸이 없으면 false.
func spawn_bug(blocked: Dictionary) -> bool:
	var free := empty_cells(blocked)
	if free.is_empty():
		return false
	bugs.append(free[rng.randi_range(0, free.size() - 1)])
	return true

func remove_bug(c: Vector3i) -> void:
	bugs.erase(c)
```

- [ ] **Step 4: 통과 확인**

Run: `./run_tests.sh`
Expected: `test_field: OK`, `test_worm: OK`, `전체 통과`.

- [ ] **Step 5: 커밋**

```bash
git add scripts/field.gd scripts/field.gd.uid tests/test_field.gd tests/test_field.gd.uid
git commit -m "feat: 상자 경계, 바위, 벌레 생성"
```

### Task 3: 규칙 (`Game`)

**Files:**
- Create: `scripts/game.gd`
- Test: `tests/test_game.gd`

**Interfaces:**
- Consumes: `Tuning` 상수, `Worm.straight`/`from_cells`/`serpentine_path`/`head`/`blocks`/`step`/`cell_set`/`entries`/`head_exit`, `Field.new`/`place_rocks`/`spawn_bug`/`in_bounds`/`has_rock`/`has_bug`/`remove_bug`
- Produces: `Game`(`RefCounted`): `enum State { WAITING, RUNNING, DEAD }`, `worm: Worm`, `field: Field`, `state: State`, `alpha: float`(머리가 지금 칸을 지난 비율, 0 = 입구 면, 1 = 출구 면), `speed: float`, `score: int`, `queue: Array[Vector3i]`, `paused: bool`(맵 회전 중 밖에서 켠다), `just_grew: bool`(이번 걸음에 자랐는가), `_init(seed: int = 0, perf := false)`, `press(dir: Vector3i) -> bool`(월드 방향 입력, 받아들였으면 true), `advance(delta: float) -> void`, `blocked(c: Vector3i) -> bool`

- [ ] **Step 1: 실패하는 테스트 쓰기 — `tests/test_game.gd`**

```gdscript
extends SceneTree

const X := Vector3i(1, 0, 0)
const Y := Vector3i(0, 1, 0)
const Z := Vector3i(0, 0, 1)
const FRAME := 1.0 / 60.0

func _initialize() -> void:
	_test_start_rules()
	_test_queue_rules()
	_test_alpha_and_frame_clamp()
	_test_straight_when_queue_empty()
	_test_queue_turns_next_cell()
	_test_wall_death()
	_test_rock_death()
	_test_body_death()
	_test_tail_follow_allowed()
	_test_stop_before_obstacle_every_frame()
	_test_eating()
	_test_speed_cap()
	_test_paused_freezes()
	_test_new_game_layout()
	_test_bugs_stay_valid_in_random_play()
	_test_perf_worm()
	print("test_game: OK")
	quit()

# 바위·벌레를 치운 판. 시작 지렁이는 머리 (4,4,4), -X 를 본다.
func _clean(head := Vector3i(4, 4, 4), length := 3) -> Game:
	var g := Game.new(1)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.worm = Worm.straight(head, -X, length)
	return g

# 머리가 한 칸 나아갈 때까지 돌린다.
func _one_step(g: Game) -> void:
	var start := g.worm.head()
	for i in 200:
		g.advance(FRAME)
		if g.worm.head() != start or g.state != Game.State.RUNNING:
			return
	assert(false, "200 프레임 안에 한 걸음도 못 갔다")

func _test_start_rules() -> void:
	var g := _clean()
	assert(not g.press(X), "목 쪽으로는 출발할 수 없다")
	assert(g.state == Game.State.WAITING)
	g.advance(1.0)
	assert(g.alpha == 0.0, "출발 전에는 진행하지 않는다")
	assert(g.press(-X), "앞으로 출발")
	assert(g.state == Game.State.RUNNING and g.worm.head_exit == -X)
	var g2 := _clean()
	assert(g2.press(Y), "옆이나 위로도 바로 출발한다")
	assert(g2.worm.head_exit == Y, "첫 입력은 큐를 거치지 않고 바로 머리 칸의 출구가 된다")
	assert(g2.queue.is_empty())

func _test_queue_rules() -> void:
	var g := _clean()
	g.press(-X)
	assert(not g.press(-X), "같은 방향은 무시")
	assert(not g.press(X), "정반대는 무시")
	assert(g.press(Y))
	assert(not g.press(-Y), "큐 마지막의 정반대도 무시")
	assert(not g.press(Y), "큐 마지막과 같은 방향도 무시")
	assert(g.press(Z))
	assert(not g.press(-X), "큐는 최대 2개")
	assert(g.queue.size() == 2)

func _test_alpha_and_frame_clamp() -> void:
	var g := _clean()
	g.press(-X)
	g.advance(0.1)
	assert(is_equal_approx(g.alpha, Tuning.SPEED_START * 0.1), "시작 속도 × 0.1초만큼 간다: %f" % g.alpha)
	var g2 := _clean()
	g2.press(-X)
	g2.advance(5.0)
	assert(is_equal_approx(g2.alpha, 1.0 / 3.0), "한 프레임에 1/3 칸을 넘지 않는다: %f" % g2.alpha)
	assert(g2.worm.head() == Vector3i(4, 4, 4), "프레임이 밀려도 칸을 건너뛰지 않는다")

func _test_straight_when_queue_empty() -> void:
	var g := _clean()
	g.press(-X)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4))
	assert(g.worm.head_exit == -X, "큐가 비면 직진")
	assert(g.worm.length() == 3)
	assert(g.alpha >= 0.0 and g.alpha < 1.0)

func _test_queue_turns_next_cell() -> void:
	var g := _clean()
	g.press(-X)
	g.press(Y)
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 4, 4), "이미 정해진 출구로 먼저 간다")
	assert(g.worm.head_exit == Y, "새 칸의 출구는 큐에서 꺼낸 방향")
	assert(g.queue.is_empty())
	_one_step(g)
	assert(g.worm.head() == Vector3i(3, 5, 4), "다음 걸음에 꺾인다")

func _test_wall_death() -> void:
	var g := _clean(Vector3i(0, 4, 4))
	g.press(-X)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "상자 밖으로 나가면 죽는다")
	assert(g.alpha == Tuning.DEATH_STOP, "머리 앞면이 벽 면에 닿는 자리에서 멈춘다: %f" % g.alpha)
	assert(g.worm.head() == Vector3i(0, 4, 4))
	g.advance(1.0)
	assert(g.alpha == Tuning.DEATH_STOP, "죽은 뒤에는 진행하지 않는다")
	assert(not g.press(Y), "죽은 뒤에는 입력을 받지 않는다")

func _test_rock_death() -> void:
	var g := _clean()
	g.field.rocks[Vector3i(3, 4, 4)] = true
	g.press(-X)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "바위에 부딪히면 죽는다")

func _test_body_death() -> void:
	var g := _clean(Vector3i(2, 4, 4), 5)
	g.press(Z)
	g.press(X)
	g.press(-Z)
	_one_step(g)
	_one_step(g)
	assert(g.state == Game.State.RUNNING)
	_one_step(g)
	assert(g.state == Game.State.DEAD, "자기 몸에 부딪히면 죽는다")

func _test_tail_follow_allowed() -> void:
	var g := _clean(Vector3i(2, 4, 4), 4)
	g.press(Z)
	g.press(X)
	g.press(-Z)
	for i in 3:
		_one_step(g)
	assert(g.state == Game.State.RUNNING, "막 비워지는 꼬리 칸으로는 들어가도 된다")
	assert(g.worm.head() == Vector3i(3, 4, 4))

# 막힌 칸 앞에서는 어떤 프레임 간격으로 와도 DEATH_STOP 을 넘지 않는다.
func _test_stop_before_obstacle_every_frame() -> void:
	for dt in [1.0 / 144.0, 1.0 / 60.0, 1.0 / 20.0, 0.5]:
		var g := _clean()
		g.field.rocks[Vector3i(3, 4, 4)] = true
		g.press(-X)
		for i in 400:
			g.advance(dt)
			assert(g.alpha <= Tuning.DEATH_STOP, "막힌 칸 앞에서 머리가 장애물에 박혔다: %f (dt %f)" % [g.alpha, dt])
		assert(g.state == Game.State.DEAD and g.worm.head() == Vector3i(4, 4, 4), "바위 앞 칸에서 멈춰 죽는다")

func _test_eating() -> void:
	var g := _clean()
	g.field.bugs.assign([Vector3i(3, 4, 4), Vector3i(0, 0, 0), Vector3i(7, 7, 7)])
	g.press(-X)
	_one_step(g)
	assert(g.score == 1, "벌레 한 마리 = 1점")
	assert(g.worm.length() == 4, "한 마디 자란다")
	assert(g.worm.cells[3] == Vector3i(6, 4, 4), "꼬리가 제자리에 남는다")
	assert(g.just_grew)
	assert(is_equal_approx(g.speed, Tuning.SPEED_START + Tuning.SPEED_STEP), "먹으면 속도가 오른다: %f" % g.speed)
	assert(g.field.bugs.size() == 3, "먹으면 새 벌레가 생겨 3마리를 유지한다")
	assert(not g.field.bugs.has(Vector3i(3, 4, 4)), "먹은 벌레는 사라진다")
	for b in g.field.bugs:
		assert(not g.worm.cell_set().has(b), "새 벌레가 지렁이 위에 생겼다")
	_one_step(g)
	assert(not g.just_grew, "다음 걸음에는 자라지 않는다")
	assert(g.worm.length() == 4)

func _test_speed_cap() -> void:
	var g := _clean()
	g.speed = Tuning.SPEED_MAX - Tuning.SPEED_STEP * 0.5
	g.field.bugs.assign([Vector3i(3, 4, 4), Vector3i(2, 4, 4)])
	g.press(-X)
	_one_step(g)
	assert(g.speed == Tuning.SPEED_MAX, "최대 속도에서 멈춘다: %f" % g.speed)
	_one_step(g)
	assert(g.speed == Tuning.SPEED_MAX, "최대에서 더 오르지 않는다: %f" % g.speed)

func _test_paused_freezes() -> void:
	var g := _clean()
	g.press(-X)
	g.paused = true
	g.advance(0.2)
	assert(g.alpha == 0.0, "회전 중에는 진행하지 않는다")
	g.paused = false
	g.advance(0.1)
	assert(g.alpha > 0.0)

func _test_new_game_layout() -> void:
	for seed in 30:
		var g := Game.new(seed)
		assert(g.worm.length() == Tuning.START_LENGTH and g.worm.head() == Tuning.START_HEAD)
		assert(g.field.rocks.size() == Tuning.ROCK_COUNT, "바위 수")
		assert(g.field.bugs.size() == Tuning.BUG_COUNT, "벌레 수")
		var worm := g.worm.cell_set()
		for b in g.field.bugs:
			assert(not worm.has(b) and not g.field.rocks.has(b), "벌레는 빈 칸에만")

# 아무렇게나 눌러 수천 걸음을 진행하며 매 걸음 불변식을 본다.
func _test_bugs_stay_valid_in_random_play() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dirs: Array[Vector3i] = [X, -X, Y, -Y, Z, -Z]
	var g := Game.new(0)
	var games := 0
	var steps := 0
	while steps < 3000:
		if g.state == Game.State.DEAD:
			games += 1
			g = Game.new(games)
		if rng.randf() < 0.08 or g.state == Game.State.WAITING:
			g.press(dirs[rng.randi_range(0, 5)])
		var before := g.worm.head()
		g.advance(FRAME)
		if g.worm.head() != before:
			steps += 1
			assert(g.field.bugs.size() == Tuning.BUG_COUNT, "벌레 수가 늘 같다")
			var worm := g.worm.cell_set()
			assert(worm.size() == g.worm.length(), "지렁이가 자기 칸과 겹친다")
			for b in g.field.bugs:
				assert(not worm.has(b) and not g.field.rocks.has(b), "벌레가 빈 칸이 아닌 곳에 있다")
			for c in g.worm.cells:
				assert(g.field.in_bounds(c) and not g.field.rocks.has(c), "지렁이가 상자 밖이나 바위 위에 있다")

func _test_perf_worm() -> void:
	var g := Game.new(5, true)
	var cells := Tuning.BOX * Tuning.BOX * Tuning.BOX
	assert(g.worm.length() == mini(Tuning.PERF_LENGTH, cells - Tuning.BUG_COUNT), "성능 확인용 지렁이 길이")
	assert(g.field.rocks.is_empty(), "성능 확인용 판에는 바위가 없다")
	assert(g.field.bugs.size() == Tuning.BUG_COUNT)
	for j in range(1, g.worm.length()):
		var d := g.worm.cells[j - 1] - g.worm.cells[j]
		assert(absi(d.x) + absi(d.y) + absi(d.z) == 1, "마디가 끊겼다")
		assert(g.worm.entries[j - 1] == d, "입구 방향이 실제 이동과 다르다")
```

- [ ] **Step 2: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_game.gd`. 나머지는 OK.

- [ ] **Step 3: 구현 — `scripts/game.gd`**

```gdscript
class_name Game
extends RefCounted

# 규칙 전부: 입력 큐, 진행률, 걸음, 먹기, 죽음. 노드를 쓰지 않아 헤드리스로 검사한다.

enum State { WAITING, RUNNING, DEAD }

var worm: Worm
var field: Field
var state := State.WAITING
var alpha := 0.0              # 머리가 지금 칸을 지난 비율. 0 = 입구 면, 1 = 출구 면
var speed := Tuning.SPEED_START
var score := 0
var queue: Array[Vector3i] = []
var paused := false           # 맵 회전 중이면 밖에서 켠다
var just_grew := false        # 이번 걸음에 꼬리가 자랐는가(새 꼬리가 부풀어 오르는 연출용)

func _init(seed: int = 0, perf := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	field = Field.new(Tuning.BOX, rng)
	if perf:
		var path := Worm.serpentine_path(Tuning.BOX)
		# 상자를 줄여도 벌레 놓을 칸은 남긴다.
		var n := mini(Tuning.PERF_LENGTH, path.size() - Tuning.BUG_COUNT)
		var body: Array[Vector3i] = []
		for i in range(n - 1, -1, -1):
			body.append(path[i])
		worm = Worm.from_cells(body)
	else:
		worm = Worm.straight(Tuning.START_HEAD, Tuning.START_DIR, Tuning.START_LENGTH)
		field.place_rocks(Tuning.ROCK_COUNT, worm.cells, Tuning.ROCK_CLEAR_RADIUS)
	for i in Tuning.BUG_COUNT:
		field.spawn_bug(worm.cell_set())

# 월드 방향 입력. 받아들였으면 true.
func press(dir: Vector3i) -> bool:
	if state == State.WAITING:
		if dir == -worm.entries[0]:
			return false  # 목 쪽으로는 출발할 수 없다
		worm.head_exit = dir
		state = State.RUNNING
		return true
	if state != State.RUNNING:
		return false
	var last: Vector3i = queue.back() if not queue.is_empty() else worm.head_exit
	if dir == last or dir == -last or queue.size() >= Tuning.QUEUE_MAX:
		return false
	queue.append(dir)
	return true

func advance(delta: float) -> void:
	if state != State.RUNNING or paused:
		return
	alpha += minf(speed * delta, Tuning.MAX_STEP_PER_FRAME)
	# 다음 칸이 막혔으면 머리 앞면이 그 면에 닿는 순간 멈춘다. 몸 칸은 걸음 이벤트에서만 바뀌므로
	# 여기서 보나 걸음 이벤트에서 보나 결과가 같다(출구는 칸에 들어설 때 이미 정해졌다).
	if alpha >= Tuning.DEATH_STOP and blocked(worm.head() + worm.head_exit):
		alpha = Tuning.DEATH_STOP
		state = State.DEAD
		return
	if alpha >= 1.0:
		_step()

# 머리가 c 로 들어가면 죽는가. 현재 꼬리 칸은 그 걸음에 비워지므로 통과다.
func blocked(c: Vector3i) -> bool:
	return not field.in_bounds(c) or field.has_rock(c) or worm.blocks(c)

# 머리가 출구 면을 넘는 순간. 막힌 칸은 advance 가 먼저 걸러낸다.
func _step() -> void:
	var next := worm.head() + worm.head_exit
	alpha -= 1.0
	just_grew = field.has_bug(next)
	if just_grew:
		field.remove_bug(next)
		score += 1
		speed = minf(speed + Tuning.SPEED_STEP, Tuning.SPEED_MAX)
	worm.step(just_grew)
	if just_grew:
		field.spawn_bug(worm.cell_set())
	worm.head_exit = queue.pop_front() if not queue.is_empty() else worm.entries[0]
```

- [ ] **Step 4: 통과 확인**

Run: `./run_tests.sh`
Expected: `test_field: OK`, `test_game: OK`, `test_worm: OK`, `전체 통과`. (`test_game` 은 무작위 3000걸음을 돌려 몇 초 걸린다.)

- [ ] **Step 5: 커밋**

```bash
git add scripts/game.gd scripts/game.gd.uid tests/test_game.gd tests/test_game.gd.uid
git commit -m "feat: 입력 큐, 걸음, 먹기, 죽음 규칙"
```

- [ ] **Step 6: 2단계 병합, 3단계 브랜치**

```bash
./run_tests.sh
git checkout main && git merge --ff-only stage2-rules && git branch -d stage2-rules
git checkout -b stage3-first-play
```

---

## 3단계: 데스크톱 첫 플레이

### Task 4: 경로 수학 (`WormPath`)

**Files:**
- Create: `scripts/worm_path.gd`
- Test: `tests/test_worm_path.gd`

**Interfaces:**
- Consumes: `Worm.cells`/`entries`/`refs`/`exit_of`/`head`/`length`, `Game`(무작위 플레이 테스트), `Tuning`
- Produces: `WormPath`(정적 함수만): `center(c: Vector3i) -> Vector3`, `turns(d_in: Vector3i, d_out: Vector3i) -> bool`, `point(c: Vector3i, d_in: Vector3i, d_out: Vector3i, a: float) -> Vector3`, `tangent(d_in: Vector3i, d_out: Vector3i, a: float) -> Vector3`, `pose(d: Vector3i, r: Vector3i) -> Basis`, `exit_ref(d_out: Vector3i, r: Vector3i) -> Vector3i`, `basis(d_in: Vector3i, d_out: Vector3i, r: Vector3i, a: float) -> Basis`, `segment(worm: Worm, j: int, a: float) -> Transform3D`
- 뜻: 칸 안 경로는 직진이면 입구 면 중심 → 출구 면 중심 직선, 꺾이면 반지름 0.5 의 4분원이다(spec 6절). 마디 j 는 진행률 `game.alpha` 로 자기 칸 j 안에 놓인다.

- [ ] **Step 1: 실패하는 테스트 쓰기 — `tests/test_worm_path.gd`**

```gdscript
extends SceneTree

const X := Vector3i(1, 0, 0)
const Y := Vector3i(0, 1, 0)
const Z := Vector3i(0, 0, 1)
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const EPS := 1e-4

func _initialize() -> void:
	_test_straight_points()
	_test_turn_points()
	_test_pose_rules()
	_test_basis_ends_and_tangent()
	_test_u_turn_comes_out_upright()
	_test_random_play_inside_cells_and_continuous()
	print("test_worm_path: OK")
	quit()

func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < EPS

func _same_basis(a: Basis, b: Basis) -> bool:
	return _near(a.x, b.x) and _near(a.y, b.y) and _near(a.z, b.z)

func _test_straight_points() -> void:
	var c := Vector3i(0, 0, 0)
	assert(_near(WormPath.point(c, X, X, 0.0), Vector3(0, 0.5, 0.5)), "입구 면 중심")
	assert(_near(WormPath.point(c, X, X, 1.0), Vector3(1, 0.5, 0.5)), "출구 면 중심")
	assert(_near(WormPath.point(c, X, Vector3i.ZERO, 0.0), Vector3(0, 0.5, 0.5)), "출구가 없으면 직진으로 본다")

func _test_turn_points() -> void:
	var c := Vector3i(1, 0, 0)
	assert(_near(WormPath.point(c, X, Y, 0.0), Vector3(1, 0.5, 0.5)), "꺾여도 입구 면 중심에서 시작")
	assert(_near(WormPath.point(c, X, Y, 1.0), Vector3(1.5, 1.0, 0.5)), "출구 면(+Y) 중심에서 끝")
	for i in 11:
		var p := WormPath.point(c, X, Y, i / 10.0)
		assert(absf(p.distance_to(Vector3(1, 1, 0.5)) - 0.5) < EPS, "모서리 중점을 중심으로 반지름 0.5")
	assert(_near(WormPath.tangent(X, Y, 0.0), Vector3(X)) and _near(WormPath.tangent(X, Y, 1.0), Vector3(Y)))

func _test_pose_rules() -> void:
	var b := WormPath.pose(-X, -X)
	assert(_near(-b.z, Vector3(-X)), "정면(-Z)이 진행 방향")
	assert(_near(b.y, Vector3.UP), "수평이면 윗면이 +Y")
	var up := WormPath.pose(Y, X)
	assert(_near(-up.z, Vector3(Y)) and _near(up.y, Vector3(-X)), "+X 로 가다 올라가면 윗면이 -X")
	var down := WormPath.pose(-Y, X)
	assert(_near(-down.z, Vector3(-Y)) and _near(down.y, Vector3(X)), "+X 로 가다 내려가면 윗면이 +X")

# 모든 꺾임 조합에서 양 끝 자세가 맞고, 앞(-Z)이 경로 접선을 정확히 따른다.
func _test_basis_ends_and_tangent() -> void:
	for d_in in DIRS:
		for d_out in DIRS:
			if d_out == d_in or d_out == -d_in:
				continue
			var refs: Array = [d_in] if d_in.y == 0 else [X, -X, Z, -Z]
			for r in refs:
				assert(_same_basis(WormPath.basis(d_in, d_out, r, 0.0), WormPath.pose(d_in, r)), "입구 자세 %s→%s" % [d_in, d_out])
				assert(_same_basis(WormPath.basis(d_in, d_out, r, 1.0), WormPath.pose(d_out, WormPath.exit_ref(d_out, r))), "출구 자세 %s→%s r=%s" % [d_in, d_out, r])
				for i in 11:
					var a := i / 10.0
					var b := WormPath.basis(d_in, d_out, r, a)
					assert(_near(-b.z, WormPath.tangent(d_in, d_out, a)), "앞이 접선과 다르다 %s→%s a=%f" % [d_in, d_out, a])
					assert(b.is_equal_approx(b.orthonormalized()), "자세가 직교가 아니다")

func _test_u_turn_comes_out_upright() -> void:
	# +X 로 가다 올라간 뒤(-X 가 윗면) 되돌아 -X 로 꺾는 칸.
	var b := WormPath.basis(Y, -X, X, 1.0)
	assert(_near(b.y, Vector3.UP), "되돌아 나온 머리는 바로 서야 한다: %s" % b.y)

# 아무렇게나 눌러 진행하며 (1) 모든 마디가 자기 칸 안에 있고 (2) 걸음이 바뀌는 순간 위치·자세가 이어지는지 본다.
func _test_random_play_inside_cells_and_continuous() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var g := Game.new(0)
	var games := 0
	var steps := 0
	var turns := 0
	while steps < 3000:
		if g.state == Game.State.DEAD:
			games += 1
			g = Game.new(games)
		if rng.randf() < 0.1 or g.state == Game.State.WAITING:
			g.press(DIRS[rng.randi_range(0, 5)])
		var w := g.worm
		var before: Array[Transform3D] = []
		for j in w.length():
			before.append(WormPath.segment(w, j, 1.0))
		var head := w.head()
		g.advance(1.0 / 60.0)
		for j in w.length():
			var p := WormPath.segment(w, j, g.alpha).origin - Vector3(w.cells[j])
			assert(p.x > -EPS and p.y > -EPS and p.z > -EPS and p.x < 1 + EPS and p.y < 1 + EPS and p.z < 1 + EPS, "마디 %d 가 자기 칸 밖에 있다: %s" % [j, p])
		if w.head() != head:
			steps += 1
			if WormPath.turns(w.entries[1], w.entries[0]):
				turns += 1
			for j in before.size():
				var after := WormPath.segment(w, j, 0.0)
				assert(_near(before[j].origin, after.origin), "걸음이 바뀔 때 마디 %d 위치가 튄다" % j)
				assert(_same_basis(before[j].basis, after.basis), "걸음이 바뀔 때 마디 %d 자세가 튄다" % j)
	assert(turns > 300, "꺾임을 충분히 검사하지 못했다: %d" % turns)
```

- [ ] **Step 2: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_worm_path.gd`. 나머지는 OK.

- [ ] **Step 3: 구현 — `scripts/worm_path.gd`**

```gdscript
class_name WormPath
extends RefCounted

# 칸 기록 + 진행률 → 마디의 위치와 자세. 순수 수학이다.
# 칸 안 경로: 직진이면 입구 면 중심 → 출구 면 중심 직선, 꺾이면 두 면 중심을 잇는 반지름 0.5 의 4분원.

static func center(c: Vector3i) -> Vector3:
	return Vector3(c) + Vector3(0.5, 0.5, 0.5)

static func turns(d_in: Vector3i, d_out: Vector3i) -> bool:
	return d_out != Vector3i.ZERO and d_out != d_in

static func point(c: Vector3i, d_in: Vector3i, d_out: Vector3i, a: float) -> Vector3:
	var fin := Vector3(d_in)
	var start := center(c) - fin * 0.5
	if not turns(d_in, d_out):
		return start + fin * a
	var fout := Vector3(d_out)
	var t := a * PI * 0.5
	# 원의 중심은 입구 면과 출구 면이 만나는 모서리의 중점이다.
	return start + fout * 0.5 - fout * (0.5 * cos(t)) + fin * (0.5 * sin(t))

static func tangent(d_in: Vector3i, d_out: Vector3i, a: float) -> Vector3:
	if not turns(d_in, d_out):
		return Vector3(d_in)
	var t := a * PI * 0.5
	return Vector3(d_in) * cos(t) + Vector3(d_out) * sin(t)

# 진행 방향 d, 기준 수평 방향 r 일 때의 자세. 모델 정면은 -Z.
# 수평이면 윗면이 +Y, 수직이면 직전 수평 자세에서 피치만 한 자세다.
static func pose(d: Vector3i, r: Vector3i) -> Basis:
	var up := Vector3.UP
	if d.y > 0:
		up = -Vector3(r)
	elif d.y < 0:
		up = Vector3(r)
	return Basis.looking_at(Vector3(d), up)

static func exit_ref(d_out: Vector3i, r: Vector3i) -> Vector3i:
	return d_out if d_out.y == 0 else r

# 꺾이는 칸에서는 꺾이는 축으로 돌리며(앞이 접선을 정확히 따른다) 출구 자세와의
# 남은 차이(앞 방향 둘레의 비틀림)를 a 만큼 나눠 푼다. 위로 갔다가 되돌아가는
# U턴처럼 순수 피치만으로는 거꾸로 서게 되는 경우에도 연속으로 바로 선다.
static func basis(d_in: Vector3i, d_out: Vector3i, r: Vector3i, a: float) -> Basis:
	var b_in := pose(d_in, r)
	if not turns(d_in, d_out):
		return b_in
	var axis := Vector3(d_in).cross(Vector3(d_out))
	var b_end := Basis(axis, PI * 0.5) * b_in
	var want := pose(d_out, exit_ref(d_out, r))
	var roll := b_end.y.signed_angle_to(want.y, Vector3(d_out))
	var b := Basis(axis, PI * 0.5 * a) * b_in
	return Basis(tangent(d_in, d_out, a), roll * a) * b

# 마디 j(머리 = 0) 의 변환. 크기는 1 이다.
static func segment(worm: Worm, j: int, a: float) -> Transform3D:
	var d_in := worm.entries[j]
	var d_out := worm.exit_of(j)
	return Transform3D(basis(d_in, d_out, worm.refs[j], a), point(worm.cells[j], d_in, d_out, a))
```

- [ ] **Step 4: 통과 확인**

Run: `./run_tests.sh`
Expected: `test_worm_path: OK` 포함 `전체 통과`.

- [ ] **Step 5: 커밋**

```bash
git add scripts/worm_path.gd scripts/worm_path.gd.uid tests/test_worm_path.gd tests/test_worm_path.gd.uid
git commit -m "feat: 칸 기록으로 마디 위치와 자세를 계산하는 경로 수학"
```

### Task 5: 등각 카메라와 회전 (`CameraRig`)

**Files:**
- Create: `scripts/camera_rig.gd`
- Test: `tests/test_camera_rig.gd`

**Interfaces:**
- Consumes: `Tuning.BOX`, `Tuning.TURN_TIME`
- Produces: `CameraRig`(`Node3D`): 상수 `PITCH_DEG`, `YAW_BASE_DEG`, `VIEW_WIDTH`, `UNITS_PER_PX`, `BOX_CENTER_Y_PX`, `AXES`; `camera: Camera3D`, `yaw_step: int`(목표 시점 0~3, 회전 버튼을 누르는 즉시 바뀐다), `frame_box() -> void`, `static screen_vector(axis: Vector3, yaw_deg: float) -> Vector2`(정사영에서 월드 방향이 화면에 비치는 벡터, (오른쪽, 위)), `static axis_for(screen_dir: int, yaw_deg: float) -> Vector3i`, `world_dir(screen_dir: int) -> Vector3i`, `turn(dir: int) -> void`(+1 = 시계 방향: ↗ 에 있던 것이 ↘ 로 간다), `is_turning() -> bool`, `current_yaw() -> float`
- 쓰는 쪽은 `CameraRig` 를 상자 중심(`Vector3.ONE * Tuning.BOX * 0.5`)에 둔다.

- [ ] **Step 1: 실패하는 테스트 쓰기 — `tests/test_camera_rig.gd`**

```gdscript
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
```

- [ ] **Step 2: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_camera_rig.gd`. 나머지는 OK.

- [ ] **Step 3: 구현 — `scripts/camera_rig.gd`**

```gdscript
class_name CameraRig
extends Node3D

# 화면 방향 → 월드 축 변환은 이 파일만 맡는다. 다른 파일이 따로 계산하면 맵을 돌린 뒤 조작이 어긋난다.
# 화면 방향 번호 i 는 화면 각도 30° + 60°·i (화면 오른쪽이 0°, 반시계): 0 ↗, 1 ▲, 2 ↖, 3 ↙, 4 ▼, 5 ↘.

const PITCH_DEG := -35.26439     # -atan(1/√2). 세 축이 화면에 같은 길이, 60° 간격으로 보이는 정확한 등각
const YAW_BASE_DEG := 45.0
const VIEW_WIDTH := Tuning.BOX * 1.55  # 설계 화면 폭 720px 에 담는 월드 길이. 45° 자세의 상자 폭 BOX·√2 에 여백 약 10%
const UNITS_PER_PX := VIEW_WIDTH / 720.0
const BOX_CENTER_Y_PX := 480.0   # 상자 중심을 화면 위에서 이만큼 아래에 둔다. 그 아래는 컨트롤러 자리
const AXES: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var camera := Camera3D.new()
var yaw_step := 0                # 목표 시점(0~3). 회전 버튼을 누르는 즉시 바뀐다
var _yaw_target := YAW_BASE_DEG  # 진행 중인 트윈의 중간값에 90°를 더하면 단계와 어긋나므로 따로 누적한다
var _tween: Tween = null

func _init() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# 직교 투영이라 거리는 보이는 크기와 무관하다. 상자를 다 담을 만큼만 물러난다.
	camera.position = Vector3(0, 0, 30)
	camera.far = 60.0
	add_child(camera)
	rotation_degrees = Vector3(PITCH_DEG, YAW_BASE_DEG, 0.0)

func _ready() -> void:
	frame_box()

func _process(_delta: float) -> void:
	frame_box()

# 화면 비율이 달라도(긴 폰, 가로로 넓은 데스크톱 창) 1px 당 월드 길이를 설계 화면과 같게 두고,
# 상자 중심을 위에서 BOX_CENTER_Y_PX 자리에 둔다. 웹은 시작 뒤에 캔버스 크기가 바뀌므로 매 프레임 맞춘다.
func frame_box() -> void:
	var vp := get_viewport().get_visible_rect().size
	camera.size = vp.y * UNITS_PER_PX
	camera.v_offset = -(vp.y * 0.5 - BOX_CENTER_Y_PX) * UNITS_PER_PX

# 정사영에서 월드 방향이 화면에 비치는 벡터 (화면 오른쪽, 화면 위). 월드 1 단위 기준.
static func screen_vector(axis: Vector3, yaw_deg: float) -> Vector2:
	var b := Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(yaw_deg), 0.0))
	return Vector2(axis.dot(b.x), axis.dot(b.y))

static func axis_for(screen_dir: int, yaw_deg: float) -> Vector3i:
	var want := Vector2.from_angle(deg_to_rad(30.0 + 60.0 * screen_dir))
	var best := AXES[0]
	var best_dot := -INF
	for a in AXES:
		var s := screen_vector(Vector3(a), yaw_deg).normalized().dot(want)
		if s > best_dot:
			best_dot = s
			best = a
	return best

# 버튼을 누른 순간의 목표 시점 기준. 회전 중이면 회전이 끝난 뒤의 시점이다.
func world_dir(screen_dir: int) -> Vector3i:
	return axis_for(screen_dir, YAW_BASE_DEG + 90.0 * yaw_step)

# +1 이면 맵이 시계 방향으로 돈다(↗ 에 있던 것이 ↘ 로 간다).
func turn(dir: int) -> void:
	yaw_step = posmod(yaw_step + dir, 4)
	_yaw_target += 90.0 * dir
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", _yaw_target, Tuning.TURN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func is_turning() -> bool:
	return _tween != null and _tween.is_running()

# 지금 화면의 실제 각도(회전 중이면 중간 값).
func current_yaw() -> float:
	return rotation_degrees.y
```

- [ ] **Step 4: 통과 확인**

Run: `./run_tests.sh`
Expected: `test_camera_rig: OK` 포함 `전체 통과`.

- [ ] **Step 5: 커밋**

```bash
git add scripts/camera_rig.gd scripts/camera_rig.gd.uid tests/test_camera_rig.gd tests/test_camera_rig.gd.uid
git commit -m "feat: 등각 직교 카메라, 맵 회전, 화면 방향 → 월드 축 변환"
```

### Task 6: 그리기 (셰이더, `WormView`, `FieldView`)

**Files:**
- Create: `shaders/worm.gdshader`, `shaders/xray.gdshader`, `shaders/soil_box.gdshader`, `shaders/layer_plane.gdshader`, `scripts/worm_view.gd`, `scripts/field_view.gd`
- Test: `tests/test_worm_view.gd`, `tests/test_field_view.gd`

**Interfaces:**
- Consumes: `Game`(`worm`, `field`, `alpha`, `state`, `queue`, `just_grew`), `WormPath.segment`/`center`, `Tuning`
- Produces:
  - `WormView`(`Node3D`): `game: Game`, `head: MeshInstance3D`, `body: MultiMeshInstance3D`, `static material(color: Color, emission := 0.0, xray := false) -> ShaderMaterial`, `static tail_scale(k: float) -> float`, `static body_transform(g: Game, j: int, time: float) -> Transform3D`, `setup(g: Game) -> void`, `_update(delta: float) -> void`
  - `FieldView`(`Node3D`): `game: Game`, `box: MeshInstance3D`, `rocks: MultiMeshInstance3D`, `plane: MeshInstance3D`, `bugs`/`rings`/`stems: Array[MeshInstance3D]`, `setup(g: Game) -> void`, `_update() -> void`
- 임시 도형이다(머리·몸·바위는 상자, 벌레는 공). 5단계에서 Blender 에셋으로 바꾼다.

- [ ] **Step 1: 실패하는 테스트 쓰기 — `tests/test_worm_view.gd`**

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_tail_scale()
	_test_instances_follow_path()
	_test_new_tail_grows_from_zero()
	print("test_worm_view: OK")
	quit()

func _test_tail_scale() -> void:
	assert(WormView.tail_scale(-1.0) == 0.0, "막 돋아나는 마디는 크기 0")
	assert(is_equal_approx(WormView.tail_scale(0.0), Tuning.TAIL_TAPER[0]), "꼬리 끝 마디")
	assert(is_equal_approx(WormView.tail_scale(2.5), lerpf(Tuning.TAIL_TAPER[2], 1.0, 0.5)), "사이 값은 보간")
	assert(WormView.tail_scale(3.0) == 1.0 and WormView.tail_scale(40.0) == 1.0, "꼬리에서 먼 마디는 제 크기")
	for i in 400:
		var k := -1.0 + i * 0.01
		assert(absf(WormView.tail_scale(k + 0.01) - WormView.tail_scale(k)) < 0.07, "꼬리 크기가 튄다: k=%f" % k)

func _game_moving_up() -> Game:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.clear()
	g.press(Vector3i(0, 1, 0))
	for i in 20:
		g.advance(1.0 / 60.0)
	return g

func _test_instances_follow_path() -> void:
	var g := _game_moving_up()
	var wv := WormView.new()
	root.add_child(wv)
	wv.setup(g)
	assert(wv.body.multimesh.visible_instance_count == g.worm.length() - 1, "몸 마디 수 = 길이 - 1")
	# 헤드리스의 MultiMesh 는 넣은 값을 돌려주지 않으므로(더미 렌더러) 넣기 전 계산을 본다.
	for j in range(1, g.worm.length()):
		var want := WormPath.segment(g.worm, j, g.alpha).origin
		assert(WormView.body_transform(g, j, 0.0).origin.distance_to(want) < 1e-4, "마디 %d 가 경로 위치에 없다" % j)
	assert(wv.head.transform.origin.distance_to(WormPath.segment(g.worm, 0, g.alpha).origin) < 1e-4, "머리가 경로 위치에 없다")
	wv.queue_free()

func _test_new_tail_grows_from_zero() -> void:
	var g := Game.new(3)
	g.field.rocks.clear()
	g.field.bugs.assign([Vector3i(3, 4, 4)])
	g.press(Vector3i(-1, 0, 0))
	while g.worm.length() == 3:
		g.advance(1.0 / 60.0)
	var last := WormView.body_transform(g, g.worm.length() - 1, 0.0).basis.get_scale().z
	assert(last <= Tuning.TAIL_TAPER[0] * g.alpha + 0.01, "새 꼬리는 크기 0 에서 부풀어야 한다: %f (alpha %f)" % [last, g.alpha])
	var before := WormView.body_transform(g, g.worm.length() - 2, 0.0).basis.get_scale().z
	assert(absf(before - Tuning.TAIL_TAPER[0]) < 0.12, "원래 꼬리는 자라는 걸음 처음에 원래 크기를 유지한다: %f" % before)
```

- [ ] **Step 2: 실패하는 테스트 쓰기 — `tests/test_field_view.gd`**

```gdscript
extends SceneTree

func _initialize() -> void:
	_test_layer_plane_follows_head()
	_test_bug_markers()
	print("test_field_view: OK")
	quit()

func _game() -> Game:
	var g := Game.new(2)
	g.field.bugs.assign([Vector3i(1, 4, 1), Vector3i(6, 1, 6), Vector3i(2, 7, 5)])
	return g

func _view(g: Game) -> FieldView:
	var fv := FieldView.new()
	root.add_child(fv)
	fv.setup(g)
	return fv

func _test_layer_plane_follows_head() -> void:
	var g := _game()
	var fv := _view(g)
	assert(fv.rocks.multimesh.instance_count == g.field.rocks.size(), "바위 수만큼 그린다")
	g.press(Vector3i(0, 1, 0))
	for i in 10:
		g.advance(1.0 / 60.0)
		fv._update()
		var head_y := WormPath.segment(g.worm, 0, g.alpha).origin.y
		assert(absf(fv.plane.position.y - head_y) < 1e-4, "머리 층 판은 머리 높이를 따라간다")
	fv.queue_free()

func _test_bug_markers() -> void:
	var g := _game()
	var fv := _view(g)
	# 출발 전 머리는 칸 (4,4,4) 의 입구 면, 높이 4.5. 벌레 (1,4,1) 은 같은 층이라 기둥이 없다.
	assert(fv.rings[0].visible and not fv.stems[0].visible, "같은 층 벌레는 고리만")
	assert(fv.stems[1].visible and fv.stems[2].visible, "다른 층 벌레는 기둥이 있다")
	assert(absf(fv.stems[1].scale.y - 3.0) < 1e-4, "기둥 길이 = 높이 차(4.5 - 1.5): %f" % fv.stems[1].scale.y)
	var ring := fv.rings[1].position
	assert(ring.distance_to(Vector3(6.5, 4.5, 6.5)) < 1e-4, "고리는 판 위, 벌레와 같은 (x, z): %s" % ring)
	g.field.bugs.remove_at(2)
	fv._update()
	assert(not fv.bugs[2].visible and not fv.rings[2].visible and not fv.stems[2].visible, "없는 벌레의 표시는 숨긴다")
	fv.queue_free()
```

- [ ] **Step 3: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_field_view.gd`, `FAIL: test_worm_view.gd`. 나머지는 OK.

- [ ] **Step 4: 셰이더 4개**

`shaders/worm.gdshader`:

```glsl
shader_type spatial;
render_mode specular_disabled;

// 지렁이·벌레·바위가 같이 쓴다. 깊을수록 어둡게 칠해(높이 색) 화면에서 겹친 물체의 높이를 가른다.
uniform vec3 albedo : source_color = vec3(1.0);
uniform float emission = 0.0;
uniform float box_height = 8.0;
uniform float min_bright = 0.6;

void fragment() {
	float y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	vec3 base = albedo * mix(min_bright, 1.0, clamp(y / box_height, 0.0, 1.0));
	ALBEDO = base;
	EMISSION = base * emission;
}
```

`shaders/xray.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_back, blend_mix;

// 비침: 깊이 검사를 뒤집어 다른 물체에 가려진 부분에만 그린다.
// 자기 겉면과 깊이가 같아 얼룩지지 않도록 카메라 쪽으로 pull 만큼 당긴다(직교 투영이라 화면 위치는 그대로).
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.7, 0.55);
uniform float pull = 0.05;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.z += pull;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
```

`shaders/soil_box.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded;

// 흙 상자의 먼 쪽 벽 2개와 바닥. 지층 띠(깊을수록 짙게), 옅은 칸 격자, 벽 위 가장자리 풀 띠.
uniform float box_size = 8.0;
uniform vec3 top_soil : source_color = vec3(0.56, 0.39, 0.25);
uniform vec3 deep_soil : source_color = vec3(0.24, 0.15, 0.10);
uniform vec3 grass : source_color = vec3(0.38, 0.63, 0.28);
uniform float grid_strength = 0.22;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 가장 가까운 정수 격자선에 가까울수록 1.
float grid_line(float v) {
	float d = abs(fract(v + 0.5) - 0.5);
	return 1.0 - smoothstep(0.0, fwidth(v) * 1.2, d);
}

void fragment() {
	float h = clamp(v_world.y / box_size, 0.0, 1.0);
	vec3 col = mix(deep_soil, top_soil, min(floor(h * 4.0) / 3.0, 1.0));
	// 면의 법선 축은 빼고 나머지 두 축의 정수선만 긋는다.
	float g = 0.0;
	if (v_normal.x < 0.5) g = max(g, grid_line(v_world.x));
	if (v_normal.y < 0.5) g = max(g, grid_line(v_world.y));
	if (v_normal.z < 0.5) g = max(g, grid_line(v_world.z));
	col = mix(col, vec3(0.0), g * grid_strength);
	if (v_normal.y < 0.5 && v_world.y > box_size - 0.15) {
		col = grass;
	}
	ALBEDO = col;
}
```

`shaders/layer_plane.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// 머리 층 판: 판 아래 물체는 판 너머로 흐리게 보인다. 칸 격자를 옅게 긋는다.
uniform vec4 tint : source_color = vec4(0.95, 0.85, 0.6, 0.16);
uniform vec4 line : source_color = vec4(1.0, 0.95, 0.75, 0.5);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(float v) {
	float d = abs(fract(v + 0.5) - 0.5);
	return 1.0 - smoothstep(0.0, fwidth(v) * 1.2, d);
}

void fragment() {
	float g = max(grid_line(v_world.x), grid_line(v_world.z));
	ALBEDO = mix(tint.rgb, line.rgb, g);
	ALPHA = mix(tint.a, line.a, g);
}
```

- [ ] **Step 5: 구현 — `scripts/worm_view.gd`**

```gdscript
class_name WormView
extends Node3D

# 지렁이 그리기: 머리 메시 + 몸 MultiMesh. 매 프레임 게임 상태로 마디 변환을 다시 계산한다.
# 3단계는 임시 도형(상자)이다. 5단계에서 Blender 에셋으로 바꾼다.

const SHADER := preload("res://shaders/worm.gdshader")
const XRAY := preload("res://shaders/xray.gdshader")

var game: Game
var head := MeshInstance3D.new()
var body := MultiMeshInstance3D.new()
var _time := 0.0
var _glance := 0.0
var _glance_dir := Vector3.ZERO

# 공용 셰이더 재질. xray 면 가려진 부분이 비쳐 보이는 두 번째 패스를 붙인다.
static func material(color: Color, emission := 0.0, xray := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("box_height", float(Tuning.BOX))
	m.set_shader_parameter("min_bright", Tuning.DEPTH_MIN_BRIGHT)
	if xray:
		var x := ShaderMaterial.new()
		x.shader = XRAY
		m.next_pass = x
	return m

# 꼬리 끝에서 k 번째(마지막 = 0) 마디의 크기 배율. k = -1 은 막 돋아나는 마디(크기 0).
# k 가 실수여도 이어지게 보간한다. 자라는 걸음 동안 k 가 1 씩 밀리는 것을 부드럽게 넘긴다.
static func tail_scale(k: float) -> float:
	if k <= -1.0:
		return 0.0
	if k >= Tuning.TAIL_TAPER.size():
		return 1.0
	var pts: Array = [0.0] + Tuning.TAIL_TAPER + [1.0]
	var i := int(floor(k)) + 1
	return lerpf(pts[i], pts[i + 1], k - floor(k))

func _init() -> void:
	var hm := BoxMesh.new()
	hm.size = Vector3.ONE * Tuning.HEAD_SIZE
	head.mesh = hm
	head.material_override = material(Color(0.92, 0.42, 0.48), 0.0, true)
	# 눈: 진행 방향이 읽히게. 얇게 둬서 비침 패스의 당김(0.05)보다 덜 튀어나오게 한다.
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.2, 0.2, 0.04)
		eye.mesh = em
		eye.position = Vector3(0.22 * side, 0.16, -Tuning.HEAD_SIZE * 0.5)
		eye.material_override = material(Color(1, 1, 1))
		head.add_child(eye)
	add_child(head)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * Tuning.SEGMENT_SIZE
	mm.mesh = bm
	mm.instance_count = Tuning.BOX * Tuning.BOX * Tuning.BOX
	mm.visible_instance_count = 0
	body.multimesh = mm
	body.material_override = material(Color(0.95, 0.6, 0.62))
	add_child(body)

func setup(g: Game) -> void:
	game = g
	_glance = 0.0
	_update(0.0)

func _process(delta: float) -> void:
	_time += delta
	_update(delta)

# 몸 마디 j(1 이상)를 그릴 변환. 위치·자세는 경로를 그대로 따르고, 크기는 꼬리 배율 × 꿈틀거림이다.
static func body_transform(g: Game, j: int, time: float) -> Transform3D:
	var t := WormPath.segment(g.worm, j, g.alpha)
	# 자라는 걸음 동안에는 꼬리 쪽 번호가 한 칸씩 밀리는 것을 진행률로 이어 준다. 새 꼬리는 크기 0 에서 시작한다.
	var grow := 1.0 - g.alpha if g.just_grew else 0.0
	var s := tail_scale(float(g.worm.length() - 1 - j) - grow)
	# 꿈틀거림: 머리에서 꼬리로 흐르는 굵기 파동. 길이 방향(Z)은 두고 단면만 바꾼다.
	var wave := 1.0 + Tuning.WOBBLE_AMP * sin(TAU * (Tuning.WOBBLE_HZ * time - j / Tuning.WOBBLE_WAVELENGTH))
	t.basis = t.basis * Basis.from_scale(Vector3(s * wave, s * wave, s))
	return t

func _update(delta: float) -> void:
	if game == null:
		return
	var n := game.worm.length()
	var mm := body.multimesh
	mm.visible_instance_count = n - 1
	for j in range(1, n):
		mm.set_instance_transform(j - 1, body_transform(game, j, _time))
	head.transform = _head_transform(delta)

# 예고 동작: 큐의 다음 방향으로 고개를 살짝 미리 돌린다. 실제로 꺾이기 시작하면 경로 자세로 합쳐진다.
func _head_transform(delta: float) -> Transform3D:
	var t := WormPath.segment(game.worm, 0, game.alpha)
	var want := 0.0
	if game.state == Game.State.RUNNING and not game.queue.is_empty():
		want = 1.0
		_glance_dir = Vector3(game.queue[0])
	_glance = move_toward(_glance, want, delta * 8.0)
	var axis := (-t.basis.z).cross(_glance_dir)
	if _glance > 0.0 and axis.length() > 0.01:
		t.basis = Basis(axis.normalized(), deg_to_rad(Tuning.GLANCE_DEG) * _glance) * t.basis
	return t
```

- [ ] **Step 6: 구현 — `scripts/field_view.gd`**

```gdscript
class_name FieldView
extends Node3D

# 흙 상자, 바위, 벌레, 머리 층 판, 벌레 고리·기둥.

var game: Game
var box := MeshInstance3D.new()
var rocks := MultiMeshInstance3D.new()
var plane := MeshInstance3D.new()
var bugs: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var stems: Array[MeshInstance3D] = []
var _time := 0.0

func _init() -> void:
	var half := Tuning.BOX * 0.5
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * Tuning.BOX
	# 면을 안쪽으로 뒤집으면 뒷면 컬링이 어느 시점에서든 가까운 벽 2개와 윗면을 알아서 숨긴다.
	bm.flip_faces = true
	box.mesh = bm
	box.position = Vector3.ONE * half
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://shaders/soil_box.gdshader")
	box.material_override = soil
	add_child(box)

	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3.ONE * 0.9
	rm.mesh = rock_mesh
	rocks.multimesh = rm
	rocks.material_override = WormView.material(Color(0.55, 0.57, 0.6))
	add_child(rocks)

	var pm := PlaneMesh.new()
	pm.size = Vector2(Tuning.BOX, Tuning.BOX)
	plane.mesh = pm
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://shaders/layer_plane.gdshader")
	plane.material_override = pmat
	add_child(plane)

	var marker := StandardMaterial3D.new()
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color = Color(1.0, 0.85, 0.35)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.38
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.03
	stem_mesh.height = 1.0
	var bug_mesh := SphereMesh.new()
	bug_mesh.radius = 0.28
	bug_mesh.height = 0.56
	var bug_mat := WormView.material(Color(1.0, 0.86, 0.45), 0.6, true)
	for i in Tuning.BUG_COUNT:
		bugs.append(_mesh(bug_mesh, bug_mat))
		rings.append(_mesh(ring_mesh, marker))
		stems.append(_mesh(stem_mesh, marker))

func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	add_child(m)
	return m

func setup(g: Game) -> void:
	game = g
	var rm := rocks.multimesh
	rm.instance_count = g.field.rocks.size()
	var i := 0
	for c in g.field.rocks:
		rm.set_instance_transform(i, Transform3D(Basis(), WormPath.center(c)))
		i += 1
	_update()

func _process(delta: float) -> void:
	_time += delta
	_update()

func _update() -> void:
	if game == null:
		return
	var head_y := WormPath.segment(game.worm, 0, game.alpha).origin.y
	var half := Tuning.BOX * 0.5
	plane.position = Vector3(half, head_y, half)
	for i in Tuning.BUG_COUNT:
		var has := i < game.field.bugs.size()
		bugs[i].visible = has
		rings[i].visible = has
		stems[i].visible = false
		if not has:
			continue
		var c := game.field.bugs[i]
		var p := WormPath.center(c)
		# 꼼지락: 칸마다 위상을 달리해 셋이 같이 움직이지 않게 한다.
		bugs[i].position = p + Vector3(0, 0.06 * sin(_time * 3.0 + c.x + c.z * 1.7), 0)
		rings[i].position = Vector3(p.x, head_y, p.z)
		# 기둥은 꼼지락을 뺀 칸 중심으로 잰다. 같은 층에서 기둥이 깜빡이지 않게.
		var gap := p.y - head_y
		if absf(gap) > 0.05:
			stems[i].visible = true
			stems[i].position = Vector3(p.x, head_y + gap * 0.5, p.z)
			stems[i].scale = Vector3(1, absf(gap), 1)
```

- [ ] **Step 7: 통과 확인**

Run: `./run_tests.sh`
Expected: `test_field_view: OK`, `test_worm_view: OK` 포함 `전체 통과`.

- [ ] **Step 8: 커밋**

```bash
git status --short
git add shaders/worm.gdshader shaders/worm.gdshader.uid shaders/xray.gdshader shaders/xray.gdshader.uid shaders/soil_box.gdshader shaders/soil_box.gdshader.uid shaders/layer_plane.gdshader shaders/layer_plane.gdshader.uid scripts/worm_view.gd scripts/worm_view.gd.uid scripts/field_view.gd scripts/field_view.gd.uid tests/test_worm_view.gd tests/test_worm_view.gd.uid tests/test_field_view.gd tests/test_field_view.gd.uid
git commit -m "feat: 지렁이·흙 상자·머리 층 판·벌레 표시·비침 그리기"
```

### Task 7: 조작과 게임 화면 (`Controller`, `Hud`, `main`), 한글 폰트

**Files:**
- Create: `scripts/controller.gd`, `scripts/hud.gd`, `scripts/main.gd`, `scenes/main.tscn`, `assets/fonts/NotoSansKR-hangul.ttf`, `assets/fonts/OFL.txt`
- Modify: `project.godot`(끝에 `[gui]` 추가)
- Test: `tests/test_controller.gd`, `tests/test_main_smoke.gd`, `tests/test_font.gd`

**Interfaces:**
- Consumes: `CameraRig`(`world_dir`, `turn`, `is_turning`, `current_yaw`, `screen_vector`, `YAW_BASE_DEG`, `BOX_CENTER_Y_PX`), `Game`, `WormView.setup`, `FieldView.setup`, `Tuning.DEATH_DELAY`
- Produces:
  - `Controller`(`Control`): `signal direction_pressed(screen_dir: int)`, `signal turn_pressed(dir: int)`, 상수 `HEIGHT`, `RING`, `BUTTON`, `FACE`, `FLASH`, `KEYS`; `rig: CameraRig`, `center() -> Vector2`, `static button_dir(i: int) -> Vector2`, `diamond() -> PackedVector2Array`, `sector_at(p: Vector2) -> int`(마름모 안이면 −1)
  - `Hud`(`CanvasLayer`): `signal turn_pressed(dir: int)`, `score_label`/`info_label`/`restart_label: Label`, `set_score(v: int)`, `show_restart(on: bool)`, 안쪽 클래스 `Hud.TurnButton`(`signal pressed_dir(dir: int)`, `dir: int`)
  - `main.gd`(`scenes/main.tscn` 루트): `game`, `rig`, `field_view`, `worm_view`, `hud`, `controller`, `new_game()`, `static perf_requested() -> bool`(웹 `?perf`, 데스크톱 `-- --perf`)

- [ ] **Step 1: 실패하는 테스트 쓰기 — `tests/test_controller.gd`**

```gdscript
extends SceneTree

var _got: Array[int] = []
var _turns: Array[int] = []

func _initialize() -> void:
	_test_sectors()
	_test_dead_zone()
	_test_touch_emits_direction()
	_test_two_fingers_in_order()
	_test_drag_is_not_input()
	_test_keyboard_hexagon()
	await _test_diamond_matches_box_top()
	print("test_controller: OK")
	quit()

func _controller() -> Controller:
	var c := Controller.new()
	c.size = Vector2(720, Controller.HEIGHT)
	c.direction_pressed.connect(func(i: int) -> void: _got.append(i))
	c.turn_pressed.connect(func(d: int) -> void: _turns.append(d))
	return c

func _test_sectors() -> void:
	var c := _controller()
	for i in 6:
		for off in [-25.0, 0.0, 25.0]:
			var a := deg_to_rad(30.0 + 60.0 * i + off)
			var p := Vector2(cos(a), -sin(a)) * Controller.RING
			assert(c.sector_at(p) == i, "버튼 %d 쪽 %f° 를 눌렀는데 %d" % [i, off, c.sector_at(p)])
	c.free()

func _test_dead_zone() -> void:
	var c := _controller()
	for p in [Vector2.ZERO, Vector2(60, 0), Vector2(-60, 0), Vector2(0, 40), Vector2(0, -40)]:
		assert(c.sector_at(p) == -1, "마름모 안은 무시해야 한다: %s" % p)
	assert(c.sector_at(Vector2(0, -120)) == 1, "마름모 바로 위는 ▲")
	c.free()

func _test_touch_emits_direction() -> void:
	var c := _controller()
	_got.clear()
	for i in 6:
		var t := InputEventScreenTouch.new()
		t.pressed = true
		t.position = c.center() + Controller.button_dir(i) * Controller.RING
		c._gui_input(t)
	assert(_got == ([0, 1, 2, 3, 4, 5] as Array[int]), "버튼마다 자기 방향: %s" % [_got])
	var inside := InputEventScreenTouch.new()
	inside.pressed = true
	inside.position = c.center()
	c._gui_input(inside)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = c.center() + Controller.button_dir(0) * Controller.RING
	c._gui_input(release)
	assert(_got.size() == 6, "마름모 안 터치와 손 뗌은 입력이 아니다")
	c.free()

func _test_two_fingers_in_order() -> void:
	var c := _controller()
	_got.clear()
	for pair in [[0, 3], [1, 5]]:
		var t := InputEventScreenTouch.new()
		t.index = pair[0]
		t.pressed = true
		t.position = c.center() + Controller.button_dir(pair[1]) * Controller.RING
		c._gui_input(t)
	assert(_got == ([3, 5] as Array[int]), "두 손가락은 닿은 순서대로: %s" % [_got])
	c.free()

func _test_drag_is_not_input() -> void:
	var c := _controller()
	_got.clear()
	var d := InputEventScreenDrag.new()
	d.position = c.center() + Controller.button_dir(0) * Controller.RING
	c._gui_input(d)
	assert(_got.is_empty(), "누른 채 미끄러지는 것은 새 입력이 아니다")
	c.free()

func _test_keyboard_hexagon() -> void:
	var c := _controller()
	_got.clear()
	_turns.clear()
	for key in [KEY_E, KEY_W, KEY_Q, KEY_A, KEY_S, KEY_D, KEY_LEFT, KEY_RIGHT]:
		var k := InputEventKey.new()
		k.physical_keycode = key
		k.pressed = true
		c._unhandled_key_input(k)
	assert(_got == ([0, 1, 2, 3, 4, 5] as Array[int]), "QWE/ASD 육각 배치: %s" % [_got])
	assert(_turns == ([-1, 1] as Array[int]), "← 반시계, → 시계")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	c._unhandled_key_input(echo)
	assert(_got.size() == 6, "키를 누르고 있어 반복되는 입력은 무시")
	c.free()

# 마름모가 실제 카메라로 본 상자 윗면과 같은 모양인지(배율만 다름) 회전 4단계 모두 본다.
func _test_diamond_matches_box_top() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var rig := CameraRig.new()
	rig.position = Vector3(4, 4, 4)
	view.add_child(rig)
	rig.camera.make_current()
	var c := _controller()
	c.rig = rig
	var top := Vector3(4, 8, 4)
	for step in 4:
		rig.rotation_degrees.y = CameraRig.YAW_BASE_DEG + 90.0 * step
		await process_frame
		var o := rig.camera.unproject_position(top)
		var d := c.diamond()
		var signs := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
		var scale := -1.0
		for k in 4:
			var q := rig.camera.unproject_position(top + Vector3(4 * signs[k].x, 0, 4 * signs[k].y)) - o
			assert(q.normalized().distance_to(d[k].normalized()) < 0.01, "시점 %d 꼭짓점 %d 방향이 다르다: %s vs %s" % [step, k, q, d[k]])
			var r := q.length() / d[k].length()
			if scale < 0.0:
				scale = r
			assert(absf(r - scale) < 0.01 * scale, "마름모 비율이 상자 윗면과 다르다")
	view.queue_free()
	c.free()
```

- [ ] **Step 2: 실패하는 테스트 쓰기 — `tests/test_main_smoke.gd`**

```gdscript
extends SceneTree

# 실제 게임 화면을 띄워 몇 초 돌린다. 연결이 끊긴 곳이 있으면 여기서 SCRIPT ERROR 가 난다.
func _initialize() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	view.add_child(main)
	await process_frame
	var game: Game = main.game
	assert(game.state == Game.State.WAITING, "처음에는 출발을 기다린다")
	var ahead := -1  # 머리가 보는 쪽을 가리키는 화면 방향
	for i in 6:
		if main.rig.world_dir(i) == Tuning.START_DIR:
			ahead = i
	main.controller.direction_pressed.emit(ahead)
	assert(game.state == Game.State.RUNNING, "방향 입력으로 출발한다")
	await create_timer(0.5).timeout
	assert(game.worm.head() != Tuning.START_HEAD, "0.5초면 한 칸 넘게 간다")
	assert(main.worm_view.body.multimesh.visible_instance_count == game.worm.length() - 1, "몸 마디 수 = 길이 - 1")
	var tap_box := InputEventScreenTouch.new()
	tap_box.pressed = true
	tap_box.position = Vector2(360, 480)
	main._unhandled_input(tap_box)
	assert(main.game == game and game.state == Game.State.RUNNING, "플레이 중 상자를 탭해도 아무 일 없다")

	# HUD 의 회전 버튼(오른쪽 = 시계)을 손가락으로 누른다.
	var turn_buttons: Array = main.hud.get_children().filter(func(n: Node) -> bool: return n is Hud.TurnButton)
	assert(turn_buttons.size() == 2, "회전 버튼 2개")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	var right_button: Hud.TurnButton = turn_buttons.filter(func(b: Hud.TurnButton) -> bool: return b.dir == 1)[0]
	right_button._gui_input(tap)
	assert(main.rig.yaw_step == 1, "회전 버튼으로 맵이 돈다")
	await process_frame
	var a := game.alpha
	var head := game.worm.head()
	await create_timer(0.1).timeout
	assert(game.alpha == a and game.worm.head() == head, "맵이 도는 동안 게임이 멈춘다")
	await create_timer(Tuning.TURN_TIME + 0.1).timeout
	assert(not main.rig.is_turning())

	# 그대로 두면 벽에 부딪혀 죽는다.
	for i in 100:
		if game.state == Game.State.DEAD:
			break
		await create_timer(0.1).timeout
	assert(game.state == Game.State.DEAD, "곧장 가면 벽에 부딪힌다")
	var yaw: int = main.rig.yaw_step
	main.controller.turn_pressed.emit(1)
	assert(main.rig.yaw_step == yaw, "죽은 뒤에는 맵이 돌지 않는다")
	main.controller.direction_pressed.emit(0)
	assert(main.game == game, "죽은 직후에는 다시 시작하지 않는다")
	await create_timer(Tuning.DEATH_DELAY + 0.1).timeout
	assert(main.hud.restart_label.visible, "잠시 뒤 다시 시작 안내")
	main.controller.direction_pressed.emit(0)
	assert(main.game != game and main.game.state == Game.State.WAITING, "새 판이 시작된다")
	print("test_main_smoke: OK")
	quit()
```

- [ ] **Step 3: 실패하는 테스트 쓰기 — `tests/test_font.gd`**

```gdscript
extends SceneTree

# 웹 빌드에는 시스템 폰트가 없고 Godot 내장 폰트에는 한글이 없다. 프로젝트 폰트에 없는 글자는
# 폰에서 네모로 나온다(데스크톱은 OS 폰트로 대체돼 드러나지 않는다). 화면에 나갈 만한 글자를 전부 훑는다.
func _initialize() -> void:
	var path := str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	assert(path != "" and ResourceLoader.exists(path), "gui/theme/custom_font 가 비었거나 파일이 없다: %s" % path)
	var font: Font = load(path)
	var missing := {}
	for dir in ["res://scenes", "res://scripts"]:
		for name in DirAccess.get_files_at(dir):
			if not (name.ends_with(".tscn") or name.ends_with(".gd")):
				continue
			for c in _literal_chars("%s/%s" % [dir, name]):
				if not font.has_char(c.unicode_at(0)):
					missing[c] = name
	assert(missing.is_empty(), "폰트에 없는 글자가 문자열에 있다(네모로 나온다): %s" % missing)
	print("test_font: OK")
	quit()

# 큰따옴표 안의 글자만 모은다. 주석 줄은 화면에 나가지 않으므로 건너뛴다.
func _literal_chars(path: String) -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var s := line.strip_edges()
		if s.begins_with("#") or s.begins_with(";"):
			continue
		var parts := line.split("\"")
		for i in range(1, parts.size(), 2):
			for c in parts[i]:
				out[c] = true
	return out
```

- [ ] **Step 4: 실패 확인**

Run: `./run_tests.sh`
Expected: `FAIL: test_controller.gd`, `FAIL: test_font.gd`, `FAIL: test_main_smoke.gd`. 나머지는 OK.

- [ ] **Step 5: 구현 — `scripts/controller.gd`**

```gdscript
class_name Controller
extends Control

# 화면 아래 컨트롤러: 가운데 마름모(상자 윗면과 같은 모양) + 둘레 6방향 버튼, 그리고 키보드.
# 방향은 화면 방향 번호(CameraRig 주석)로만 내보낸다. 월드 축으로 바꾸는 건 CameraRig 몫이다.

signal direction_pressed(screen_dir: int)
signal turn_pressed(dir: int)

const HEIGHT := 400.0      # 컨트롤러 영역 높이(px)
const RING := 150.0        # 가운데에서 버튼 중심까지
const BUTTON := 54.0       # 버튼 반지름
const FACE := 80.0         # 마름모: 월드 1 단위를 이 픽셀로 그린 상자 윗면(가운데에서 각 축 ±1)
const FLASH := 0.15        # 누른 버튼이 빛나는 시간(초)
# QWE / ASD 가 컨트롤러와 같은 육각 배치. 물리 키 위치라 한/영 상태와 무관하다.
const KEYS := {KEY_E: 0, KEY_W: 1, KEY_Q: 2, KEY_A: 3, KEY_S: 4, KEY_D: 5}

var rig: CameraRig
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP

func center() -> Vector2:
	return size * 0.5

static func button_dir(i: int) -> Vector2:
	var a := deg_to_rad(30.0 + 60.0 * i)
	return Vector2(cos(a), -sin(a))

# 상자 윗면의 네 꼭짓점(가운데 기준, 화면 픽셀, 아래가 +y). 지금 화면 각도로 계산하므로
# 맵이 도는 동안에는 마름모도 상자 윗면을 따라 돈다.
func diamond() -> PackedVector2Array:
	var yaw := rig.current_yaw() if rig != null else CameraRig.YAW_BASE_DEG
	var ax := CameraRig.screen_vector(Vector3.RIGHT, yaw)
	var az := CameraRig.screen_vector(Vector3.BACK, yaw)
	var fx := Vector2(ax.x, -ax.y) * FACE
	var fz := Vector2(az.x, -az.y) * FACE
	return PackedVector2Array([fx + fz, fx - fz, -fx - fz, -fx + fz])

# 가운데 기준 위치 p 의 화면 방향 번호. 60° 부채꼴 6개로 나눈다. 마름모 안이면 -1.
func sector_at(p: Vector2) -> int:
	if Geometry2D.is_point_in_polygon(p, diamond()):
		return -1
	var ang := fposmod(rad_to_deg(atan2(-p.y, p.x)), 360.0)
	return int(ang / 60.0) % 6

func _gui_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t == null or not t.pressed:
		return
	var i := sector_at(t.position - center())
	if i >= 0:
		_press(i)
	accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if KEYS.has(k.physical_keycode):
		_press(KEYS[k.physical_keycode])
	elif k.physical_keycode == KEY_LEFT:
		turn_pressed.emit(-1)
	elif k.physical_keycode == KEY_RIGHT:
		turn_pressed.emit(1)

func _press(i: int) -> void:
	_flash[i] = FLASH
	direction_pressed.emit(i)

func _process(delta: float) -> void:
	for i in 6:
		_flash[i] = maxf(0.0, _flash[i] - delta)
	queue_redraw()

func _draw() -> void:
	var c := center()
	var pts := PackedVector2Array()
	for p in diamond():
		pts.append(c + p)
	draw_colored_polygon(pts, Color(0.95, 0.75, 0.5, 0.18))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.95, 0.8, 0.6, 0.7), 3.0, true)
	for i in 6:
		var dir := button_dir(i)
		var p := c + dir * RING
		var lit := _flash[i] > 0.0
		draw_circle(p, BUTTON, Color(1, 0.85, 0.5, 0.55) if lit else Color(1, 1, 1, 0.12))
		draw_arc(p, BUTTON, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 2.0, true)
		# 대가 달린 화살표. 삼각형만 그리면 작은 화면에서 대각선 버튼이 안쪽을 가리키는 것처럼 읽힌다.
		var side := Vector2(-dir.y, dir.x)
		draw_line(p - dir * 20.0, p + dir * 4.0, Color(1, 1, 1, 0.9), 7.0, true)
		draw_colored_polygon(PackedVector2Array([p + dir * 24.0, p + dir * 2.0 + side * 13.0, p + dir * 2.0 - side * 13.0]), Color(1, 1, 1, 0.9))
```

- [ ] **Step 6: 구현 — `scripts/hud.gd`**

```gdscript
class_name Hud
extends CanvasLayer

# 위쪽: 점수, 빌드 버전과 fps, 맵 회전 버튼 2개. 죽은 뒤에는 다시 시작 안내.

signal turn_pressed(dir: int)

var score_label := Label.new()
var info_label := Label.new()
var restart_label := Label.new()
var _version := str(ProjectSettings.get_setting("application/config/version", "dev"))

func _ready() -> void:
	score_label.position = Vector2(24, 16)
	score_label.add_theme_font_size_override("font_size", 48)
	add_child(score_label)
	info_label.position = Vector2(24, 80)
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.modulate = Color(1, 1, 1, 0.6)
	add_child(info_label)
	restart_label.text = "탭하면 다시 시작"
	restart_label.add_theme_font_size_override("font_size", 40)
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	restart_label.offset_top = 130
	restart_label.visible = false
	add_child(restart_label)
	for d in [-1, 1]:
		var b := TurnButton.new(d)
		b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		b.position = Vector2(-120 if d == 1 else -232, 16)
		b.pressed_dir.connect(turn_pressed.emit)
		add_child(b)

func set_score(v: int) -> void:
	score_label.text = str(v)

func show_restart(on: bool) -> void:
	restart_label.visible = on

func _process(_delta: float) -> void:
	info_label.text = "%s  %d fps" % [_version, Engine.get_frames_per_second()]

# 맵 회전 버튼. ⟲⟳ 같은 기호는 한글 폰트에 없어 네모로 나오므로 직접 그린다.
class TurnButton extends Control:
	signal pressed_dir(dir: int)
	var dir := 1

	func _init(d: int) -> void:
		dir = d
		size = Vector2(104, 104)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var t := event as InputEventScreenTouch
		if t != null and t.pressed:
			pressed_dir.emit(dir)
			accept_event()

	# 240° 호 + 화살촉. dir = 1 이면 시계 방향, -1 이면 좌우를 뒤집어 반시계.
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 46.0, Color(1, 1, 1, 0.12))
		var flip := Vector2(dir, 1)
		var arc := PackedVector2Array()
		for k in 25:
			var a := deg_to_rad(-210.0 + 240.0 * k / 24.0)
			arc.append(c + Vector2(cos(a), sin(a)) * 24.0 * flip)
		draw_polyline(arc, Color.WHITE, 5.0, true)
		var a1 := deg_to_rad(30.0)
		var tip := Vector2(cos(a1), sin(a1)) * 24.0
		var tan := Vector2(-sin(a1), cos(a1))
		var out := Vector2(cos(a1), sin(a1))
		draw_colored_polygon(PackedVector2Array([
			c + (tip + tan * 12.0) * flip,
			c + (tip - tan * 4.0 + out * 10.0) * flip,
			c + (tip - tan * 4.0 - out * 10.0) * flip,
		]), Color.WHITE)
```

- [ ] **Step 7: 구현 — `scripts/main.gd`, `scenes/main.tscn`**

`scripts/main.gd`:

```gdscript
extends Node3D

# 게임 화면: 게임 진행, 입력 연결, 죽은 뒤 다시 시작.
# 타이틀·일시정지·게임오버 화면은 6단계에서 붙인다.

var game: Game
var rig := CameraRig.new()
var field_view := FieldView.new()
var worm_view := WormView.new()
var hud := Hud.new()
var controller := Controller.new()
var _dead_time := 0.0

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.07, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.9)
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 20.0, 0.0)
	sun.light_energy = 0.9
	add_child(sun)
	rig.position = Vector3.ONE * Tuning.BOX * 0.5
	add_child(rig)
	add_child(field_view)
	add_child(worm_view)
	add_child(hud)
	controller.rig = rig
	hud.add_child(controller)
	controller.direction_pressed.connect(_on_direction)
	controller.turn_pressed.connect(_on_turn)
	hud.turn_pressed.connect(_on_turn)
	new_game()

func new_game() -> void:
	game = Game.new(randi(), perf_requested())
	field_view.setup(game)
	worm_view.setup(game)
	_dead_time = 0.0
	hud.show_restart(false)

# 웹은 주소 끝 ?perf, 데스크톱은 실행 인자 --perf 면 500마디로 시작한다(성능 확인용).
static func perf_requested() -> bool:
	if OS.get_cmdline_user_args().has("--perf"):
		return true
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.location.search", true)).contains("perf")
	return false

func _process(delta: float) -> void:
	game.paused = rig.is_turning()
	game.advance(delta)
	hud.set_score(game.score)
	if game.state == Game.State.DEAD:
		_dead_time += delta
		hud.show_restart(_dead_time >= Tuning.DEATH_DELAY)

func _on_direction(screen_dir: int) -> void:
	if game.state == Game.State.DEAD:
		_restart_if_ready()
		return
	game.press(rig.world_dir(screen_dir))

func _on_turn(dir: int) -> void:
	if game.state != Game.State.DEAD:
		rig.turn(dir)

func _unhandled_input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t != null and t.pressed and game.state == Game.State.DEAD:
		_restart_if_ready()

func _restart_if_ready() -> void:
	if _dead_time >= Tuning.DEATH_DELAY:
		new_game()
```

`scenes/main.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 8: 한글 폰트**

```bash
cp ~/games/bus-driver/assets/fonts/NotoSansKR-hangul.ttf ~/games/bus-driver/assets/fonts/OFL.txt assets/fonts/
```

`project.godot` 끝에 덧붙인다:

```ini

[gui]

; 웹에는 시스템 폰트가 없고 Godot 내장 폰트에는 한글이 없다. 지정하지 않으면 폰에서 한글이 네모로 나온다.
theme/custom_font="res://assets/fonts/NotoSansKR-hangul.ttf"
```

- [ ] **Step 9: 통과 확인**

Run: `./run_tests.sh`
Expected: 10개 파일 전부 `: OK`, 마지막 줄 `전체 통과`.

- [ ] **Step 10: 커밋**

```bash
git status --short
git add project.godot scenes/main.tscn scripts/controller.gd scripts/controller.gd.uid scripts/hud.gd scripts/hud.gd.uid scripts/main.gd scripts/main.gd.uid assets/fonts/NotoSansKR-hangul.ttf assets/fonts/NotoSansKR-hangul.ttf.import assets/fonts/OFL.txt tests/test_controller.gd tests/test_controller.gd.uid tests/test_main_smoke.gd tests/test_main_smoke.gd.uid tests/test_font.gd tests/test_font.gd.uid
git commit -m "feat: 6방향 컨트롤러, HUD, 게임 화면 조립, 한글 폰트"
```

- [ ] **Step 11: 데스크톱 플레이 확인 — 사용자 판단 (여기서 멈춘다)**

창을 띄우는 Godot 은 에이전트 샌드박스 안에서 바로 꺼지므로(함정 7) 사용자에게 직접 실행해 달라고 한다:

```bash
godot --path ~/games/cube-worm              # 보통 판
godot --path ~/games/cube-worm -- --perf    # 500마디 성능 확인(왼쪽 위 fps)
```

조작: `Q W E / A S D` 가 육각 6방향(`W` ▲ 위, `S` ▼ 아래, `Q` ↖, `E` ↗, `A` ↙, `D` ↘), `←` `→` 맵 회전. 화면 아래 컨트롤러를 마우스로 눌러도 된다. 죽으면 1초 뒤 아무 데나 클릭하거나 방향 버튼을 누르면 다시 시작한다.

사용자에게 물을 것(spec 10절 3단계): ① 3D 가 읽히는가(머리 층 판, 벌레 고리·기둥, 높이 색, 비침) ② 재밌는가 ③ 상자 크기 8 과 속도 3 → 6 이 맞는가.

- 조정값만 바꾸면 되는 피드백이면 `scripts/tuning.gd` 만 고치고 `./run_tests.sh` 로 확인한 뒤 커밋한다(`chore: 조정값 — <무엇>`). 테스트는 조정값을 읽으므로 따라온다.
- 설계를 바꾸는 피드백이면 구현을 멈추고 사용자와 spec 부터 다시 본다.

- [ ] **Step 12: 3단계 병합 (사용자가 좋다고 한 뒤)**

```bash
./run_tests.sh
git checkout main && git merge --ff-only stage3-first-play && git branch -d stage3-first-play
```

---

## 4단계: 폰

### Task 8: 웹 배포와 폰 확인

**Files:**
- Create: `export_presets.cfg`, `.github/workflows/deploy.yml`(blockbox 워크플로에서 이름만 바꿈)

**Interfaces:**
- Consumes: `project.godot` 의 `application/config/version`(워크플로가 덮어쓰고 `Hud` 가 왼쪽 위에 보여준다), `main.perf_requested()`(주소 끝 `?perf`)
- Produces: `https://kjw5541a-hash.github.io/cube-worm/` — 어느 브랜치를 push 해도 그 빌드로 덮어쓴다(blockbox 와 같은 방식)

- [ ] **Step 1: 브랜치**

```bash
git checkout -b stage4-phone
```

- [ ] **Step 2: `export_presets.cfg`**

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include="<meta name=\"mobile-web-app-capable\" content=\"yes\"><meta name=\"apple-mobile-web-app-capable\" content=\"yes\"><meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black-translucent\">"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
```

`thread_support=false` 는 꼭 지킨다. 스레드를 켜면 SharedArrayBuffer 용 응답 헤더가 필요한데 GitHub Pages 는 헤더를 못 바꿔 흰 화면만 뜬다.

- [ ] **Step 3: 로컬 웹 내보내기 확인**

웹 템플릿은 이 맥에 이미 있다(`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`).

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
test -s build/web/index.pck && test -s build/web/index.wasm && echo EXPORT_OK
```

Expected: `EXPORT_OK`. (`build/` 는 `.gitignore` 에 있어 커밋되지 않는다.)

- [ ] **Step 4: 배포 워크플로 — blockbox 것에서 이름만 바꾼다**

```bash
mkdir -p .github/workflows
sed -e 's/BASENAME=blockbox-/BASENAME=cube-worm-/' \
    -e 's/content="blockbox"/content="큐브 지렁이"/' \
    -e 's|<title>blockbox</title>|<title>큐브 지렁이</title>|' \
    -e 's/background: #0d0f17;/background: #1c120d;/' \
    -e 's/f.src = v.trim() + ".html";/f.src = v.trim() + ".html" + location.search;/' \
    ~/games/blockbox/.github/workflows/deploy.yml > .github/workflows/deploy.yml
grep -c "blockbox" .github/workflows/deploy.yml
grep -n "BASENAME=cube-worm-\|큐브 지렁이\|#1c120d\|location.search" .github/workflows/deploy.yml
```

Expected: 첫 grep 은 `0`. 둘째 grep 은 5줄(73 BASENAME, 113 앱 제목 meta, 116 title, 122 배경색, 133 `location.search`).

마지막 치환이 빠지면 `?perf` 가 안 먹는다. 배포된 게임은 바깥 `index.html` 안의 iframe 에서 돌기 때문에, 바깥 주소의 `?perf` 를 iframe 주소로 넘겨줘야 게임이 읽을 수 있다.

이 워크플로가 하는 일: 어느 브랜치든 push 하면 테스트(`./run_tests.sh`) → `config/version` 에 날짜·브랜치·커밋을 박음 → 웹 내보내기 → Pages 배포. 바깥 `index.html` 은 `version.txt` 를 읽어 그 빌드를 iframe 으로 띄워서, 폰의 "홈 화면에 추가" 아이콘이 다음 배포에도 살아 있다.

- [ ] **Step 5: 커밋**

```bash
git add export_presets.cfg .github/workflows/deploy.yml
git commit -m "chore: 웹 내보내기 설정과 Pages 배포 워크플로"
```

- [ ] **Step 6: 사용자에게 묻기 — 여기서 멈춘다 (밖으로 나가는 동작)**

물을 것: "GitHub 에 `kjw5541a-hash/cube-worm` 저장소를 만들고 올려서 Pages 로 배포해도 될까? 무료 계정에서는 Pages 가 공개 저장소에서만 되니 공개로 만든다(blockbox, 3D블럭파괴와 같은 방식)." 승인을 받기 전에는 Step 7 을 하지 않는다. 사용자가 비공개를 원하면 Pages 가 안 되니(유료 플랜 제외) 다른 배포 방법을 사용자와 정한다.

- [ ] **Step 7: (승인 뒤) 저장소 만들기, Pages 켜기, push**

순서가 중요하다. 워크플로가 들어 있는 `stage4-phone` 을 Pages 설정보다 먼저 올리면 첫 배포가 실패한다.

```bash
gh repo create kjw5541a-hash/cube-worm --public --source . --remote origin
git push -u origin main
gh api -X POST repos/kjw5541a-hash/cube-worm/pages -f build_type=workflow
# 어느 브랜치에서든 Pages 에 배포할 수 있게 한다(blockbox 와 같은 설정: '*' 와 main).
gh api -X PUT repos/kjw5541a-hash/cube-worm/environments/github-pages \
  -F 'deployment_branch_policy[protected_branches]=false' \
  -F 'deployment_branch_policy[custom_branch_policies]=true'
gh api -X POST repos/kjw5541a-hash/cube-worm/environments/github-pages/deployment-branch-policies -f name='*' -f type=branch
gh api -X POST repos/kjw5541a-hash/cube-worm/environments/github-pages/deployment-branch-policies -f name=main -f type=branch
gh api repos/kjw5541a-hash/cube-worm/environments/github-pages/deployment-branch-policies --jq '[.branch_policies[].name]'
git push -u origin stage4-phone
```

Expected: 마지막 `gh api` 출력에 `"*"` 와 `"main"` 이 있다. (`main` 정책이 이미 있다는 422 응답이 나오면 무시해도 된다.)

- [ ] **Step 8: 배포 확인**

```bash
gh run watch "$(gh run list --branch stage4-phone --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
curl -s https://kjw5541a-hash.github.io/cube-worm/version.txt
```

Expected: 실행이 성공으로 끝나고, `version.txt` 가 `cube-worm-<날짜>-stage4-phone-<커밋 7자리>` 다. 실패하면 `gh run view --log-failed` 에서 가장 짧은 결정적 줄을 보고 고친다.

- [ ] **Step 9: 폰 확인 — 사용자 판단 (여기서 멈춘다)**

사용자에게 폰으로 `https://kjw5541a-hash.github.io/cube-worm/` 을 열어 확인해 달라고 한다.

1. 왼쪽 위 버전 문구에 `stage4-phone` 과 커밋이 보이는가(새 빌드인지 구별).
2. 터치 컨트롤러 6방향이 화면에서 보이는 방향대로 가는가. 맵을 돌린 뒤에도 그런가.
3. 비침: 바위나 몸 뒤에 숨은 머리·벌레가 비쳐 보이는가(사파리에서 특히).
4. 한글이 네모로 나오지 않는가.
5. 주소 끝에 `?perf` 를 붙여 열면(`https://kjw5541a-hash.github.io/cube-worm/?perf`) 왼쪽 위 fps 가 60 근처인가.

알려진 한계(6단계에서 처리): "홈 화면에 추가"로 전체 화면 실행하면 위쪽 HUD 가 상태 표시줄과 겹칠 수 있다. 타이틀·일시정지·게임오버 화면은 아직 없다.

- [ ] **Step 10: 4단계 병합과 정리 (사용자가 좋다고 한 뒤)**

```bash
./run_tests.sh
git checkout main && git merge --ff-only stage4-phone && git push origin main
git branch -d stage4-phone && git push origin --delete stage4-phone
```

main 을 push 하면 Pages 가 main 빌드로 다시 배포된다.

---

## 끝난 뒤

- 사용자에게 보고한다: 배포 주소, 폰 확인 결과, 조정한 값.
- 5단계(Blender 에셋, 공용 셰이더 마무리, 먹기·죽음 연출)와 6단계(타이틀, 게임오버, 최고 기록, 일시정지, 노치 처리)는 3·4단계 플레이 판단을 반영해 별도 계획으로 쓴다.
