# skill_menu_ui.gd
# 스킬 선택 메뉴 UI
class_name SkillMenuUI
extends Control

signal skill_selected(skill: SkillData)
signal cancelled()

@onready var skill_list: VBoxContainer = $Panel/ScrollContainer/SkillList
@onready var description_label: Label = $Panel/DescriptionLabel
@onready var sp_cost_label: Label = $Panel/SPCostLabel

var battler: Battler
var skill_buttons: Array = []
var selected_index: int = 0


func _ready() -> void:
	visible = false


func show_skills(target_battler: Battler) -> void:
	print("[SkillMenuUI] show_skills called for: ", target_battler.data.display_name)
	battler = target_battler
	_build_skill_list()
	visible = true
	print("[SkillMenuUI] visible = ", visible, ", skill count = ", battler.data.skills.size())

	if skill_buttons.size() > 0:
		skill_buttons[0].grab_focus()


func _build_skill_list() -> void:
	# 기존 버튼 제거
	for child in skill_list.get_children():
		child.queue_free()
	skill_buttons.clear()

	# 스킬 버튼 생성
	for skill in battler.data.skills:
		var button = Button.new()
		button.text = skill.display_name + " (SP: %d)" % skill.sp_cost
		button.custom_minimum_size = Vector2(250, 40)

		# SP 부족하면 비활성화
		if battler.current_sp < skill.sp_cost:
			button.disabled = true
			button.modulate = Color.DIM_GRAY

		button.pressed.connect(_on_skill_pressed.bind(skill))
		button.focus_entered.connect(_on_skill_focused.bind(skill))
		button.mouse_entered.connect(_on_skill_focused.bind(skill))

		skill_list.add_child(button)
		skill_buttons.append(button)

	print("[SkillMenuUI] Created ", skill_buttons.size(), " skill buttons")


func _on_skill_pressed(skill: SkillData) -> void:
	print("[SkillMenuUI] Skill pressed: ", skill.display_name)
	skill_selected.emit(skill)
	visible = false


func _on_skill_focused(skill: SkillData) -> void:
	description_label.text = skill.description
	sp_cost_label.text = "SP: %d" % skill.sp_cost


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		visible = false
		get_viewport().set_input_as_handled()


func hide_menu() -> void:
	visible = false
