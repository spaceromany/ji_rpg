# test_battle_scene.gd
# 옥토패스 스타일 전투 씬 컨트롤러
class_name TestBattleScene
extends Node2D

# UI 참조
@onready var turn_order_ui: TurnOrderUI = $CanvasLayer/TurnOrderUI
@onready var command_ui: CommandUI = $CanvasLayer/CommandUI
@onready var target_selector_ui: TargetSelectorUI = $CanvasLayer/TargetSelectorUI
@onready var player_status_container: VBoxContainer = $CanvasLayer/PlayerStatusContainer
@onready var enemy_status_container: VBoxContainer = $CanvasLayer/EnemyStatusContainer
@onready var battle_log: RichTextLabel = $CanvasLayer/BattleLog
@onready var popup_container: Control = $CanvasLayer/PopupContainer
@onready var player_sprites_container: Node2D = $PlayerSprites
@onready var enemy_sprites_container: Node2D = $EnemySprites
@onready var battle_camera: Camera2D = $BattleCamera

# 전투 시스템
var battle_manager: BattleManager
var player_battlers: Array = []
var enemy_battlers: Array = []

# 현재 선택 상태
var current_skill: SkillData
var current_targets: Array = []
var current_bp_used: int = 0

# UI 씬 참조
const BattlerStatusUIScene = preload("res://scenes/ui/battler_status_ui.tscn")
const EnemyStatusUIScene = preload("res://scenes/ui/enemy_status_ui.tscn")

# 플레이어 상태 UI 참조 저장
var player_status_uis: Array = []
var enemy_status_uis: Array = []

# 외부에서 전달받은 필드 유닛
var field_player_units: Array = []
var field_enemy_units: Array = []


func _ready() -> void:
	# 전투 씬 자체 카메라 활성화 (전장 맵 카메라와 독립)
	if battle_camera:
		battle_camera.make_current()
	await get_tree().process_frame
	_setup_battle()


func set_field_units(player_units: Array, enemy_units: Array) -> void:
	"""GameManager에서 호출 - 전장 유닛 정보 설정"""
	field_player_units = player_units
	field_enemy_units = enemy_units
	print("[TestBattle] Received field units - Players: %d, Enemies: %d" % [player_units.size(), enemy_units.size()])


func _setup_battle() -> void:
	print("[TestBattle] _setup_battle started")

	# 전투 매니저 생성
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# 필드 유닛이 있으면 해당 유닛의 배틀러 사용, 없으면 기본 테스트용
	if field_player_units.size() > 0:
		_setup_battlers_from_field_units()
	else:
		_setup_default_battlers()

	# UI 설정
	_setup_ui()

	await get_tree().process_frame

	# BattleManager 시그널 연결
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.waiting_for_player_input.connect(_on_waiting_for_player_input)
	battle_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	battle_manager.action_executed.connect(_on_action_executed)

	# UI 시그널 연결
	command_ui.action_confirmed.connect(_on_command_action_confirmed)
	command_ui.cancelled.connect(_on_command_cancelled)
	target_selector_ui.target_selected.connect(_on_target_selected)
	target_selector_ui.cancelled.connect(_on_target_cancelled)
	target_selector_ui.selection_changed.connect(_on_target_selection_changed)

	# 턴 순서 UI 설정
	turn_order_ui.setup(battle_manager.turn_manager)

	# 전투 시작
	print("[TestBattle] Starting battle...")
	battle_manager.start_battle(player_battlers, enemy_battlers)


func _setup_battlers_from_field_units() -> void:
	"""필드 유닛에서 배틀러 생성 - 각 부대당 1명의 대표 배틀러"""
	print("[TestBattle] Setting up battlers from field units")

	# 플레이어 배틀러 생성 (부대당 1명)
	var player_index = 0
	for field_unit in field_player_units:
		if player_index >= 4:
			break
		if field_unit.data and field_unit.data.battler_data_list.size() > 0:
			# 첫 번째 배틀러(리더)를 대표로 사용
			var battler_data = field_unit.data.battler_data_list[0]
			var battler = _create_battler(battler_data, true, player_index)
			player_battlers.append(battler)
			player_index += 1

	# 적 배틀러 생성 (부대당 1명)
	var enemy_index = 0
	for field_unit in field_enemy_units:
		if enemy_index >= 4:
			break
		if field_unit.data and field_unit.data.battler_data_list.size() > 0:
			# 첫 번째 배틀러(리더)를 대표로 사용
			var battler_data = field_unit.data.battler_data_list[0]
			var battler = _create_battler(battler_data, false, enemy_index)
			enemy_battlers.append(battler)
			enemy_index += 1

	print("[TestBattle] Created %d player battlers (from %d units), %d enemy battlers (from %d units)" % [
		player_battlers.size(), field_player_units.size(),
		enemy_battlers.size(), field_enemy_units.size()
	])


func _setup_default_battlers() -> void:
	"""기본 테스트용 배틀러 생성"""
	print("[TestBattle] Using default test battlers")

	# 플레이어 파티 생성 (우측에 배치)
	var warrior = _create_battler(SampleData.create_warrior(), true, 0)
	var mage = _create_battler(SampleData.create_mage(), true, 1)
	player_battlers = [warrior, mage]

	# 적 파티 생성 (좌측에 배치)
	var goblin1 = _create_battler(SampleData.create_goblin(), false, 0)
	var goblin2 = _create_battler(SampleData.create_goblin(), false, 1)
	enemy_battlers = [goblin1, goblin2]


# 스프라이트 기본 위치 (종렬 배치용)
const PLAYER_BASE_X: float = 1400.0  # 아군 기본 X 위치
const ENEMY_BASE_X: float = 400.0    # 적군 기본 X 위치
const SPRITE_Y_START: float = 180.0  # Y 시작 위치
const SPRITE_Y_GAP: float = 220.0    # Y 간격 (스프라이트 간 여백 확보)
const STEP_FORWARD: float = 100.0    # 턴 시 앞으로 나오는 거리

func _create_battler(data: BattlerData, is_player: bool, index: int) -> Battler:
	var battler = Battler.new()
	battler.data = data
	battler.is_player = is_player
	add_child(battler)
	battler.initialize()

	# 스프라이트 생성 (옥토패스 스타일: 적 좌측, 아군 우측 - 종렬 배치)
	var sprite = ColorRect.new()
	sprite.size = Vector2(120, 180)  # 1920x1080 기준 크기

	# 이름 레이블
	var name_label = Label.new()
	name_label.text = data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, -35)
	name_label.size = Vector2(120, 30)
	name_label.add_theme_font_size_override("font_size", 18)
	sprite.add_child(name_label)

	# 종렬 배치: Y축으로 나열
	var y_pos = SPRITE_Y_START + index * SPRITE_Y_GAP

	if is_player:
		# 아군: 우측에 종렬 배치
		sprite.color = Color(0.3, 0.5, 0.8)
		sprite.position = Vector2(PLAYER_BASE_X, y_pos)
		player_sprites_container.add_child(sprite)
	else:
		# 적: 좌측에 종렬 배치
		sprite.color = Color(0.7, 0.3, 0.3)
		sprite.position = Vector2(ENEMY_BASE_X, y_pos)
		enemy_sprites_container.add_child(sprite)

	# 기본 위치 저장 (턴 시 복귀용)
	battler.set_meta("sprite", sprite)
	battler.set_meta("base_position", sprite.position)
	return battler


func _setup_ui() -> void:
	# 플레이어 상태 UI (우측 상단)
	for battler in player_battlers:
		var status_ui = BattlerStatusUIScene.instantiate()
		player_status_container.add_child(status_ui)
		status_ui.setup(battler)
		player_status_uis.append(status_ui)

	# 적 상태 UI (좌측 하단)
	for battler in enemy_battlers:
		var status_ui = EnemyStatusUIScene.instantiate()
		enemy_status_container.add_child(status_ui)
		status_ui.setup(battler)
		enemy_status_uis.append(status_ui)

		# 브레이크 시 팝업
		battler.broke.connect(_on_enemy_broke.bind(battler))
		# 사망 시 처리
		battler.died.connect(_on_battler_died.bind(battler))

	# 플레이어 사망 시 처리
	for battler in player_battlers:
		battler.died.connect(_on_battler_died.bind(battler))


func _on_battle_started() -> void:
	_log("[color=yellow]===== 전투 시작! =====[/color]")
	_log("[color=gray]R: 부스트 | ↑↓: 선택 | Enter: 확인 | Esc: 취소[/color]")
	Audio.play_bgm("battle")


func _on_battle_ended(player_won: bool) -> void:
	# 전투 결과를 BattlerData에 동기화
	_sync_battle_results()

	if player_won:
		_log("[color=green]===== 승리! =====[/color]")
		Audio.change_bgm("victory", 0.3, 0.5)
	else:
		_log("[color=red]===== 패배... =====[/color]")
		Audio.change_bgm("defeat", 0.3, 0.5)


func _sync_battle_results() -> void:
	"""전투 결과를 BattlerData와 FieldUnit에 동기화"""
	# 플레이어 배틀러 상태 동기화
	for i in range(player_battlers.size()):
		var battler = player_battlers[i]
		battler.sync_to_data()

		# FieldUnit HP 바 업데이트
		if i < field_player_units.size():
			var field_unit = field_player_units[i]
			if is_instance_valid(field_unit):
				var hp_percent = float(battler.current_hp) / float(battler.data.max_hp)
				field_unit.current_hp_percent = hp_percent
				print("[TestBattle] Synced player %s: HP=%d/%d (%.0f%%)" % [
					battler.data.display_name,
					battler.current_hp,
					battler.data.max_hp,
					hp_percent * 100
				])

	# 적 배틀러 상태 동기화
	for i in range(enemy_battlers.size()):
		var battler = enemy_battlers[i]
		battler.sync_to_data()

		# FieldUnit HP 바 업데이트
		if i < field_enemy_units.size():
			var field_unit = field_enemy_units[i]
			if is_instance_valid(field_unit):
				var hp_percent = float(battler.current_hp) / float(battler.data.max_hp)
				field_unit.current_hp_percent = hp_percent
				print("[TestBattle] Synced enemy %s: HP=%d/%d (%.0f%%)" % [
					battler.data.display_name,
					battler.current_hp,
					battler.data.max_hp,
					hp_percent * 100
				])


func _on_waiting_for_player_input(battler: Battler) -> void:
	print("[TestBattle] _on_waiting_for_player_input called for: %s" % battler.data.display_name)
	_log("")
	_log("[color=cyan]>>> %s의 턴 <<<[/color]" % battler.data.display_name)

	# 현재 턴 캐릭터 하이라이트
	_highlight_current_battler(battler)

	# 커맨드 UI 표시 (캐릭터 옆에 배치)
	_position_command_ui(battler)
	command_ui.show_commands(battler)
	print("[TestBattle] Command UI shown, waiting for input...")


func _position_command_ui(battler: Battler) -> void:
	# 현재 턴 캐릭터의 스프라이트 위치 근처에 커맨드 UI 배치
	if battler.has_meta("base_position"):
		var base_pos = battler.get_meta("base_position")
		# 아군: 캐릭터 왼쪽에 배치 (앞으로 나온 위치 기준)
		# 적군: 캐릭터 오른쪽에 배치
		if battler.is_player:
			command_ui.position = Vector2(base_pos.x - STEP_FORWARD - 350, base_pos.y - 80)
		else:
			command_ui.position = Vector2(base_pos.x + STEP_FORWARD + 150, base_pos.y - 80)


func _highlight_current_battler(battler: Battler) -> void:
	# 모든 스프라이트 원래 색으로 + 기본 위치로 복귀
	for b in player_battlers + enemy_battlers:
		if b.has_meta("sprite") and b.has_meta("base_position"):
			var sprite = b.get_meta("sprite")
			var base_pos = b.get_meta("base_position")

			# 색상 복원
			if b.state == Enums.BattlerState.BROKEN:
				sprite.color = Color(0.3, 0.3, 0.3)
			elif b.is_player:
				sprite.color = Color(0.3, 0.5, 0.8)
			else:
				sprite.color = Color(0.7, 0.3, 0.3)

			# 기본 위치로 부드럽게 복귀
			var tween = create_tween()
			tween.tween_property(sprite, "position", base_pos, 0.15).set_ease(Tween.EASE_OUT)

	# 현재 배틀러 하이라이트 + 앞으로 나오기
	if battler.has_meta("sprite") and battler.has_meta("base_position"):
		var sprite = battler.get_meta("sprite")
		var base_pos = battler.get_meta("base_position")

		# 밝은 노란색으로 하이라이트
		sprite.color = Color(0.9, 0.8, 0.3)

		# 앞으로 나오기 (아군은 왼쪽으로, 적군은 오른쪽으로)
		var step_direction = -1 if battler.is_player else 1
		var target_pos = base_pos + Vector2(step_direction * STEP_FORWARD, 0)

		var tween = create_tween()
		tween.tween_property(sprite, "position", target_pos, 0.2).set_ease(Tween.EASE_OUT)


func _on_enemy_turn_started(battler: Battler) -> void:
	"""적군 턴 시작 시 호출 - 하이라이트 처리"""
	print("[TestBattle] Enemy turn started: %s" % battler.data.display_name)
	_log("")
	_log("[color=red]>>> %s의 턴 <<<[/color]" % battler.data.display_name)
	_highlight_current_battler(battler)


func _on_command_action_confirmed(skill: SkillData, bp_used: int) -> void:
	Audio.play_se("select")
	current_skill = skill
	current_bp_used = bp_used
	var current_battler = battle_manager.get_current_battler()

	# 타겟 유형에 따른 처리
	if skill.target_type == Enums.TargetType.SELF:
		# 자기 자신 대상
		current_targets = [current_battler]
		_execute_action()

	elif skill.target_type == Enums.TargetType.ALL_ENEMIES:
		# 전체 적 대상
		current_targets = enemy_battlers.filter(func(b): return b.is_alive())
		_execute_action()

	elif skill.target_type == Enums.TargetType.ALL_ALLIES:
		# 전체 아군 대상
		current_targets = player_battlers.filter(func(b): return b.is_alive())
		_execute_action()

	elif skill.target_type == Enums.TargetType.SINGLE_ALLY:
		# 단일 아군 대상 선택
		var valid_targets = player_battlers.filter(func(b): return b.is_alive())
		target_selector_ui.show_targets(valid_targets, skill.display_name, false)

	else:
		# 단일 적 대상 선택
		var valid_targets = enemy_battlers.filter(func(b): return b.is_alive())
		target_selector_ui.show_targets(valid_targets, skill.display_name, false)


func _on_command_cancelled() -> void:
	Audio.play_se("cancel")
	current_skill = null
	current_targets.clear()


func _on_target_selected(targets: Array) -> void:
	Audio.play_se("select")
	current_targets = targets

	# 하이라이트 초기화
	var current_battler = battle_manager.get_current_battler()
	_highlight_current_battler(current_battler)

	_execute_action()


func _on_target_cancelled() -> void:
	Audio.play_se("cancel")
	var current_battler = battle_manager.get_current_battler()
	_highlight_current_battler(current_battler)

	# 커맨드 UI로 돌아가기
	command_ui.show_commands(current_battler)


func _on_target_selection_changed(target: Battler) -> void:
	_highlight_target(target)


func _highlight_target(target: Battler) -> void:
	var current_battler = battle_manager.get_current_battler()

	# 모든 스프라이트 원래 색으로 (위치는 유지)
	for b in player_battlers + enemy_battlers:
		if b.has_meta("sprite"):
			var sprite = b.get_meta("sprite")
			if b == current_battler:
				sprite.color = Color(0.9, 0.8, 0.3)  # 현재 턴
			elif b.state == Enums.BattlerState.BROKEN:
				sprite.color = Color(0.3, 0.3, 0.3)
			elif b.is_player:
				sprite.color = Color(0.3, 0.5, 0.8)
			else:
				sprite.color = Color(0.7, 0.3, 0.3)

	# 선택된 대상 하이라이트 (주황색) + 살짝 앞으로
	if target.has_meta("sprite") and target.has_meta("base_position"):
		var sprite = target.get_meta("sprite")
		var base_pos = target.get_meta("base_position")
		sprite.color = Color(1.0, 0.6, 0.2)

		# 타겟도 살짝 앞으로 (현재 턴 캐릭터보다 적게)
		var step_direction = -1 if target.is_player else 1
		var target_pos = base_pos + Vector2(step_direction * STEP_FORWARD * 0.5, 0)

		var tween = create_tween()
		tween.tween_property(sprite, "position", target_pos, 0.1).set_ease(Tween.EASE_OUT)


func _execute_action() -> void:
	var current_battler = battle_manager.get_current_battler()

	var target_name = "전체"
	if current_targets.size() == 1:
		target_name = current_targets[0].data.display_name

	var boost_text = ""
	if current_bp_used > 0:
		boost_text = " [color=orange]x%d Boost![/color]" % current_bp_used

	_log("%s → [color=white]%s[/color] → %s%s" % [
		current_battler.data.display_name,
		current_skill.display_name,
		target_name,
		boost_text
	])

	battle_manager.execute_player_action(
		current_battler,
		current_skill,
		current_targets,
		current_bp_used
	)


func _on_action_executed(action_result: Dictionary) -> void:
	var results: Array = action_result.results
	var targets: Array = action_result.targets

	for i in range(results.size()):
		var result = results[i]
		# 타겟 스프라이트 위치 가져오기
		var target: Battler = targets[i] if i < targets.size() else null

		if result.has("total_damage"):
			var dmg = result.total_damage
			var is_crit = result.is_critical
			var is_weak = result.is_weakness

			# 효과음 재생
			if is_crit:
				Audio.play_se("critical")
			else:
				Audio.play_se_with_variation("hit")

			# 데미지 팝업 - 타겟 스프라이트 위치 근처
			var popup_pos = _get_battler_popup_position(target)
			DamagePopup.create_damage(popup_container, popup_pos, dmg, is_crit, is_weak)

			var log_text = "  → [color=red]%d[/color]" % dmg
			if is_crit:
				log_text += " [color=yellow]CRITICAL![/color]"
			if is_weak:
				log_text += " [color=orange]WEAK![/color]"
			if result.shield_broken:
				log_text += " [color=red]BREAK![/color]"
				Audio.play_se("break")

			_log(log_text)

		elif result.has("heal"):
			var heal = result.heal
			Audio.play_se("heal")
			# 힐 팝업 - 타겟 스프라이트 위치 근처
			var heal_target = result.target if result.has("target") else target
			var popup_pos = _get_battler_popup_position(heal_target)
			DamagePopup.create_heal(popup_container, popup_pos, heal)
			_log("  → [color=green]+%d HP[/color]" % heal)


func _get_battler_popup_position(battler: Battler) -> Vector2:
	"""배틀러 스프라이트 위치에서 팝업 위치 계산"""
	if battler and battler.has_meta("sprite"):
		var sprite = battler.get_meta("sprite")
		# 스프라이트 중앙 상단 근처에 약간의 랜덤성 추가
		var sprite_pos = sprite.global_position
		var sprite_size = sprite.size
		return Vector2(
			sprite_pos.x + sprite_size.x / 2 + randf_range(-30, 30),
			sprite_pos.y + randf_range(-20, 20)
		)
	# 폴백: 화면 중앙
	return Vector2(randf_range(800, 1100), randf_range(400, 550))


func _on_enemy_broke(battler: Battler) -> void:
	# 브레이크 팝업 - 해당 적 스프라이트 위치에 표시
	var popup_pos = _get_battler_popup_position(battler)
	DamagePopup.create_break(popup_container, popup_pos)

	if battler.has_meta("sprite"):
		var sprite = battler.get_meta("sprite")
		sprite.color = Color(0.3, 0.3, 0.3)


func _on_battler_died(battler: Battler) -> void:
	_log("[color=gray]%s 쓰러짐![/color]" % battler.data.display_name)
	Audio.play_se("defeat")

	# 스프라이트 숨기기 (페이드 아웃 효과)
	if battler.has_meta("sprite"):
		var sprite = battler.get_meta("sprite")
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(sprite.hide)


func _log(text: String) -> void:
	battle_log.append_text(text + "\n")
