# skill_data.gd
# 스킬 데이터 리소스
class_name SkillData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# 스킬 기본 정보
@export_group("Basic Info")
@export var sp_cost: int = 0
@export var element: Enums.ElementType = Enums.ElementType.SWORD
@export var target_type: Enums.TargetType = Enums.TargetType.SINGLE_ENEMY
@export var effect_type: Enums.EffectType = Enums.EffectType.DAMAGE

# 데미지/힐 관련
@export_group("Power")
@export var base_power: int = 100           # 기본 위력
@export var hit_count: int = 1              # 기본 타격 횟수

# BP 부스트 효과
@export_group("Boost Effects")
@export var boost_power_bonus: float = 0.5   # BP당 위력 증가 비율
@export var boost_hit_bonus: int = 1         # BP당 추가 타격 횟수 (0이면 위력만 증가)

# 버프/디버프용
@export_group("Buff/Debuff")
@export var stat_type: Enums.StatType = Enums.StatType.ATK
@export var stat_modifier: float = 0.0       # 스탯 변화율 (0.3 = 30% 증가)
@export var duration: int = 3                # 지속 턴


# BP 적용 후 최종 위력 계산
func get_boosted_power(bp_used: int) -> int:
	return int(base_power * (1.0 + boost_power_bonus * bp_used))


# BP 적용 후 최종 타격 횟수 계산
func get_boosted_hit_count(bp_used: int) -> int:
	return hit_count + (boost_hit_bonus * bp_used)
