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

const LEVEL_MAX := 8                       # 레벨 N 의 맵 높이는 N 칸. 8 레벨이 정육면체(BOX 칸)다
const CLEAR_DELAY := 0.8                    # 클리어 뒤 다음 레벨 입력을 받기까지(초)
# 타임어택: 레벨 TIME_LEVEL 한 판. 시도마다 바위·벌레를 새로 무작위로 놓는다.
const TIME_LEVEL := 8
# 판 생성 규칙(Field·Game 의 배치 코드)을 일부러 바꾸면 올린다. 시간 기록은 이 값이 같은 판끼리만 비교한다.
# 2: 고정 시드 한 배치 → 시도마다 무작위 배치. 고정 배치에서 낸 옛 기록은 숨겨진다.
const TIME_LAYOUT_VERSION := 2
const BUG_COUNT := 3                        # 벌레 종류 수. 종류마다 한 마리씩 항상 있다(= BUG_SCORES.size())
const BUG_SCORES: Array[int] = [1, 2, 3]    # 종류별 점수: 크림·더듬이·반딧불. 성장과 속도 상승은 종류와 무관하다
const ROCK_COUNT := 8
const ROCK_CLEAR_RADIUS := 2                # 시작 지렁이 칸에서 이 체비쇼프 거리 안에는 바위 없음
const QUEUE_MAX := 2

# 콤보와 황금 벌레(기존 방식의 점수). 둘 다 실행 중(맵 회전 중 제외)에만 시간이 흐른다.
const COMBO_WINDOW := 3.0                   # 벌레를 먹고 이 시간(초) 안에 다음 벌레를 먹으면 연속
const COMBO_MAX := 5                        # 연속 수(= 점수 배율)의 상한
const GOLD_AT := 3                          # 연속 수가 이 값이 되는 순간 황금 벌레가 나온다
const GOLD_TIME := 5.0                      # 황금 벌레가 머무는 시간(초)
const GOLD_SCORE := 5                       # 황금 벌레의 기본 점수(연속 수를 곱한다)

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

# 연출(5단계)
const BULGE_PEAK := 0.25                    # 먹은 덩어리가 몸을 따라 흐를 때 마디가 부푸는 비율(꼭대기)
const BULGE_WIDTH := 1.3                    # 덩어리의 폭(마디 수)
const EAT_PULL := 0.5                       # 먹힌 벌레가 머리로 빨려 드는 데 걸리는, 걸음의 앞쪽 비율
const DEATH_SQUASH := 0.78                  # 죽을 때 머리가 앞뒤로 찌그러지는 비율(앞면은 장애물에 붙은 채)
const DEATH_SQUASH_TIME := 0.14             # 찌그러지는 데 걸리는 시간(초)
const SHAKE_TIME := 0.24                    # 죽을 때 화면 흔들림 시간(초)
const SHAKE_AMP := 0.18                     # 화면 흔들림 세기(월드 길이)
const POP_TIME := 0.9                       # 점수 +N 이 떠올라 사라지는 시간(초)
const GOLD_SCALE := 1.3                     # 황금 벌레의 크기 배율(일반 벌레보다 크게)
const GOLD_SPIN := 3.0                      # 황금 벌레가 제자리에서 도는 속도(라디안/초)
const BADGE_SIZE := Vector2(44, 28)         # 다른 층 벌레 배지(▲N·▼N)의 크기(화면 픽셀, 720×1280 기준). 작을수록 아래 벌레·바위를 덜 가린다
const BADGE_ALPHA := 0.55                   # 배지 불투명도: 아래 물체가 비쳐 보이게 반투명
const GOLD_BLINK := 1.5                     # 황금 벌레가 사라지기 이 시간(초) 전부터 0.1초마다 깜빡인다
