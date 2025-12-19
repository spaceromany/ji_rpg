# battler_status_ui.gd
# 옥토패스 스타일 아군 상태 표시 UI (우측 HP/SP/BP 표시)
class_name BattlerStatusUI
extends Control

@onready var name_label: Label = $VBox/NameLabel
@onready var hp_bar: ProgressBar = $VBox/HPContainer/HPBar
@onready var hp_label: Label = $VBox/HPContainer/HPLabel
@onready var sp_bar: ProgressBar = $VBox/SPContainer/SPBar
@onready var sp_label: Label = $VBox/SPContainer/SPLabel
@onready var bp_container: HBoxContainer = $VBox/BPContainer

var battler: Battler
var bp_icons: Array = []


func _ready() -> void:
	# BP 아이콘 생성 (5개)
	_create_bp_icons()


func _create_bp_icons() -> void:
	for i in range(5):
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.color = Color(0.3, 0.3, 0.3)
		bp_container.add_child(icon)
		bp_icons.append(icon)


func setup(target_battler: Battler) -> void:
	battler = target_battler

	# 시그널 연결
	battler.hp_changed.connect(_on_hp_changed)
	battler.sp_changed.connect(_on_sp_changed)
	battler.bp_changed.connect(_on_bp_changed)
	battler.state_changed.connect(_on_state_changed)

	# 초기값 설정
	name_label.text = battler.data.display_name
	_update_hp(battler.current_hp, battler.data.max_hp)
	_update_sp(battler.current_sp, battler.data.max_sp)
	_update_bp(battler.current_bp)


func _update_hp(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
	hp_label.text = "%d / %d" % [current, max_hp]

	# HP 비율에 따른 색상 변경
	var ratio = float(current) / float(max_hp)
	if ratio <= 0.25:
		hp_bar.modulate = Color.RED
	elif ratio <= 0.5:
		hp_bar.modulate = Color.ORANGE
	else:
		hp_bar.modulate = Color(0.2, 0.8, 0.2)  # 초록


func _update_sp(current: int, max_sp: int) -> void:
	sp_bar.max_value = max_sp
	sp_bar.value = current
	sp_label.text = "%d / %d" % [current, max_sp]


func _update_bp(current: int) -> void:
	# BP 아이콘 업데이트
	for i in range(bp_icons.size()):
		var icon = bp_icons[i]
		if i < current:
			icon.color = Color(1.0, 0.6, 0.0)  # 주황색 (활성)
		else:
			icon.color = Color(0.25, 0.25, 0.25)  # 어두운 회색 (비활성)


func _on_hp_changed(current: int, max_hp: int) -> void:
	_update_hp(current, max_hp)


func _on_sp_changed(current: int, max_sp: int) -> void:
	_update_sp(current, max_sp)


func _on_bp_changed(current: int) -> void:
	_update_bp(current)


func _on_state_changed(new_state: Enums.BattlerState) -> void:
	match new_state:
		Enums.BattlerState.BROKEN:
			modulate = Color(1.0, 0.6, 0.6)
		Enums.BattlerState.DEAD:
			modulate = Color(0.4, 0.4, 0.4)
		_:
			modulate = Color.WHITE


func highlight(enabled: bool) -> void:
	if enabled:
		modulate = Color(1.2, 1.2, 1.0)
	else:
		modulate = Color.WHITE
