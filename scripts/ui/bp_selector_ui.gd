# bp_selector_ui.gd
# BP 부스트 선택 UI
class_name BPSelectorUI
extends Control

signal bp_confirmed(bp_amount: int)
signal cancelled()

@onready var bp_display: HBoxContainer = $Panel/BPDisplay
@onready var info_label: Label = $Panel/InfoLabel
@onready var confirm_button: Button = $Panel/ConfirmButton

var battler: Battler
var skill: SkillData
var selected_bp: int = 0
var max_usable_bp: int = 0


func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)


func show_selector(target_battler: Battler, selected_skill: SkillData) -> void:
	battler = target_battler
	skill = selected_skill
	selected_bp = 0
	max_usable_bp = min(battler.current_bp, 3)  # 최대 3BP까지 사용 가능

	_update_display()
	visible = true
	confirm_button.grab_focus()


func _update_display() -> void:
	# BP 아이콘 업데이트
	for i in range(bp_display.get_child_count()):
		var icon = bp_display.get_child(i)
		if i < battler.current_bp:
			if i < selected_bp:
				icon.modulate = Color.ORANGE  # 사용 예정
			else:
				icon.modulate = Color.YELLOW  # 보유 중
		else:
			icon.modulate = Color.DIM_GRAY  # 없음

	# 효과 미리보기
	var power_text = ""
	var hit_text = ""

	if skill.effect_type == Enums.EffectType.DAMAGE:
		var boosted_power = skill.get_boosted_power(selected_bp)
		var boosted_hits = skill.get_boosted_hit_count(selected_bp)

		if skill.boost_hit_bonus > 0:
			hit_text = "타격: %d회" % boosted_hits
		else:
			var power_percent = int((float(boosted_power) / float(skill.base_power)) * 100)
			power_text = "위력: %d%%" % power_percent

	elif skill.effect_type == Enums.EffectType.HEAL:
		var boost_percent = int((1.0 + skill.boost_power_bonus * selected_bp) * 100)
		power_text = "회복량: %d%%" % boost_percent

	var final_text = "BP 사용: %d" % selected_bp
	if power_text:
		final_text += " | " + power_text
	if hit_text:
		final_text += " | " + hit_text

	info_label.text = final_text


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_right"):
		selected_bp = min(selected_bp + 1, max_usable_bp)
		_update_display()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_left"):
		selected_bp = max(selected_bp - 1, 0)
		_update_display()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		visible = false
		get_viewport().set_input_as_handled()


func _on_confirm_pressed() -> void:
	bp_confirmed.emit(selected_bp)
	visible = false


func hide_selector() -> void:
	visible = false
