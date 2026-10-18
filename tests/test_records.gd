extends SceneTree

# 기록 판정과 표시 형식(순수 함수).
func _initialize() -> void:
	_test_to_ms()
	_test_format_time()
	_test_judge_time()
	_test_judge_score()
	_test_time_result_text()
	_test_time_layout()
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

# 판 배치 이름은 레벨-규칙버전이다. 바뀌면 옛 시간 기록은 다른 판의 기록이라 숨겨진다.
# 고정 시드 배치 시절 이름은 "8-1-1" 이었다. 무작위 배치(버전 2)에서 낸 기록과 섞이지 않는다.
func _test_time_layout() -> void:
	assert(Records.time_layout() == "8-2", "판 배치 이름: %s" % Records.time_layout())
