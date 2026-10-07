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
