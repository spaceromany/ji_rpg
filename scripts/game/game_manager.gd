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

	# 전투 씬 로드
	_load_battle_scene()


func _load_battle_scene() -> void:
	current_state = GameState.BATTLE

	battle_scene = BATTLE_SCENE.instantiate()
	add_child(battle_scene)

	# 전투 씬에 참전 유닛 정보 전달
	# 기존 test_battle_scene.gd를 수정하여 외부에서 유닛을 받을 수 있도록 해야 함
	# 일단은 기본 전투로 진행

	# 전투 종료 시그널 연결
	if battle_scene.has_signal("battle_ended"):
		# battle_manager의 시그널을 통해 연결
		await get_tree().process_frame
		if battle_scene.battle_manager:
			battle_scene.battle_manager.battle_ended.connect(_on_battle_ended)


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

	# 전투 결과 반영
	if player_won:
		# 적 유닛 제거
		for enemy_unit in current_battle_enemy_units:
			if is_instance_valid(enemy_unit):
				enemy_unit.update_after_battle(0)  # HP 0 = 패배
	else:
		# 플레이어 유닛 데미지 (간단히 처리)
		for player_unit in current_battle_player_units:
			if is_instance_valid(player_unit):
				player_unit.update_after_battle(0.5)  # HP 50%로

	# 참전 유닛 전투 상태 해제
	for unit in current_battle_player_units + current_battle_enemy_units:
		if is_instance_valid(unit):
			unit.is_in_battle = false

	# 초기화
	current_battle_player_units.clear()
	current_battle_enemy_units.clear()

	field_map.is_battle_active = false
