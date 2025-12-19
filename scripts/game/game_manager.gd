# game_manager.gd
# 전장 맵 ↔ 전투 씬 전환 관리
class_name GameManager
extends Node

enum GameState {
	FIELD_MAP,
	BATTLE,
	PAUSED
}

var current_state: GameState = GameState.FIELD_MAP

# 씬 참조
var field_map: FieldMap
var battle_scene: TestBattleScene

# 현재 전투 참가 유닛
var current_battle_player_units: Array = []
var current_battle_enemy_units: Array = []

# 전투 전 카메라 줌 저장
var saved_zoom_level: float = 1.0

# 씬 경로
const FIELD_MAP_SCENE = preload("res://scenes/field/field_map.tscn")
const BATTLE_SCENE = preload("res://scenes/test_battle.tscn")


func _ready() -> void:
	# 전장 맵으로 시작
	_load_field_map()


func _load_field_map() -> void:
	current_state = GameState.FIELD_MAP

	# 기존 씬 제거
	if battle_scene:
		battle_scene.queue_free()
		battle_scene = null

	# 전장 맵 로드
	field_map = FIELD_MAP_SCENE.instantiate()
	add_child(field_map)

	# 시그널 연결
	field_map.battle_triggered.connect(_on_battle_triggered)


func _on_battle_triggered(player_units: Array, enemy_units: Array) -> void:
	"""전투 시작"""
	current_battle_player_units = player_units
	current_battle_enemy_units = enemy_units

	# 전장 맵 일시정지 (제거하지 않음)
	field_map.paused = true
	field_map.visible = false

	# 카메라 줌 저장 및 리셋
	saved_zoom_level = field_map.zoom_level
	field_map.zoom_level = 1.0
	if field_map.camera:
		field_map.camera.zoom = Vector2(1.0, 1.0)

	# 전투 씬 로드
	_load_battle_scene()


func _load_battle_scene() -> void:
	current_state = GameState.BATTLE

	battle_scene = BATTLE_SCENE.instantiate()

	# 전장 유닛 정보 전달 (add_child 전에!)
	battle_scene.set_field_units(current_battle_player_units, current_battle_enemy_units)

	add_child(battle_scene)

	# 전투 종료 시그널 연결 (battle_manager가 생성될 때까지 대기)
	await get_tree().create_timer(0.1).timeout
	_connect_battle_signals()


func _connect_battle_signals() -> void:
	if battle_scene and battle_scene.battle_manager:
		if not battle_scene.battle_manager.battle_ended.is_connected(_on_battle_ended):
			battle_scene.battle_manager.battle_ended.connect(_on_battle_ended)
			print("[GameManager] Connected to battle_ended signal")


func _on_battle_ended(player_won: bool) -> void:
	"""전투 종료"""
	print("[GameManager] Battle ended. Player won: %s" % player_won)

	# 잠시 대기 (승리/패배 연출)
	await get_tree().create_timer(2.0).timeout

	# 전투 씬 제거
	if battle_scene:
		battle_scene.queue_free()
		battle_scene = null

	# 전장 맵 결과 반영 및 복귀
	_return_to_field_map(player_won)


func _return_to_field_map(player_won: bool) -> void:
	current_state = GameState.FIELD_MAP

	# 전장 맵 복귀
	field_map.visible = true
	field_map.paused = false

	# 카메라 줌 복원
	field_map.zoom_level = saved_zoom_level
	if field_map.camera:
		field_map.camera.zoom = Vector2(saved_zoom_level, saved_zoom_level)

	print("[GameManager] Returning to field map. Player won: %s" % player_won)

	# 전투 결과 반영 - HP 바 업데이트 및 사망 유닛 제거
	if player_won:
		# 적 유닛 제거 (패배한 적)
		for enemy_unit in current_battle_enemy_units:
			if is_instance_valid(enemy_unit):
				print("[GameManager] Removing defeated enemy: %s" % enemy_unit.data.display_name)
				field_map.enemy_units.erase(enemy_unit)
				enemy_unit.queue_free()
	else:
		# 플레이어 패배 시 참전 유닛 제거
		for player_unit in current_battle_player_units:
			if is_instance_valid(player_unit):
				print("[GameManager] Removing defeated player unit: %s" % player_unit.data.display_name)
				field_map.player_units.erase(player_unit)
				player_unit.queue_free()

	# 생존 유닛 전투 상태 해제 및 HP 바 업데이트
	for unit in current_battle_player_units + current_battle_enemy_units:
		if is_instance_valid(unit):
			unit.is_in_battle = false
			# HP 바 업데이트 (current_hp_percent는 TestBattleScene에서 이미 설정됨)
			unit._update_hp_bar()
			print("[GameManager] Updated HP bar for %s: %.0f%%" % [
				unit.data.display_name,
				unit.current_hp_percent * 100
			])

	# 초기화
	current_battle_player_units.clear()
	current_battle_enemy_units.clear()

	field_map.is_battle_active = false
	print("[GameManager] Field map resumed. Players: %d, Enemies: %d" % [field_map.player_units.size(), field_map.enemy_units.size()])
