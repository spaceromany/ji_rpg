# enemy_status_ui.gd
# 옥토패스 스타일 적 상태 표시 UI (좌측 하단, 실드/약점)
class_name EnemyStatusUI
extends Control

@onready var name_label: Label = $VBox/NameLabel
@onready var shield_label: Label = $VBox/ShieldRow/ShieldLabel
@onready var weakness_container: HBoxContainer = $VBox/WeaknessContainer
@onready var break_label: Label = $VBox/BreakLabel

var battler: Battler
var weakness_icons: Array = []

# 속성별 약자 매핑
const ELEMENT_SHORT: Dictionary = {
	Enums.ElementType.SWORD: "검",
	Enums.ElementType.SPEAR: "창",
	Enums.ElementType.DAGGER: "단",
	Enums.ElementType.AXE: "도",
	Enums.ElementType.BOW: "궁",
	Enums.ElementType.STAFF: "장",
	Enums.ElementType.FIRE: "화",
	Enums.ElementType.ICE: "빙",
	Enums.ElementType.THUNDER: "뇌",
	Enums.ElementType.WIND: "풍",
	Enums.ElementType.LIGHT: "광",
	Enums.ElementType.DARK: "암"
}

# 속성별 색상
const ELEMENT_COLORS: Dictionary = {
	Enums.ElementType.SWORD: Color(0.7, 0.7, 0.7),
	Enums.ElementType.SPEAR: Color(0.6, 0.6, 0.8),
	Enums.ElementType.DAGGER: Color(0.5, 0.5, 0.6),
	Enums.ElementType.AXE: Color(0.6, 0.4, 0.3),
	Enums.ElementType.BOW: Color(0.4, 0.6, 0.3),
	Enums.ElementType.STAFF: Color(0.6, 0.4, 0.6),
	Enums.ElementType.FIRE: Color(1.0, 0.4, 0.2),
	Enums.ElementType.ICE: Color(0.4, 0.8, 1.0),
	Enums.ElementType.THUNDER: Color(1.0, 1.0, 0.3),
	Enums.ElementType.WIND: Color(0.5, 0.9, 0.5),
	Enums.ElementType.LIGHT: Color(1.0, 1.0, 0.8),
	Enums.ElementType.DARK: Color(0.5, 0.3, 0.6)
}


func setup(target_battler: Battler) -> void:
	battler = target_battler

	# 시그널 연결
	battler.shield_changed.connect(_on_shield_changed)
	battler.state_changed.connect(_on_state_changed)

	# 초기값 설정
	name_label.text = battler.data.display_name
	_update_shield(battler.current_shield)
	_setup_weaknesses()
	break_label.visible = false


func _update_shield(current: int) -> void:
	shield_label.text = str(current)

	# 실드가 낮으면 색상 변경
	if current <= 1:
		shield_label.add_theme_color_override("font_color", Color.RED)
	elif current <= 2:
		shield_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		shield_label.add_theme_color_override("font_color", Color.CYAN)


func _setup_weaknesses() -> void:
	# 기존 약점 아이콘 제거
	for child in weakness_container.get_children():
		child.queue_free()
	weakness_icons.clear()

	# 약점 아이콘 생성
	for weakness in battler.data.weaknesses:
		var icon_container = PanelContainer.new()
		icon_container.custom_minimum_size = Vector2(28, 28)

		var icon_label = Label.new()
		icon_label.text = ELEMENT_SHORT.get(weakness, "?")
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 12)

		var color = ELEMENT_COLORS.get(weakness, Color.WHITE)
		icon_label.add_theme_color_override("font_color", color)

		icon_container.add_child(icon_label)
		weakness_container.add_child(icon_container)
		weakness_icons.append({"container": icon_container, "element": weakness, "revealed": true})


func _on_shield_changed(current: int, _max_shield: int) -> void:
	_update_shield(current)


func _on_state_changed(new_state: Enums.BattlerState) -> void:
	match new_state:
		Enums.BattlerState.BROKEN:
			break_label.visible = true
			break_label.text = "BREAK!"
			modulate = Color(1.0, 0.5, 0.5)

			# 브레이크 연출
			var tween = create_tween()
			tween.tween_property(break_label, "scale", Vector2(1.3, 1.3), 0.1)
			tween.tween_property(break_label, "scale", Vector2(1.0, 1.0), 0.15)

		Enums.BattlerState.DEAD:
			modulate = Color(0.4, 0.4, 0.4)
			break_label.visible = false

		Enums.BattlerState.IDLE:
			break_label.visible = false
			modulate = Color.WHITE


func highlight(enabled: bool) -> void:
	if enabled:
		modulate = Color(1.3, 1.3, 1.0)
	else:
		if battler and battler.state == Enums.BattlerState.BROKEN:
			modulate = Color(1.0, 0.5, 0.5)
		else:
			modulate = Color.WHITE
