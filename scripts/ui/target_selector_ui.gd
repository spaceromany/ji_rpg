# target_selector_ui.gd
# 대상 선택 UI
class_name TargetSelectorUI
extends Control

signal target_selected(targets: Array)
signal cancelled
signal selection_changed(target: Battler)  # 선택 커서 이동 시

@onready var target_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TargetList
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel

var valid_targets: Array = []
var selected_index: int = 0
var is_multi_target: bool = false
var target_buttons: Array = []


func _ready() -> void:
	visible = false


func show_targets(targets: Array, skill_name: String, multi_target: bool = false) -> void:
	valid_targets = targets
	is_multi_target = multi_target
	selected_index = 0

	# 제목 설정
	if multi_target:
		title_label.text = "%s - 전체 대상" % skill_name
	else:
		title_label.text = "%s - 대상 선택" % skill_name

	# 기존 버튼 제거
	for child in target_list.get_children():
		child.queue_free()
	target_buttons.clear()

	# 전체 대상인 경우
	if multi_target:
		var all_button = Button.new()
		all_button.text = "전체 (%d명)" % targets.size()
		all_button.custom_minimum_size = Vector2(200, 40)
		all_button.pressed.connect(_on_all_selected)
		target_list.add_child(all_button)
		target_buttons.append(all_button)
	else:
		# 개별 대상 버튼 생성
		for i in range(targets.size()):
			var target: Battler = targets[i]
			var button = Button.new()
			button.text = _get_target_display_text(target)
			button.custom_minimum_size = Vector2(200, 40)
			button.pressed.connect(_on_target_pressed.bind(i))
			target_list.add_child(button)
			target_buttons.append(button)

	visible = true
	_update_selection()

	# 첫 번째 버튼에 포커스
	await get_tree().process_frame
	if target_buttons.size() > 0:
		target_buttons[0].grab_focus()


func _get_target_display_text(target: Battler) -> String:
	var text = target.data.display_name

	# HP 정보 추가
	var hp_percent = int(float(target.current_hp) / float(target.data.max_hp) * 100)
	text += " (HP: %d%%)" % hp_percent

	# 브레이크 상태 표시
	if target.state == Enums.BattlerState.BROKEN:
		text += " [BREAK]"

	return text


func hide_selector() -> void:
	visible = false


func _update_selection() -> void:
	for i in range(target_buttons.size()):
		var button: Button = target_buttons[i]
		if i == selected_index:
			button.add_theme_color_override("font_color", Color.YELLOW)
		else:
			button.remove_theme_color_override("font_color")

	# 선택 변경 시그널 발생 (전체 대상이 아닌 경우만)
	if not is_multi_target and selected_index < valid_targets.size():
		selection_changed.emit(valid_targets[selected_index])


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_up"):
		selected_index = (selected_index - 1 + target_buttons.size()) % target_buttons.size()
		_update_selection()
		if target_buttons.size() > 0:
			target_buttons[selected_index].grab_focus()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down"):
		selected_index = (selected_index + 1) % target_buttons.size()
		_update_selection()
		if target_buttons.size() > 0:
			target_buttons[selected_index].grab_focus()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		hide_selector()
		cancelled.emit()
		get_viewport().set_input_as_handled()


func _confirm_selection() -> void:
	if is_multi_target:
		target_selected.emit(valid_targets)
	else:
		if selected_index < valid_targets.size():
			target_selected.emit([valid_targets[selected_index]])
	hide_selector()


func _on_target_pressed(index: int) -> void:
	selected_index = index
	_confirm_selection()


func _on_all_selected() -> void:
	target_selected.emit(valid_targets)
	hide_selector()
