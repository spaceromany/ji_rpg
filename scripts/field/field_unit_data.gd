# field_unit_data.gd
# 전장 맵에서 사용되는 유닛(군대) 데이터
class_name FieldUnitData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var is_player: bool = true

# 유닛에 포함된 배틀러들 (최대 4명)
@export var battler_data_list: Array[BattlerData] = []

# 전장 맵 관련
@export var move_speed: float = 100.0  # 이동 속도 (픽셀/초)
@export var detection_range: float = 150.0  # 적 감지 범위
@export var support_range: float = 200.0  # 지원 가능 범위 (인접 판정)

# 유닛 아이콘/색상
@export var unit_color: Color = Color.BLUE


func get_leader() -> BattlerData:
	"""리더(첫 번째 배틀러) 반환"""
	if battler_data_list.size() > 0:
		return battler_data_list[0]
	return null


func get_battler_count() -> int:
	return battler_data_list.size()


func is_defeated() -> bool:
	"""모든 배틀러가 사망했는지 확인"""
	for battler_data in battler_data_list:
		if battler_data.current_hp > 0:
			return false
	return true
