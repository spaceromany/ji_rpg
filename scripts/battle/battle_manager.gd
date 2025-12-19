# battle_manager.gd
# 전투 전체 흐름 관리
class_name BattleManager
extends Node

signal battle_started()
signal battle_ended(player_won: bool)
signal action_executed(action_result: Dictionary)
signal waiting_for_player_input(battler: Battler)
signal enemy_turn_started(battler: Battler)  # 적군 턴 시작 시그널

enum BattleState {
	INACTIVE,
	STARTING,
	PLAYER_TURN,
	ENEMY_TURN,
	EXECUTING_ACTION,
	VICTORY,
	DEFEAT
}

var state: BattleState = BattleState.INACTIVE
var turn_manager: TurnManager
var player_party: Array = []
var enemy_party: Array = []
var is_processing_turn: bool = false  # 턴 처리 중 플래그


func _ready() -> void:
	turn_manager = TurnManager.new()
	turn_manager.turn_started.connect(_on_turn_started)


func start_battle(players: Array, enemies: Array) -> void:
	"""전투 시작"""
	player_party = players
	enemy_party = enemies

	# 시그널 연결
	for battler in player_party + enemy_party:
		battler.broke.connect(_on_battler_broke.bind(battler))
		battler.died.connect(_on_battler_died.bind(battler))

	state = BattleState.STARTING

	# 턴 매니저 초기화
	var all_battlers: Array = []
	all_battlers.append_array(player_party)
	all_battlers.append_array(enemy_party)
	turn_manager.initialize(all_battlers)

	battle_started.emit()

	# 첫 라운드 시작
	turn_manager.start_round()


func _on_turn_started(battler: Battler) -> void:
	"""배틀러 턴 시작 시 호출"""
	# 이미 턴 처리 중이면 무시 (중복 시그널 방지)
	if is_processing_turn:
		print("[BattleManager] Already processing turn, ignoring signal for: %s" % battler.data.display_name)
		return

	print("[BattleManager] Turn started for: %s (can_act: %s, state: %s)" % [
		battler.data.display_name,
		battler.can_act(),
		battler.state
	])

	# 비동기 처리를 위해 별도 함수로 분리
	_process_turn(battler)


func _process_turn(battler: Battler) -> void:
	"""실제 턴 처리 (비동기)"""
	is_processing_turn = true

	if not battler.can_act():
		# 브레이크 상태면 턴 스킵
		print("[BattleManager] %s cannot act, skipping turn" % battler.data.display_name)
		await get_tree().create_timer(0.5).timeout
		is_processing_turn = false
		turn_manager.advance_turn()
		return

	if battler.is_player:
		state = BattleState.PLAYER_TURN
		print("[BattleManager] Waiting for player input: %s" % battler.data.display_name)
		is_processing_turn = false  # 플레이어 입력 대기 시 플래그 해제
		waiting_for_player_input.emit(battler)
		# 플레이어 턴은 여기서 끝 - 입력 대기
	else:
		state = BattleState.ENEMY_TURN
		print("[BattleManager] Executing enemy AI: %s" % battler.data.display_name)
		is_processing_turn = false  # 시그널 발행 전 플래그 해제
		enemy_turn_started.emit(battler)  # 적군 턴 시작 시그널 (하이라이트용)
		await get_tree().create_timer(0.3).timeout  # 하이라이트 애니메이션 대기
		is_processing_turn = true
		await _execute_enemy_ai(battler)
		# is_processing_turn은 _execute_enemy_ai 내부에서 advance_turn 호출 전에 해제됨


func execute_player_action(
	attacker: Battler,
	skill: SkillData,
	targets: Array,
	bp_to_use: int = 0
) -> void:
	"""플레이어 행동 실행"""
	if state != BattleState.PLAYER_TURN:
		return

	state = BattleState.EXECUTING_ACTION

	# BP 사용
	if bp_to_use > 0:
		attacker.use_bp(bp_to_use)

	# SP 사용
	if not attacker.use_sp(skill.sp_cost):
		# SP 부족 - 행동 취소 (UI에서 미리 체크해야 함)
		state = BattleState.PLAYER_TURN
		return

	# 행동 실행
	await _execute_action(attacker, skill, targets, bp_to_use)

	# 승패 체크
	if _check_battle_end():
		return

	# 다음 턴
	turn_manager.advance_turn()


func _execute_action(
	attacker: Battler,
	skill: SkillData,
	targets: Array,
	bp_used: int
) -> void:
	"""실제 스킬 실행"""
	var results: Array = []

	match skill.effect_type:
		Enums.EffectType.DAMAGE:
			for target in targets:
				var result = DamageCalculator.calculate_damage(
					attacker, target, skill, bp_used
				)
				target.take_damage(result.total_damage)
				results.append(result)

		Enums.EffectType.HEAL:
			for target in targets:
				var heal_amount = DamageCalculator.calculate_heal(
					attacker, skill, bp_used
				)
				target.heal(heal_amount)
				results.append({"heal": heal_amount, "target": target})

		Enums.EffectType.BUFF, Enums.EffectType.DEBUFF:
			var modifier = skill.stat_modifier
			if skill.effect_type == Enums.EffectType.DEBUFF:
				modifier = -modifier

			# BP로 효과 강화 (지속시간 증가)
			var duration = skill.duration + bp_used

			for target in targets:
				target.apply_stat_modifier(skill.stat_type, modifier, duration)
				results.append({
					"stat": skill.stat_type,
					"modifier": modifier,
					"duration": duration
				})

	action_executed.emit({
		"attacker": attacker,
		"skill": skill,
		"targets": targets,
		"results": results
	})

	# 액션 연출 대기 (나중에 애니메이션 연동)
	await get_tree().create_timer(0.5).timeout


func _execute_enemy_ai(enemy: Battler) -> void:
	"""적 AI 행동 (심플 버전)"""
	# 가장 단순한 AI: 랜덤 스킬, 랜덤 타겟
	if enemy.data.skills.is_empty():
		is_processing_turn = false
		turn_manager.advance_turn()
		return

	var skill = enemy.data.skills.pick_random()

	# 타겟 선택
	var targets: Array = []
	match skill.target_type:
		Enums.TargetType.SINGLE_ENEMY:
			# 적 입장에서 적 = 플레이어
			var alive_players = player_party.filter(func(b): return b.is_alive())
			if not alive_players.is_empty():
				targets.append(alive_players.pick_random())

		Enums.TargetType.ALL_ENEMIES:
			targets = player_party.filter(func(b): return b.is_alive())

		Enums.TargetType.SINGLE_ALLY:
			var alive_enemies = enemy_party.filter(func(b): return b.is_alive())
			if not alive_enemies.is_empty():
				targets.append(alive_enemies.pick_random())

		Enums.TargetType.ALL_ALLIES:
			targets = enemy_party.filter(func(b): return b.is_alive())

		Enums.TargetType.SELF:
			targets.append(enemy)

	if targets.is_empty():
		is_processing_turn = false
		turn_manager.advance_turn()
		return

	state = BattleState.EXECUTING_ACTION
	await _execute_action(enemy, skill, targets, 0)

	if _check_battle_end():
		is_processing_turn = false
		return

	is_processing_turn = false
	turn_manager.advance_turn()


func _on_battler_broke(battler: Battler) -> void:
	turn_manager.on_battler_broke(battler)


func _on_battler_died(battler: Battler) -> void:
	turn_manager.on_battler_died(battler)


func _check_battle_end() -> bool:
	"""승패 체크"""
	var players_alive = player_party.any(func(b): return b.is_alive())
	var enemies_alive = enemy_party.any(func(b): return b.is_alive())

	if not enemies_alive:
		state = BattleState.VICTORY
		battle_ended.emit(true)
		return true

	if not players_alive:
		state = BattleState.DEFEAT
		battle_ended.emit(false)
		return true

	return false


func get_current_battler() -> Battler:
	return turn_manager.get_current_battler()


func get_valid_targets(skill: SkillData, from_player: bool) -> Array:
	"""스킬에 따른 유효 타겟 목록 반환"""
	var targets: Array = []

	match skill.target_type:
		Enums.TargetType.SINGLE_ENEMY:
			if from_player:
				targets = enemy_party.filter(func(b): return b.is_alive())
			else:
				targets = player_party.filter(func(b): return b.is_alive())

		Enums.TargetType.ALL_ENEMIES:
			if from_player:
				targets = enemy_party.filter(func(b): return b.is_alive())
			else:
				targets = player_party.filter(func(b): return b.is_alive())

		Enums.TargetType.SINGLE_ALLY:
			if from_player:
				targets = player_party.filter(func(b): return b.is_alive())
			else:
				targets = enemy_party.filter(func(b): return b.is_alive())

		Enums.TargetType.ALL_ALLIES:
			if from_player:
				targets = player_party.filter(func(b): return b.is_alive())
			else:
				targets = enemy_party.filter(func(b): return b.is_alive())

		Enums.TargetType.SELF:
			targets.append(get_current_battler())

	return targets
