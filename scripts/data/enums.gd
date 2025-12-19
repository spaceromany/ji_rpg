# enums.gd
# 전투 시스템에서 사용되는 열거형 정의
class_name Enums

# 공격/약점 속성 타입
enum ElementType {
	# 물리 속성
	SWORD,      # 검
	SPEAR,      # 창
	DAGGER,     # 단검
	AXE,        # 도끼
	BOW,        # 활
	STAFF,      # 지팡이

	# 마법 속성
	FIRE,       # 불
	ICE,        # 얼음
	THUNDER,    # 번개
	WIND,       # 바람
	LIGHT,      # 빛
	DARK        # 어둠
}

# 스킬 타겟 타입
enum TargetType {
	SINGLE_ENEMY,       # 적 단일
	ALL_ENEMIES,        # 적 전체
	SINGLE_ALLY,        # 아군 단일
	ALL_ALLIES,         # 아군 전체
	SELF                # 자기 자신
}

# 배틀러 상태
enum BattlerState {
	IDLE,               # 대기
	ACTING,             # 행동 중
	BROKEN,             # 브레이크 상태
	DEAD                # 사망
}

# 스킬 효과 타입
enum EffectType {
	DAMAGE,             # 데미지
	HEAL,               # 회복
	BUFF,               # 버프
	DEBUFF              # 디버프
}

# 스탯 타입 (버프/디버프용)
enum StatType {
	ATK,                # 물리 공격력
	DEF,                # 물리 방어력
	MATK,               # 마법 공격력
	MDEF,               # 마법 방어력
	SPD,                # 속도
	CRIT,               # 치명타율
	EVASION             # 회피율
}
