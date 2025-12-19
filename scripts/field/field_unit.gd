# field_unit.gd
# 전장 맵에서 이동하는 유닛 (실시간)
class_name FieldUnit
extends Node2D

signal unit_clicked(unit: FieldUnit)
signal contact_made(initiator: FieldUnit, target: FieldUnit)

@export var data: FieldUnitData

# 이동 관련
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var is_selected: bool = false

# 전투 관련
var is_in_battle: bool = false
var current_hp_percent: float = 1.0

# 시간 정지
var time_paused: bool = false

# 컴포넌트
var sprite: ColorRect
var label: Label
var selection_indicator: ColorRect
var hp_bar: ColorRect
var detection_area: Area2D
var path_line: Line2D
var arrow: Polygon2D
var support_range_circle: Node2D


func _ready() -> void:
	_setup_visuals()
	_setup_areas()
	_setup_path_display()
	_setup_support_range_circle()


func _setup_visuals() -> void:
	# 선택 표시 (먼저 추가해서 뒤에 배치)
	selection_indicator = ColorRect.new()
	selection_indicator.size = Vector2(50, 50)
	selection_indicator.position = Vector2(-25, -25)
	selection_indicator.color = Color(1, 1, 0, 0.5)
	selection_indicator.visible = false
	add_child(selection_indicator)

	# 유닛 스프라이트
	sprite = ColorRect.new()
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)
	sprite.color = data.unit_color if data else Color.GRAY
	add_child(sprite)

	# 유닛 이름
	label = Label.new()
	label.text = data.display_name if data else "Unit"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -38)
	label.size = Vector2(80, 20)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)

	# HP 바 배경
	var hp_bg = ColorRect.new()
	hp_bg.size = Vector2(40, 6)
	hp_bg.position = Vector2(-20, 24)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	add_child(hp_bg)

	# HP 바
	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(40, 6)
	hp_bar.position = Vector2(-20, 24)
	hp_bar.color = Color.GREEN
	add_child(hp_bar)


func _setup_areas() -> void:
	# 클릭 감지는 _input에서 직접 처리

	# 접촉 감지용 Area2D
	detection_area = Area2D.new()
	detection_area.collision_layer = 2 if (data and data.is_player) else 4
	detection_area.collision_mask = 4 if (data and data.is_player) else 2
	add_child(detection_area)

	var detect_collision = CollisionShape2D.new()
	var detect_shape = CircleShape2D.new()
	detect_shape.radius = 30.0  # 접촉 범위
	detect_collision.shape = detect_shape
	detection_area.add_child(detect_collision)

	detection_area.area_entered.connect(_on_detection_area_entered)


func _setup_path_display() -> void:
	# 이동 경로 점선
	path_line = Line2D.new()
	path_line.width = 2.0
	path_line.default_color = Color(1, 1, 0, 0.7)
	path_line.visible = false
	add_child(path_line)

	# 화살표
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(10, 8),
		Vector2(-10, 8)
	])
	arrow.color = Color(1, 1, 0, 0.8)
	arrow.visible = false
	add_child(arrow)


func _setup_support_range_circle() -> void:
	# 지원 범위 원을 그리는 커스텀 노드
	support_range_circle = Node2D.new()
	support_range_circle.z_index = -5  # 유닛 뒤에 배치
	add_child(support_range_circle)
	move_child(support_range_circle, 0)  # 가장 뒤로

	# draw 함수를 위한 스크립트 연결
	support_range_circle.set_script(preload("res://scripts/field/support_range_drawer.gd"))
	support_range_circle.setup(self)


func initialize(unit_data: FieldUnitData) -> void:
	data = unit_data
	if sprite:
		sprite.color = data.unit_color
	if label:
		label.text = data.display_name

	# Area2D 레이어 재설정
	if detection_area:
		detection_area.collision_layer = 2 if data.is_player else 4
		detection_area.collision_mask = 4 if data.is_player else 2

	_update_hp_bar()


func _process(delta: float) -> void:
	if is_in_battle or time_paused:
		return

	if not data:
		return

	if is_moving and target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		var distance = global_position.distance_to(target_position)

		if distance < 5.0:
			# 도착
			is_moving = false
			_hide_path()
			print("[FieldUnit] %s arrived at destination" % data.display_name)
		else:
			var move_amount = direction * data.move_speed * delta
			global_position += move_amount
			_update_path_display()


func move_to(pos: Vector2) -> void:
	"""목표 위치로 이동 시작"""
	target_position = pos
	is_moving = true
	print("[FieldUnit] %s moving to %s" % [data.display_name if data else "Unknown", pos])
	_update_path_display()


func stop() -> void:
	"""이동 중지"""
	is_moving = false
	target_position = Vector2.ZERO
	_hide_path()


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_indicator:
		selection_indicator.visible = selected

	# 이동 중이면 선택 해제해도 화살표 유지
	if is_moving:
		_update_path_display()


func _update_path_display() -> void:
	"""이동 경로 점선 + 화살표 표시"""
	if not is_moving or target_position == Vector2.ZERO:
		_hide_path()
		return

	# 로컬 좌표로 변환
	var local_target = target_position - global_position

	# 점선 그리기
	path_line.clear_points()
	var distance = local_target.length()
	var direction = local_target.normalized()
	var dash_length = 10.0
	var gap_length = 8.0
	var current_dist = 0.0

	while current_dist < distance - 15:  # 화살표 공간 남기기
		var start = direction * current_dist
		var end_dist = min(current_dist + dash_length, distance - 15)
		var end = direction * end_dist
		path_line.add_point(start)
		path_line.add_point(end)
		# gap을 위해 포인트 추가하지 않음 (Line2D는 연속선이므로 별도 처리 필요)
		current_dist = end_dist + gap_length

	path_line.visible = true

	# 화살표 위치 및 회전
	arrow.position = local_target
	arrow.rotation = direction.angle() + PI / 2
	arrow.visible = true


func _hide_path() -> void:
	if path_line:
		path_line.visible = false
		path_line.clear_points()
	if arrow:
		arrow.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 마우스 위치가 유닛 범위 내인지 확인
			var mouse_pos = get_global_mouse_position()
			var unit_rect = Rect2(global_position - Vector2(22, 22), Vector2(44, 44))
			if unit_rect.has_point(mouse_pos):
				print("[FieldUnit] %s clicked!" % (data.display_name if data else "Unknown"))
				unit_clicked.emit(self)


func _on_detection_area_entered(area: Area2D) -> void:
	"""다른 유닛과 접촉 감지"""
	var other_unit = area.get_parent()
	if other_unit is FieldUnit and other_unit != self:
		if other_unit.data.is_player != data.is_player:
			contact_made.emit(self, other_unit)


func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.size.x = 40 * current_hp_percent
		if current_hp_percent > 0.5:
			hp_bar.color = Color.GREEN
		elif current_hp_percent > 0.25:
			hp_bar.color = Color.YELLOW
		else:
			hp_bar.color = Color.RED


func update_after_battle(remaining_hp_percent: float) -> void:
	"""전투 후 상태 업데이트"""
	current_hp_percent = remaining_hp_percent
	_update_hp_bar()
	is_in_battle = false

	if remaining_hp_percent <= 0:
		queue_free()


func get_nearby_allies(all_units: Array, range_override: float = -1) -> Array:
	"""인접한 아군 유닛 반환"""
	var support_range = range_override if range_override > 0 else data.support_range
	var allies: Array = []

	for unit in all_units:
		if unit == self:
			continue
		if unit.data.is_player == data.is_player:
			var distance = global_position.distance_to(unit.global_position)
			if distance <= support_range:
				allies.append(unit)

	return allies
