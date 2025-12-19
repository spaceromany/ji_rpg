# battler.gd
# 전투 중인 캐릭터/적의 런타임 상태를 관리
class_name Battler
extends Node

signal hp_changed(current: int, max_hp: int)
signal sp_changed(current: int, max_sp: int)
signal bp_changed(current: int)
signal shield_changed(current: int, max_shield: int)
signal state_changed(new_state: Enums.BattlerState)
signal broke()  # 브레이크 발생 시
signal died()

# 기본 데이터 참조
@export var data: BattlerData

# 런타임 상태
var current_hp: int
var current_sp: int
var current_bp: int = 0
var current_shield: int
var state: Enums.BattlerState = Enums.BattlerState.IDLE

# 버프/디버프 (StatType -> {modifier: float, turns: int})
var stat_modifiers: Dictionary = {}

# 브레이크 후 회복까지 남은 턴
var break_recovery_turns: int = 0

# 플레이어 여부
var is_player: bool = true


func _ready() -> void:
	if data:
		initialize()


func initialize() -> void:
	# BattlerData의 현재 HP/SP 사용 (전투 간 상태 유지)
	current_hp = data.get_current_hp()
	current_sp = data.get_current_sp()
	current_shield = data.max_shield
	current_bp = 0 if is_player else 0
	state = Enums.BattlerState.IDLE
	stat_modifiers.clear()


func sync_to_data() -> void:
	"""전투 종료 시 현재 상태를 BattlerData에 동기화"""
	data.set_current_hp(current_hp)
	data.set_current_sp(current_sp)


#region HP/SP/BP 관리
func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, data.max_hp)

	if current_hp <= 0:
		_die()


func heal(amount: int) -> void:
	current_hp = min(data.max_hp, current_hp + amount)
	hp_changed.emit(current_hp, data.max_hp)


func use_sp(amount: int) -> bool:
	if current_sp < amount:
		return false
	current_sp -= amount
	sp_changed.emit(current_sp, data.max_sp)
	return true


func restore_sp(amount: int) -> void:
	current_sp = min(data.max_sp, current_sp + amount)
	sp_changed.emit(current_sp, data.max_sp)


func gain_bp(amount: int = 1) -> void:
	current_bp = min(5, current_bp + amount)  # 최대 5BP
	bp_changed.emit(current_bp)


func use_bp(amount: int) -> bool:
	if current_bp < amount:
		return false
	current_bp -= amount
	bp_changed.emit(current_bp)
	return true
#endregion


#region 실드/브레이크 시스템
func hit_shield(element: Enums.ElementType) -> bool:
	"""약점 공격 시 실드 감소. 브레이크 발생 시 true 반환"""
	if state == Enums.BattlerState.BROKEN:
		return false

	if element in data.weaknesses:
		current_shield -= 1
		shield_changed.emit(current_shield, data.max_shield)

		if current_shield <= 0:
			_break()
			return true

	return false


func _break() -> void:
	state = Enums.BattlerState.BROKEN
	break_recovery_turns = 2  # 브레이크 후 1턴 스킵, 그 다음 턴 시작 시 회복
	state_changed.emit(state)
	broke.emit()


func recover_from_break() -> void:
	if state == Enums.BattlerState.BROKEN:
		current_shield = data.max_shield
		state = Enums.BattlerState.IDLE
		shield_changed.emit(current_shield, data.max_shield)
		state_changed.emit(state)
#endregion


#region 스탯 계산
func get_stat(stat_type: Enums.StatType) -> float:
	var base_value: float = _get_base_stat(stat_type)
	var modifier: float = 1.0

	if stat_modifiers.has(stat_type):
		modifier += stat_modifiers[stat_type].modifier

	return base_value * modifier


func _get_base_stat(stat_type: Enums.StatType) -> float:
	match stat_type:
		Enums.StatType.ATK:
			return data.atk
		Enums.StatType.DEF:
			return data.def
		Enums.StatType.MATK:
			return data.matk
		Enums.StatType.MDEF:
			return data.mdef
		Enums.StatType.SPD:
			return data.spd
		Enums.StatType.CRIT:
			return data.crit_rate
		Enums.StatType.EVASION:
			return data.evasion
	return 0.0


func apply_stat_modifier(stat_type: Enums.StatType, modifier: float, duration: int) -> void:
	stat_modifiers[stat_type] = {
		"modifier": modifier,
		"turns": duration
	}


func tick_modifiers() -> void:
	"""턴 종료 시 호출 - 버프/디버프 지속시간 감소"""
	var to_remove: Array = []

	for stat_type in stat_modifiers:
		stat_modifiers[stat_type].turns -= 1
		if stat_modifiers[stat_type].turns <= 0:
			to_remove.append(stat_type)

	for stat_type in to_remove:
		stat_modifiers.erase(stat_type)
#endregion


#region 턴 관리
func on_turn_start() -> void:
	"""턴 시작 시 호출"""
	# 브레이크 회복 체크
	if state == Enums.BattlerState.BROKEN:
		break_recovery_turns -= 1
		if break_recovery_turns <= 0:
			recover_from_break()

	# 플레이어는 턴 시작 시 BP 1 획득
	if is_player and state != Enums.BattlerState.BROKEN:
		gain_bp(1)


func on_turn_end() -> void:
	"""턴 종료 시 호출"""
	tick_modifiers()


func can_act() -> bool:
	return state == Enums.BattlerState.IDLE
#endregion


func _die() -> void:
	state = Enums.BattlerState.DEAD
	state_changed.emit(state)
	died.emit()


func is_alive() -> bool:
	return state != Enums.BattlerState.DEAD
