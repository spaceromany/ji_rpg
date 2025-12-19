# field_map.gd
# 실시간 전장 맵 컨트롤러
class_name FieldMap
extends Node2D

signal battle_triggered(player_units: Array, enemy_units: Array)
signal battle_ended(player_won: bool, participating_units: Array)

# 맵 설정
@export var map_size: Vector2 = Vector2(1152, 648)
@export var grid_size: int = 64

# 유닛 관리
var player_units: Array[FieldUnit] = []
var enemy_units: Array[FieldUnit] = []
var selected_unit: FieldUnit = null
var selected_units: Array[FieldUnit] = []  # 다중 선택

# 전투 상태
var is_battle_active: bool = false
var paused: bool = false

# 시간 정지
var time_stopped: bool = false

# 드래그 선택
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var selection_rect: ColorRect = null

# 줌
var zoom_level: float = 1.0
var min_zoom: float = 0.5
var max_zoom: float = 2.0
var zoom_speed: float = 0.1
var camera: Camera2D = null

# 컴포넌트
@onready var units_container: Node2D = $Units
@onready var terrain_container: Node2D = $Terrain
@onready var ui_layer: CanvasLayer = $UILayer

# UI 요소
var time_indicator: Label
var info_label: RichTextLabel

# 씬 참조
const FieldUnitScene = preload("res://scenes/field/field_unit.tscn")


func _ready() -> void:
	_setup_camera()
	_setup_map()
	_setup_ui()
	_setup_selection_rect()
	_spawn_test_units()


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = map_size / 2
	camera.zoom = Vector2(zoom_level, zoom_level)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)
	camera.make_current()


func _setup_selection_rect() -> void:
	# 드래그 선택 박스
	selection_rect = ColorRect.new()
	selection_rect.color = Color(0.3, 0.7, 1.0, 0.3)
	selection_rect.visible = false
	selection_rect.z_index = 100
	add_child(selection_rect)


func _setup_map() -> void:
	# 배경
	var bg = ColorRect.new()
	bg.size = map_size
	bg.color = Color(0.15, 0.2, 0.15)
	bg.z_index = -10
	add_child(bg)

	# 그리드 라인
	_draw_grid()


func _setup_ui() -> void:
	# 시간 상태 표시
	time_indicator = Label.new()
	time_indicator.text = "▶ 진행 중"
	time_indicator.position = Vector2(map_size.x / 2 - 50, 10)
	time_indicator.add_theme_font_size_override("font_size", 18)
	time_indicator.add_theme_color_override("font_color", Color.GREEN)
	ui_layer.add_child(time_indicator)

	# 조작 안내 업데이트
	info_label = $UILayer/InfoPanel/InfoLabel
	if info_label:
		info_label.text = """[color=yellow]전장 맵[/color]
[color=gray]Space: 시간 정지/재개[/color]
좌클릭: 유닛 선택
드래그: 다중 선택
우클릭: 이동 명령
휠: 줌 인/아웃
적과 접촉 시 전투 시작"""


func _draw_grid() -> void:
	for x in range(0, int(map_size.x), grid_size):
		var line = Line2D.new()
		line.add_point(Vector2(x, 0))
		line.add_point(Vector2(x, map_size.y))
		line.default_color = Color(0.3, 0.3, 0.3, 0.3)
		line.width = 1
		add_child(line)

	for y in range(0, int(map_size.y), grid_size):
		var line = Line2D.new()
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(map_size.x, y))
		line.default_color = Color(0.3, 0.3, 0.3, 0.3)
		line.width = 1
		add_child(line)


func _spawn_test_units() -> void:
	# 플레이어 유닛들 (우측)
	var player1_data = _create_player_unit_data("1부대", Color(0.2, 0.5, 0.9))
	var player2_data = _create_player_unit_data("2부대", Color(0.3, 0.6, 1.0))
	var player3_data = _create_player_unit_data("3부대", Color(0.2, 0.4, 0.8))

	spawn_unit(player1_data, Vector2(900, 250))
	spawn_unit(player2_data, Vector2(950, 350))
	spawn_unit(player3_data, Vector2(850, 400))

	# 적 유닛들 (좌측)
	var enemy1_data = _create_enemy_unit_data("적 선봉대", Color(0.9, 0.2, 0.2))
	var enemy2_data = _create_enemy_unit_data("적 본대", Color(0.8, 0.3, 0.3))
	var enemy3_data = _create_enemy_unit_data("적 후위대", Color(0.7, 0.2, 0.2))

	spawn_unit(enemy1_data, Vector2(200, 300))
	spawn_unit(enemy2_data, Vector2(150, 400))
	spawn_unit(enemy3_data, Vector2(250, 450))


func _create_player_unit_data(unit_name: String, color: Color) -> FieldUnitData:
	var data = FieldUnitData.new()
	data.id = unit_name.to_lower().replace(" ", "_")
	data.display_name = unit_name
	data.is_player = true
	data.unit_color = color
	data.move_speed = 150.0
	data.support_range = 200.0

	data.battler_data_list.append(SampleData.create_warrior())
	data.battler_data_list.append(SampleData.create_mage())

	return data


func _create_enemy_unit_data(unit_name: String, color: Color) -> FieldUnitData:
	var data = FieldUnitData.new()
	data.id = unit_name.to_lower().replace(" ", "_")
	data.display_name = unit_name
	data.is_player = false
	data.unit_color = color
	data.move_speed = 60.0
	data.detection_range = 800.0  # 맵 전체 감지
	data.support_range = 180.0

	data.battler_data_list.append(SampleData.create_goblin())
	data.battler_data_list.append(SampleData.create_goblin())

	return data


func spawn_unit(unit_data: FieldUnitData, pos: Vector2) -> FieldUnit:
	var unit = FieldUnitScene.instantiate()
	unit.data = unit_data
	units_container.add_child(unit)
	unit.global_position = pos
	unit.initialize(unit_data)

	# 시그널 연결
	unit.unit_clicked.connect(_on_unit_clicked)
	unit.contact_made.connect(_on_contact_made)

	if unit_data.is_player:
		player_units.append(unit)
	else:
		enemy_units.append(unit)

	return unit


func _input(event: InputEvent) -> void:
	if is_battle_active or paused:
		return

	# 스페이스바: 시간 정지/재개
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			_toggle_time_stop()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE and event.pressed:
			_deselect_all()
			return

	# 마우스 버튼 처리
	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()

		# 좌클릭 시작 - 드래그 선택 시작
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 유닛 위에서 클릭했는지 확인
			var clicked_unit = _get_unit_at_position(mouse_pos)
			if clicked_unit == null:
				# 빈 공간 클릭 - 드래그 시작
				is_dragging = true
				drag_start = mouse_pos
				selection_rect.position = drag_start
				selection_rect.size = Vector2.ZERO
				selection_rect.visible = true

		# 좌클릭 해제 - 드래그 선택 완료
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				_finish_drag_selection()
				is_dragging = false
				selection_rect.visible = false

		# 우클릭: 선택된 유닛들 이동
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected_units.size() > 0:
				var target_pos = mouse_pos
				# 맵 범위 제한
				target_pos.x = clamp(target_pos.x, 30, map_size.x - 30)
				target_pos.y = clamp(target_pos.y, 30, map_size.y - 30)
				_move_selected_units(target_pos)

		# 마우스 휠: 줌 인/아웃 (전투 중이 아닐 때만)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and not is_battle_active:
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not is_battle_active:
			_zoom_camera(-zoom_speed)

	# 마우스 이동 - 드래그 중 선택 박스 업데이트
	if event is InputEventMouseMotion and is_dragging:
		_update_selection_rect(get_global_mouse_position())


func _zoom_camera(delta: float) -> void:
	"""카메라 줌 조절"""
	zoom_level = clamp(zoom_level + delta, min_zoom, max_zoom)
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", Vector2(zoom_level, zoom_level), 0.1)


func _get_unit_at_position(pos: Vector2) -> FieldUnit:
	"""해당 위치에 있는 플레이어 유닛 반환"""
	for unit in player_units:
		var unit_rect = Rect2(unit.global_position - Vector2(22, 22), Vector2(44, 44))
		if unit_rect.has_point(pos):
			return unit
	return null


func _update_selection_rect(current_pos: Vector2) -> void:
	"""드래그 중 선택 박스 업데이트"""
	var rect_pos = Vector2(min(drag_start.x, current_pos.x), min(drag_start.y, current_pos.y))
	var rect_size = Vector2(abs(current_pos.x - drag_start.x), abs(current_pos.y - drag_start.y))
	selection_rect.position = rect_pos
	selection_rect.size = rect_size


func _finish_drag_selection() -> void:
	"""드래그 선택 완료 - 박스 안의 유닛 선택"""
	var rect = Rect2(selection_rect.position, selection_rect.size)

	# 최소 크기 체크 (너무 작으면 클릭으로 간주)
	if rect.size.x < 10 and rect.size.y < 10:
		return

	# 기존 선택 해제
	_deselect_all()

	# 박스 안의 플레이어 유닛 선택
	for unit in player_units:
		if rect.has_point(unit.global_position):
			selected_units.append(unit)
			unit.set_selected(true)

	if selected_units.size() > 0:
		selected_unit = selected_units[0]
		print("[FieldMap] Selected %d units: %s" % [selected_units.size(), selected_units.map(func(u): return u.data.display_name)])


func _move_selected_units(target_pos: Vector2) -> void:
	"""선택된 모든 유닛을 목표 위치로 이동 (포메이션 유지)"""
	if selected_units.size() == 0:
		return

	# 선택된 유닛들의 중심점 계산
	var center = Vector2.ZERO
	for unit in selected_units:
		center += unit.global_position
	center /= selected_units.size()

	# 각 유닛을 상대적 위치 유지하며 이동
	for unit in selected_units:
		var offset = unit.global_position - center
		var unit_target = target_pos + offset
		# 맵 범위 제한
		unit_target.x = clamp(unit_target.x, 30, map_size.x - 30)
		unit_target.y = clamp(unit_target.y, 30, map_size.y - 30)
		unit.move_to(unit_target)

	print("[FieldMap] Moving %d units to %s" % [selected_units.size(), target_pos])


func _toggle_time_stop() -> void:
	time_stopped = not time_stopped

	# 모든 유닛에 시간 정지 상태 전달
	for unit in player_units + enemy_units:
		unit.time_paused = time_stopped

	# UI 업데이트
	if time_indicator:
		if time_stopped:
			time_indicator.text = "⏸ 정지"
			time_indicator.add_theme_color_override("font_color", Color.YELLOW)
		else:
			time_indicator.text = "▶ 진행 중"
			time_indicator.add_theme_color_override("font_color", Color.GREEN)


func _on_unit_clicked(unit: FieldUnit) -> void:
	if is_battle_active:
		return

	# 플레이어 유닛만 선택 가능
	if unit.data.is_player:
		_select_single_unit(unit)


func _select_single_unit(unit: FieldUnit) -> void:
	"""단일 유닛 선택 (기존 선택 해제)"""
	_deselect_all()

	selected_unit = unit
	selected_units.append(unit)
	unit.set_selected(true)
	print("[FieldMap] Selected: %s" % unit.data.display_name)


func _deselect_all() -> void:
	"""모든 유닛 선택 해제"""
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	selected_unit = null


func _on_contact_made(initiator: FieldUnit, target: FieldUnit) -> void:
	"""유닛 접촉 시 전투 시작"""
	if is_battle_active or time_stopped:
		return

	print("[FieldMap] Contact! %s vs %s" % [initiator.data.display_name, target.data.display_name])

	var all_units: Array = []
	all_units.append_array(player_units)
	all_units.append_array(enemy_units)

	var participating_players: Array = []
	var participating_enemies: Array = []

	# 접촉한 유닛 추가
	if initiator.data.is_player:
		participating_players.append(initiator)
		participating_enemies.append(target)
	else:
		participating_players.append(target)
		participating_enemies.append(initiator)

	# 인접 아군 추가 (최대 4개)
	var main_player = participating_players[0]
	var main_enemy = participating_enemies[0]

	print("[FieldMap] Main player: %s at %s, support_range: %s" % [main_player.data.display_name, main_player.global_position, main_player.data.support_range])

	var player_allies = main_player.get_nearby_allies(all_units)
	print("[FieldMap] Found %d player allies in range" % player_allies.size())
	for ally in player_allies:
		var dist = main_player.global_position.distance_to(ally.global_position)
		print("[FieldMap]   - %s at distance %s" % [ally.data.display_name, dist])
		if participating_players.size() >= 4:
			break
		if ally not in participating_players:
			participating_players.append(ally)

	var enemy_allies = main_enemy.get_nearby_allies(all_units)
	print("[FieldMap] Found %d enemy allies in range" % enemy_allies.size())
	for ally in enemy_allies:
		var dist = main_enemy.global_position.distance_to(ally.global_position)
		print("[FieldMap]   - %s at distance %s" % [ally.data.display_name, dist])
		if participating_enemies.size() >= 4:
			break
		if ally not in participating_enemies:
			participating_enemies.append(ally)

	print("[FieldMap] Final participants - Players: %s, Enemies: %s" % [
		participating_players.map(func(u): return u.data.display_name),
		participating_enemies.map(func(u): return u.data.display_name)
	])
	_start_battle(participating_players, participating_enemies)


func _start_battle(p_units: Array, e_units: Array) -> void:
	is_battle_active = true

	for unit in p_units + e_units:
		unit.is_in_battle = true
		unit.stop()

	print("[FieldMap] Battle started!")
	print("  Players (%d): %s" % [p_units.size(), p_units.map(func(u): return u.data.display_name)])
	print("  Enemies (%d): %s" % [e_units.size(), e_units.map(func(u): return u.data.display_name)])

	battle_triggered.emit(p_units, e_units)


func end_battle(player_won: bool, _player_units_result: Array, _enemy_units_result: Array) -> void:
	is_battle_active = false
	print("[FieldMap] Battle ended. Player won: %s" % player_won)


func _process(_delta: float) -> void:
	if is_battle_active or paused or time_stopped:
		return

	_update_enemy_ai()


func _update_enemy_ai() -> void:
	"""적 AI - 가장 가까운 플레이어 추적"""
	for enemy in enemy_units:
		if not is_instance_valid(enemy) or enemy.is_in_battle:
			continue

		var closest_player: FieldUnit = null
		var closest_distance: float = INF

		for player in player_units:
			if not is_instance_valid(player):
				continue
			var dist = enemy.global_position.distance_to(player.global_position)
			if dist < closest_distance and dist < enemy.data.detection_range:
				closest_distance = dist
				closest_player = player

		# 플레이어를 발견하면 추적 (이미 이동 중이어도 타겟 갱신)
		if closest_player:
			enemy.move_to(closest_player.global_position)
