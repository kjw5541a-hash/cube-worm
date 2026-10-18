# 큐브 지렁이 — 콤보 배율과 황금 벌레 설계

2026-10-18. 재미 강화 기획의 A안이다. 기존 방식(레벨 진행, 점수)의 점수에 선택을 넣는다.
`2026-10-16-cube-worm-modes-design.md` 3절의 "규칙은 하나도 바꾸지 않는다"는 점수 규칙에 한해 이 문서가 대신한다. 둘이 어긋나면 이 문서가 맞다.

## 목표

- 지금은 한 레벨의 점수가 늘 같다(그 판 벌레 점수의 합). 어떤 벌레를 언제 먹느냐가 점수를 바꾸게 한다.
- **콤보:** 빨리 이어 먹으면 배율이 오른다. 먹는 순서와 빠르기가 점수가 된다.
- **황금 벌레:** 콤보를 이은 보상으로 잠깐 나타나는 큰 점수. 쫓을지 말지가 선택이 된다.
- 살아남기 난이도는 올리지 않는다. 콤보를 무시하고 안전하게 해도 지금처럼 깰 수 있다.
- 규칙은 `Game` 안에 둔다. 화면·소리는 `Game` 상태를 읽기만 한다. `Game` 은 지금처럼 방식을 모른다.

사용자가 정한 것: A안(콤보 배율 + 잠깐 나타나는 황금 벌레, 기존 방식만), 콤보는 시간 기준(3초 안에 다음 벌레, ×5 상한,
맵 회전 중 멈춤, 점수 옆 줄어드는 막대, 소리의 연속 음 상승을 같은 콤보로 합침), 황금 벌레는 콤보 ×3 보상,
모양은 크림 굼벵이 모양 + 금색. 나머지는 채팅에서 세 절(규칙 / 화면·소리 / 기록·테스트·확인)로 보여 주고 승인받았다.

## 1. 콤보

- `Game.combo`: 지금 이어지는 연속 먹기 수(0 = 없음, 최대 `COMBO_MAX`). 연속 n 번째로 먹은 벌레의 점수 배율이 n 이다.
- `Game.combo_left`: 콤보를 이을 수 있는 남은 시간(초).
- 벌레를 먹는 걸음에서: `combo_left > 0` 이면 `combo = mini(combo + 1, COMBO_MAX)`, 아니면 `combo = 1`. 그다음 `combo_left = COMBO_WINDOW`.
  얻는 점수는 `기본 점수 × combo` 다(일반 벌레의 기본 점수는 지금의 `BUG_SCORES`).
- `advance` 에서 상태가 `RUNNING` 이고 `paused` 가 아닐 때만 `combo_left` 가 `delta` 만큼 준다(`elapsed` 와 같은 규칙).
  0 이 되면 `combo = 0` 이다. 줄이기는 그 프레임의 이동보다 먼저 한다.
  그래서 출발 전 대기, 맵 회전 중, 시작·메뉴 화면(`advance` 를 부르지 않는다), 죽은 뒤, 클리어 뒤에는 멈춘다.
- 새 판(죽은 뒤 다시, 다음 레벨)은 `Game` 을 새로 만드므로 콤보는 0 부터다. 레벨을 넘어 이어지지 않는다.
- 예: 크림(1)·더듬이(2)·반딧불(3)을 차례로 이어 먹으면 1×1 + 2×2 + 3×3 = 14점, 거꾸로 먹으면 3×1 + 2×2 + 1×3 = 10점이다.
  지금 규칙으로는 어느 순서든 6점이다.
- 성장·속도 규칙은 그대로다(벌레마다 한 마디, `SPEED_STEP`).
- 타임어택에서도 콤보는 계산된다. 점수를 보이지 않으므로 화면 밖으로 드러나는 것은 먹는 소리의 음높이뿐이다.

## 2. 황금 벌레

- `Game.golden`(기본 `false`): 황금 벌레를 쓰는 판인가. `Main` 이 기존 방식 판에서만 켠다.
- 상태: `Game.gold_cell`(칸)과 `Game.gold_left`(사라지기까지 남은 시간, 초. 0 = 없음). 황금 벌레는 `Field.bugs` 에 넣지 않는다.
- **나타남:** 벌레를 먹은 걸음의 끝(몸이 움직인 뒤)에, 클리어가 아니고, `golden` 이 켜져 있고, `combo == GOLD_AT` 이고,
  `gold_left == 0` 이면 나타난다.
  - 칸은 `field.empty_cells(worm.cell_set())`(바위·벌레·지렁이 몸이 없는 칸) 중 하나를 판의 난수 `field.rng` 로 고른다.
    시드가 같으면 같은 칸이 나온다. 빈 칸이 없으면 나오지 않는다.
  - `gold_left = GOLD_TIME` 으로 두고 신호 `gold_appeared(cell)` 을 낸다. 같은 걸음의 `ate` 신호 다음이다.
  - 연속 수는 한 콤보에서 `GOLD_AT` 을 한 번만 지나므로 콤보 하나에 한 마리다.
    앞의 황금 벌레가 아직 남아 있을 때 새 콤보가 다시 `GOLD_AT` 이 되면 새로 나오지 않는다.
- **사라짐:** `gold_left` 는 `combo_left` 와 같은 규칙으로 준다. 0 이 되면 없다. 클리어하면 바로 0 이 된다.
- **먹기:** 머리가 `gold_left > 0` 인 `gold_cell` 로 들어가는 걸음이다. 일반 벌레와 같이 콤보 규칙(1절)을 따르고,
  한 마디 자라고, `SPEED_STEP` 만큼 빨라지고, 먹은 덩어리 연출(`eat_steps`)과 `eaten_cell`·`eaten_kind` 를 남긴다.
  - 점수는 `GOLD_SCORE × combo` 다. 먹으면 `gold_left = 0`.
  - 신호는 기존 `ate(kind, points, cell)` 를 `kind = Game.GOLD` 로 낸다. `Game.GOLD` = `Tuning.BUG_COUNT`(지금 3), 일반 종류 번호 다음이다.
  - 나타난 뒤 3초 안에 먹으면 연속 4번째라 ×4 = 20점, 콤보가 끊긴 뒤 먹으면 ×1 = 5점이다.
- **클리어:** 지금처럼 `field.bugs` 가 비면(일반 벌레를 다 먹으면) 클리어다. 황금 벌레는 세지 않는다.
  연속 수가 `GOLD_AT` 이 된 벌레가 마지막 일반 벌레면 클리어라서 나오지 않는다.
  그래서 벌레가 세 마리인 레벨 1~3 에는 나오지 않는다(레벨 4~6 은 6마리, 7~8 은 9마리).
- **죽음:** `DEAD` 에서는 타이머가 멈추고 황금 벌레는 그 자리에 남아 보인다. 다시 시작하면 새 `Game` 이라 없다.
- 일반 벌레와 황금 벌레는 한 칸에 겹치지 않는다(황금 벌레는 빈 칸에만 나오고, 일반 벌레는 판을 만들 때만 놓인다).

## 3. 화면

### 모델

- `assets/blender/bugs.py` 의 `KINDS` 에 `"gold"` 를 더한다. 크림과 같은 크기 목록·호 각도·호 반지름, 더듬이 없음,
  몸 `#FFC21A`·머리 `#FFE680`(시작값, 폰에서 조정). `build_all.py` 는 `KINDS` 를 돌므로 `assets/models/grub_gold.glb` 가 나온다.
  삼각형 수는 크림과 같아 상한 2000 안이다.
- `Skins.GOLD = {"id": "gold", "name": "황금", "model": DIR + "grub_gold.glb", "color": Color("#FFE14A")}`.
  `color` 는 고리·기둥·층 눈금 점·`+N`·`황금!` 글자의 색이다. `Skins.BUGS` 는 그대로 3종이다.

### 판 (`FieldView`)

- 황금 벌레 노드 하나(가려지면 비치는 재질, 일반 벌레와 같다), 금색 고리·기둥 한 벌, 먹힐 때 머리로 빨려 드는 유령 하나(`ghosts[Game.GOLD]`).
- 보임: `gold_left > 0`. 마지막 `GOLD_BLINK` 초 동안은 `gold_left` 가 0.1초 줄 때마다 숨었다 보였다 한다. 깜빡임은 `gold_left` 로 정하므로 게임 상태만으로 결정된다
  (맵 회전 중이나 죽은 뒤에는 그 순간의 모습으로 멈춘다).
  고리·기둥도 같이 깜빡인다.
- 위치는 칸 중심에 일반 벌레와 같은 꼼지락 높이를 더한 곳, 크기는 `GOLD_SCALE` 배. 제자리에서 `GOLD_SPIN` 라디안/초로 돈다.
- 발광은 일반 벌레(0.5 ± 0.2, 느리게)보다 세고 빠르게 한다: 0.9 ± 0.4, 초당 약 0.8번(시작값).
- 유령은 `GOLD_SCALE` 배 크기에서 작아진다.
- 고리·기둥 배치는 벌레·바위와 같은 규칙이다(머리 층 높이의 고리, 높이 차가 있으면 기둥). 벌레·바위·황금 벌레 세 곳이 같은 작은 도우미 함수를 쓰게 묶는다.

### 층 눈금 (`FloorGauge`)

- `update_from` 에서 `gold_layer` 를 읽는다(황금 벌레가 없으면 -1). 그 층 칸의 맨 앞, 일반 벌레 점보다 앞에 반지름 `DOT × 1.4` 의 금색 점을 그린다.

### HUD

- **콤보 줄:** 점수 아래, 타임어택의 `남은 벌레` 와 같은 자리(y 112)에 금색 `×N` 글자(28px, 왼쪽 끝 x 24)와
  그 오른쪽의 막대(왼쪽 끝 x 80, 꽉 차면 폭 120px, 높이 12px, 글자와 세로 가운데 맞춤).
- `Hud.set_combo(mult, frac)`: `frac > 0` 이면 보이고 글자는 `×mult`, 막대 폭은 `120 × frac`. `frac <= 0` 이면 숨긴다.
  `set_mode` 는 두 방식 모두 이 줄을 숨긴 채로 시작한다.
- `Main` 은 기존 방식에서 매 프레임 `set_combo(mini(game.combo + 1, COMBO_MAX), game.combo_left / COMBO_WINDOW)` 를 부른다.
  상태가 `RUNNING` 이 아니면 `frac` 은 0 이다(죽은 뒤·클리어 뒤에는 숨긴다).
  - 그래서 N 은 **다음 벌레에 붙을 배율**이다. 첫 벌레를 먹으면 `×2` 와 꽉 찬 막대가 뜨고, 막대가 다 줄기 전에 먹으면 ×2 다. 상한에서는 `×5` 그대로다.
- 레이아웃: 빌드 문구 아래, 메뉴 버튼 위에 들어가야 한다(기존 `_test_header_layout` 과 같은 방식으로 잰다).
  28px 가 넘친다고 나오면 `남은 벌레` 와 같은 24px 로 줄인다.
- `+N` 은 지금처럼 먹은 칸 위에 뜨고, N 은 배율을 곱한 점수다. 황금 벌레를 먹으면 `Skins.GOLD` 색이다.
- `황금!`: 나타날 때 그 칸의 화면 위치(`+N` 과 같은 계산)에 `Skins.GOLD` 색으로 `Hud.pop` 한다.
- `×` 글자는 프로젝트 폰트에 있다(2026-10-18 헤드리스로 확인). `test_font` 가 계속 지킨다.

## 4. 소리

- `Sfx` 의 실제 시간 콤보(`COMBO_WINDOW` 2초, `_combo`, `_last_eat`, `COMBO_MAX`)를 지운다.
- `play_eat(kind, combo)`: 받은 연속 수로 음높이를 정한다. `combo_pitch(combo)` = 원래 음보다 온음 `clampi(combo, 1, Tuning.COMBO_MAX) - 1` 개 위.
  연속 1번째는 원래 음, 5번째부터는 온음 4개 위(지금 최대와 같다)에서 멈춘다. 그래서 화면의 배율과 음이 같이 올라간다.
- 소리 이름은 `"eat_%d" % kind` 그대로다. 황금 벌레(`Game.GOLD` = 3)는 `eat_3` 이 된다.
- 새 소리 둘을 `tools/audio/synth.py` 의 `SOUNDS` 끝에 더한다.
  - `eat_3`: 황금 벌레를 먹는 소리. 반짝이는 높은 두 음.
  - `gold`: 나타나는 소리. 빠르게 올라가는 세 음.
  - `synth.py` 는 이름을 주면 그 소리만 쓰게 한다(`python3 tools/audio/synth.py eat_3 gold`). 기존 `.ogg` 는 다시 쓰지 않는다.
  - `.import` 파일은 Godot 헤드리스 임포트로 만들어 `.ogg` 와 같이 커밋한다.
- `Sfx.NAMES` 에 `eat_3`, `gold` 를 더한다. `gold_appeared` 가 오면 `Main` 이 `sfx.play("gold")` 를 부른다.

## 5. 방식과 기록

- 기존 방식: `Main.new_game` 이 `game.golden = mode == Title.Mode.CLASSIC` 으로 둔다. `?level`, `?perf` 로 시작한 판도 켜진다(기록만 쓰지 않는다).
- 타임어택: 꺼진다. 판 생성·속도 규칙이 그대로라 `TIME_LAYOUT_VERSION` 은 2 그대로이고, 지금 시간 기록과 계속 비교한다.
- 최고 점수: `best_score` 키 그대로다. `SaveData` 와 저장 형식은 바뀌지 않는다.
  옛 최고는 콤보 없이 낸 점수라 첫 판에서 깨지기 쉽다. 깨지면 지금 규칙대로 `신기록!` 이 한 번 뜬다.

## 6. 구조

| 파일 | 변경 |
|---|---|
| `scripts/tuning.gd` | `COMBO_WINDOW` 3.0, `COMBO_MAX` 5, `GOLD_AT` 3, `GOLD_TIME` 5.0, `GOLD_SCORE` 5, 연출 `GOLD_SCALE` 1.3, `GOLD_SPIN` 3.0, `GOLD_BLINK` 1.5 |
| `scripts/game.gd` | `GOLD`, 신호 `gold_appeared(cell)`, `golden`, `combo`, `combo_left`, `gold_cell`, `gold_left`. `advance` 의 두 타이머, `_step` 의 콤보·황금 벌레 먹기·나타남 |
| `scripts/audio.gd` | 실제 시간 콤보 삭제, `play_eat(kind, combo)`, `combo_pitch(combo)`, `NAMES` 에 `eat_3`·`gold` |
| `tools/audio/synth.py` | `eat_3`, `gold`, 이름을 주면 그 소리만 쓰기 |
| `assets/audio/eat_3.ogg`, `gold.ogg` (+ `.import`) | 새 파일 |
| `assets/blender/bugs.py` | `KINDS["gold"]` |
| `assets/models/grub_gold.glb` (+ `.import`) | 새 파일 |
| `scripts/skins.gd` | `GOLD` |
| `scripts/field_view.gd` | 황금 벌레 노드·고리·기둥·유령, 깜빡임·회전·발광, 고리·기둥 도우미 |
| `scripts/floor_gauge.gd` | `gold_layer`, 금색 점 |
| `scripts/hud.gd` | `×N` 글자와 막대, `set_combo(mult, frac)` |
| `scripts/main.gd` | `game.golden`, `gold_appeared` 연결(소리·`황금!`), `_on_ate` 의 `play_eat(kind, game.combo)` 와 황금 색, 매 프레임 `set_combo` |

흐름: `Game._step` 에서 먹기 → `ate` → `Main._on_ate`(음높이 = `game.combo`, `+N`, 최고 점수).
연속 수가 `GOLD_AT` → `gold_appeared` → `Main`(소리 `gold`, `황금!`). `Main._process` → `Hud.set_combo`.
`FieldView`·`FloorGauge` 는 `game.gold_cell`·`game.gold_left` 를 읽어 그린다.

## 7. 테스트

기능마다 실패하는 테스트를 먼저 보고 통과시킨다.

- `tests/test_game.gd`(확장)
  - 콤보: 3초 안에 이어 먹으면 연속 수가 오르고 점수에 배율이 붙는다. 3초가 지나면 0, 그다음 벌레는 1부터. `paused` 동안 멈춘다. `COMBO_MAX` 에서 멈춘다.
  - 황금 벌레: `golden` 이 꺼져 있으면 안 나온다. 켜져 있으면 연속 3에서 한 번 나온다(빈 칸, 신호 한 번, 같은 시드면 같은 칸).
    `GOLD_TIME` 뒤 사라진다. 먹으면 `ate(GOLD, GOLD_SCORE × combo, cell)`, 자라고 빨라지고 콤보가 이어진다.
    클리어 조건에 세지 않는다. 클리어하면 사라진다. 마지막 일반 벌레로 연속 3이 되면 나오지 않는다.
  - 기존 점수 테스트(`_test_eating`, `_test_scores_by_kind`, `_test_ate_signal`)는 판마다 벌레를 한 마리만 먹어 배율이 ×1 이라 그대로 통과한다.
- `tests/test_audio.gd`(수정): 음높이가 넘겨받은 연속 수를 따르고 상한에서 멈춘다. 실제 시간 콤보 검사는 지운다. 새 소리 둘이 읽힌다.
- `tests/test_models.gd`(확장): `grub_gold` 가 다른 굼벵이와 같은 계약(삼각형 상한, 크기, 칸 중심 원점, 색)을 지킨다.
- `tests/test_skins.gd`(확장): `Skins.GOLD` 의 에셋이 있고, 색이 일반 벌레 셋과 다르다.
- `tests/test_field_view.gd`(확장): 황금 벌레의 위치·크기·고리, 없으면 숨김, 마지막 `GOLD_BLINK` 초의 깜빡임, 먹힐 때 유령.
- `tests/test_floor_gauge.gd`(확장): 황금 벌레가 있으면 그 층, 없으면 -1.
- `tests/test_hud.gd`(확장): `×N` 글자와 막대 폭, `frac` 0 이면 숨김, `set_mode` 뒤 숨김, 빌드 문구와 메뉴 버튼 사이에 들어감.
- `tests/test_modes_flow.gd`(확장): 기존 방식 판은 `golden` 켜짐, 타임어택은 꺼짐. 먹을 때 소리 음높이가 `game.combo` 를 따른다.
  `gold_appeared` 가 오면 `황금!` 이 뜨고 `gold` 소리가 난다. 타임어택에서는 콤보 줄이 안 보인다.

## 8. 만드는 순서

작업이 하나 끝날 때마다 전체 테스트가 통과해야 한다.

1. `Tuning` 조정값과 `Game` 규칙.
2. `Sfx` 콤보 합치기와 새 소리 합성(`.ogg` + `.import`). `Main` 의 `play_eat` 호출 한 줄도 같이 고친다.
3. 황금 벌레 모델(Blender 헤드리스 빌드)과 `Skins.GOLD`.
4. `FieldView` 와 층 눈금 표시.
5. `Hud` 콤보 줄.
6. `Main` 연결과 흐름 테스트.
7. 브랜치 푸시(Pages 배포) → 웹 확인 → 폰 확인.

브랜치는 `combo-gold`(time-attack-random 의 2522fa7 위)다. 배포할 때 time-attack-random 의 아직 안 올린 커밋(2522fa7, 문서만)을 먼저 푸시하고 그다음 `combo-gold` 를 푸시한다.
배포 워크플로는 `concurrency: pages`, `cancel-in-progress: false` 라 차례로 돌고, 나중에 푸시한 `combo-gold` 가 라이브가 된다.

## 9. 확인할 것

- **웹 확인(자동 조작):** 기존 방식에서 벌레를 먹으면 콤보 줄이 뜨고 줄어드는지, 타임어택에서는 안 보이는지.
  실제 판에서 연속 3을 만들어 황금 벌레를 부르는 일은 자동 조작으로 어렵다. 나오는 규칙은 흐름 테스트로 확인한다.
- **황금 벌레 모습:** 저장소 밖의 일회용 스크립트로 데스크톱 창에 판을 띄우고 황금 벌레를 억지로 놓아 스크린샷을 찍는다
  (그동안 Mac 화면에 Godot 창이 잠깐 뜬다). 더듬이 벌레와 구분되는지 먼저 보고, 헷갈리면 색·크기·발광을 고친 뒤 넘긴다.
- **폰 확인(사용자), 플레이로 판단할 것:**
  - 콤보 시간 3초와 상한 ×5 가 적당한지.
  - 황금 벌레가 레벨 4부터 나오는 게 괜찮은지(`GOLD_AT` 을 2 로 내리면 레벨 1부터 나온다). 머무는 5초와 기본 5점이 적당한지.
  - 황금 벌레가 눈에 잘 띄는지, 더듬이 벌레와 헷갈리지 않는지.
  - 콤보 줄은 점수 아래라 지렁이를 보는 시선에서 멀다. 잘 안 보이면 머리 근처로 옮긴다.
  - 새 소리 두 개의 크기.

## 범위 밖

타임어택의 콤보 보상, 황금 벌레 말고 다른 특수 벌레, 콤보가 끊길 때 소리, 순위표.
