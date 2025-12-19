# turn_manager.gd
# 턴 순서 관리
class_name TurnManager
extends RefCounted

signal turn_order_changed(order: Array)
signal turn_started(battler: Battler)
signal round_started(round_number: int)

var battlers: Array = []
var turn_order: Array = []
var current_turn_index: int = 0
var current_round: int = 1


func initialize(all_battlers: Array) -> void:
	battlers = all_battlers
	current_round = 1
	_calculate_turn_order()


func _calculate_turn_order() -> void:
	"""속도 기반 턴 순서 계산"""
	turn_order.clear()

	# 살아있고 브레이크 상태가 아닌 배틀러만 포함
	for battler in battlers:
		if battler.is_alive():
			turn_order.append(battler)

	# 속도 내림차순 정렬 (속도가 높을수록 먼저 행동)
	turn_order.sort_custom(_compare_speed)

	# 브레이크 상태인 배틀러는 맨 뒤로
	var broken_battlers: Array = []
	var active_battlers: Array = []

	for battler in turn_order:
		if battler.state == Enums.BattlerState.BROKEN:
			broken_battlers.append(battler)
		else:
			active_battlers.append(battler)

	turn_order = active_battlers + broken_battlers
	turn_order_changed.emit(turn_order)


func _compare_speed(a: Battler, b: Battler) -> bool:
	var speed_a = a.get_stat(Enums.StatType.SPD)
	var speed_b = b.get_stat(Enums.StatType.SPD)

	# 속도가 같으면 랜덤
	if speed_a == speed_b:
		return randf() > 0.5

	return speed_a > speed_b


func start_round() -> void:
	"""새 라운드 시작"""
	print("[TurnManager] start_round: ", current_round)
	round_started.emit(current_round)
	_calculate_turn_order()
	current_turn_index = 0

	# 모든 배틀러 턴 시작 처리 (BP 획득 등)
	for battler in battlers:
		if battler.is_alive():
			battler.on_turn_start()

	# 첫 번째 배틀러 턴 시작 시그널
	var first = get_current_battler()
	if first:
		print("[TurnManager] First turn: ", first.data.display_name)
		turn_started.emit(first)


func get_current_battler() -> Battler:
	if current_turn_index >= turn_order.size():
		return null
	return turn_order[current_turn_index]


func advance_turn() -> Battler:
	"""현재 배틀러 턴 종료, 다음 배틀러 반환"""
	var current = get_current_battler()
	if current:
		current.on_turn_end()

	current_turn_index += 1

	# 라운드 종료 체크
	if current_turn_index >= turn_order.size():
		current_round += 1
		start_round()
	else:
		# 턴 순서 UI 업데이트 (현재 턴부터 남은 순서 표시)
		var remaining_order = turn_order.slice(current_turn_index)
		turn_order_changed.emit(remaining_order)

	var next = get_current_battler()
	if next:
		turn_started.emit(next)

	return next


func is_round_over() -> bool:
	return current_turn_index >= turn_order.size()


func get_turn_preview(count: int = 10) -> Array:
	"""앞으로의 턴 순서 미리보기"""
	var preview: Array = []
	var temp_index = current_turn_index

	for i in range(count):
		var index = temp_index % turn_order.size()
		if index < turn_order.size():
			preview.append(turn_order[index])
		temp_index += 1

	return preview


func on_battler_broke(_battler: Battler) -> void:
	"""배틀러가 브레이크될 때 턴 순서 재계산"""
	_calculate_turn_order()


func on_battler_died(battler: Battler) -> void:
	"""배틀러 사망 시 턴 순서에서 제거"""
	if battler in turn_order:
		var battler_index = turn_order.find(battler)
		turn_order.erase(battler)

		# 현재 인덱스 조정 (사망한 배틀러가 현재 턴 이전이었으면)
		if battler_index < current_turn_index:
			current_turn_index -= 1

	# 현재 턴부터 남은 순서 emit
	var remaining_order = turn_order.slice(current_turn_index)
	turn_order_changed.emit(remaining_order)


func get_all_alive_battlers() -> Array:
	"""살아있는 모든 배틀러 반환 (다음 사이클 계산용)"""
	return battlers.filter(func(b): return b.is_alive())
