# damage_calculator.gd
# 데미지 계산 유틸리티
class_name DamageCalculator
extends RefCounted

# 브레이크 상태 데미지 배율
const BREAK_DAMAGE_MULTIPLIER: float = 1.5

# 물리 속성 목록
const PHYSICAL_ELEMENTS: Array = [
	Enums.ElementType.SWORD,
	Enums.ElementType.SPEAR,
	Enums.ElementType.DAGGER,
	Enums.ElementType.AXE,
	Enums.ElementType.BOW,
	Enums.ElementType.STAFF
]


static func is_physical(element: int) -> bool:
	return element in PHYSICAL_ELEMENTS


static func calculate_damage(
	attacker: Battler,
	defender: Battler,
	skill: SkillData,
	bp_used: int = 0
) -> Dictionary:
	"""
	데미지 계산 결과 반환:
	{
		total_damage: int,      # 총 데미지
		hit_count: int,         # 타격 횟수
		is_critical: bool,      # 크리티컬 여부
		is_weakness: bool,      # 약점 공격 여부
		shield_broken: bool     # 이 공격으로 브레이크 발생 여부
	}
	"""
	var result = {
		"total_damage": 0,
		"hit_count": 0,
		"is_critical": false,
		"is_weakness": false,
		"shield_broken": false
	}

	# 스킬 위력 계산 (BP 적용)
	var power = skill.get_boosted_power(bp_used)
	var hit_count = skill.get_boosted_hit_count(bp_used)
	result.hit_count = hit_count

	# 약점 체크
	result.is_weakness = skill.element in defender.data.weaknesses

	# 공격력/방어력 결정 (물리 vs 마법)
	var atk_stat: float
	var def_stat: float

	if is_physical(skill.element):
		atk_stat = attacker.get_stat(Enums.StatType.ATK)
		def_stat = defender.get_stat(Enums.StatType.DEF)
	else:
		atk_stat = attacker.get_stat(Enums.StatType.MATK)
		def_stat = defender.get_stat(Enums.StatType.MDEF)

	# 기본 데미지 공식
	# 데미지 = (공격력 * 스킬위력 / 100) - (방어력 / 2)
	var base_damage = (atk_stat * power / 100.0) - (def_stat / 2.0)
	base_damage = max(1, base_damage)  # 최소 1 데미지

	# 크리티컬 체크
	var crit_rate = attacker.get_stat(Enums.StatType.CRIT)
	if randf() < crit_rate:
		result.is_critical = true
		base_damage *= 1.5

	# 브레이크 상태면 추가 데미지
	if defender.state == Enums.BattlerState.BROKEN:
		base_damage *= BREAK_DAMAGE_MULTIPLIER

	# 랜덤 변동 (±5%)
	var variance = randf_range(0.95, 1.05)
	base_damage *= variance

	# 총 데미지 (히트 수 * 단일 히트 데미지)
	result.total_damage = int(base_damage) * hit_count

	# 실드 히트 처리 (브레이크 상태가 아닐 때만)
	if result.is_weakness and defender.state != Enums.BattlerState.BROKEN:
		# 각 히트마다 실드 감소
		for i in range(hit_count):
			if defender.hit_shield(skill.element):
				result.shield_broken = true
				break

	return result


static func calculate_heal(
	caster: Battler,
	skill: SkillData,
	bp_used: int = 0
) -> int:
	"""회복량 계산"""
	var power = skill.get_boosted_power(bp_used)
	var matk = caster.get_stat(Enums.StatType.MATK)

	var heal_amount = matk * power / 100.0
	heal_amount *= randf_range(0.95, 1.05)

	return int(heal_amount)
