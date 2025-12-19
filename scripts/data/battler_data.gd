# battler_data.gd
# 배틀러(캐릭터/적)의 기본 데이터 리소스
class_name BattlerData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

# 기본 스탯
@export_group("Base Stats")
@export var max_hp: int = 100
@export var max_sp: int = 50
@export var atk: int = 10
@export var def: int = 10
@export var matk: int = 10
@export var mdef: int = 10
@export var spd: int = 10
@export var crit_rate: float = 0.05
@export var evasion: float = 0.0

# 약점 시스템 (적 전용)
@export_group("Weakness System")
@export var weaknesses: Array = []  # Array of Enums.ElementType
@export var max_shield: int = 3  # 실드 포인트

# 사용 가능한 스킬
@export_group("Skills")
@export var skills: Array = []  # Array of SkillData

# 장착 무기 속성 (플레이어용)
@export_group("Equipment")
@export var weapon_elements: Array = []  # Array of Enums.ElementType
