# turn_order_ui.gd
# 옥토패스 스타일 턴 순서 표시 UI (상단 중앙)
# 현재 사이클 + 다음 사이클 표시
class_name TurnOrderUI
extends Control

@onready var turn_container: HBoxContainer = $TurnContainer

var turn_manager: TurnManager
var turn_icons: Array = []
var all_battlers: Array = []  # 전체 배틀러 목록 (사이클 계산용)

const ICON_SIZE := Vector2(40, 40)
const CURRENT_ICON_SIZE := Vector2(50, 50)
const NEXT_CYCLE_ICON_SIZE := Vector2(35, 35)


func setup(manager: TurnManager) -> void:
	turn_manager = manager
	turn_manager.turn_order_changed.connect(_on_turn_order_changed)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.round_started.connect(_on_round_started)


func _on_turn_order_changed(order: Array) -> void:
	_rebuild_turn_display_with_next_cycle(order)


func _on_turn_started(_battler: Battler) -> void:
	_highlight_current_turn()


func _on_round_started(_round_number: int) -> void:
	# 라운드 시작 시 배틀러 목록 업데이트
	all_battlers = turn_manager.turn_order.duplicate()


func _rebuild_turn_display_with_next_cycle(current_order: Array) -> void:
	# 기존 아이콘 제거
	for child in turn_container.get_children():
		child.queue_free()
	turn_icons.clear()

	# 현재 사이클 표시 (남은 턴 순서)
	for i in range(current_order.size()):
		var battler = current_order[i]

		# 사망한 배틀러는 표시 안함
		if not battler.is_alive():
			continue

		# 구분선 (현재 턴과 다음 턴 사이)
		if turn_icons.size() == 1:
			var separator = _create_separator()
			turn_container.add_child(separator)

		var is_current = (turn_icons.size() == 0)
		var icon = _create_turn_icon(battler, is_current, false)
		turn_container.add_child(icon)
		turn_icons.append(icon)

	# 다음 사이클 표시 (전체 살아있는 배틀러 기준)
	var all_alive = turn_manager.get_all_alive_battlers()
	if all_alive.size() > 0:
		var next_separator = _create_next_turn_separator()
		turn_container.add_child(next_separator)

		# 다음 사이클 표시 (속도순 재정렬)
		var next_cycle = _get_next_cycle_order(all_alive)
		var next_display_count = min(next_cycle.size(), 6)  # 최대 6개

		for i in range(next_display_count):
			var battler = next_cycle[i]
			var icon = _create_turn_icon(battler, false, true)
			turn_container.add_child(icon)
			turn_icons.append(icon)


func _get_next_cycle_order(alive_battlers: Array) -> Array:
	# 다음 사이클 턴 순서 (속도순 정렬)
	var next_order = alive_battlers.duplicate()
	next_order.sort_custom(func(a, b):
		var speed_a = a.get_stat(Enums.StatType.SPD)
		var speed_b = b.get_stat(Enums.StatType.SPD)
		return speed_a > speed_b
	)
	return next_order


func _create_separator() -> Control:
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 35)
	sep.color = Color(0.5, 0.5, 0.5, 0.6)
	return sep


func _create_next_turn_separator() -> Control:
	# "Next Turn" 텍스트가 있는 구분선
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(60, 45)
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var label = Label.new()
	label.text = "Next"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(label)

	var arrow = Label.new()
	arrow.text = "▶"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 12)
	arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(arrow)

	return container


func _create_turn_icon(battler: Battler, is_current: bool, is_next_cycle: bool) -> Control:
	var container = Control.new()
	var icon_size: Vector2

	if is_current:
		icon_size = CURRENT_ICON_SIZE
	elif is_next_cycle:
		icon_size = NEXT_CYCLE_ICON_SIZE
	else:
		icon_size = ICON_SIZE

	container.custom_minimum_size = icon_size

	# 배경
	var bg = ColorRect.new()
	bg.size = icon_size
	bg.position = Vector2.ZERO

	# 캐릭터 아이콘 (컬러로 구분)
	var icon_color: Color
	if battler.state == Enums.BattlerState.BROKEN:
		icon_color = Color(0.3, 0.3, 0.3, 0.9)  # 브레이크 상태
	elif battler.is_player:
		icon_color = Color(0.2, 0.5, 0.8, 1.0)  # 플레이어 - 파랑
	else:
		icon_color = Color(0.8, 0.3, 0.2, 1.0)  # 적 - 빨강

	# 다음 사이클은 약간 투명하게
	if is_next_cycle:
		icon_color.a = 0.6

	bg.color = icon_color
	container.add_child(bg)

	# 캐릭터 이니셜
	var initial_label = Label.new()
	initial_label.text = battler.data.display_name.left(2)
	initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_label.size = icon_size

	var label_font_size: int
	if is_current:
		label_font_size = 14
	elif is_next_cycle:
		label_font_size = 9
	else:
		label_font_size = 11

	initial_label.add_theme_font_size_override("font_size", label_font_size)
	initial_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(initial_label)

	# 현재 턴 하이라이트 테두리
	if is_current:
		var border = ColorRect.new()
		border.size = icon_size + Vector2(4, 4)
		border.position = Vector2(-2, -2)
		border.color = Color.GOLD
		border.z_index = -1
		container.add_child(border)
		border.move_to_front()
		bg.move_to_front()
		initial_label.move_to_front()

	# 브레이크 상태 표시
	if battler.state == Enums.BattlerState.BROKEN:
		var break_label = Label.new()
		break_label.text = "X"
		break_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		break_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		break_label.size = icon_size
		break_label.add_theme_font_size_override("font_size", 16 if not is_next_cycle else 12)
		break_label.add_theme_color_override("font_color", Color.RED)
		container.add_child(break_label)

	return container


func _highlight_current_turn() -> void:
	if turn_icons.size() > 0:
		var icon = turn_icons[0]
		var tween = create_tween()
		tween.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.15)
		tween.tween_property(icon, "scale", Vector2(1.1, 1.1), 0.1)
