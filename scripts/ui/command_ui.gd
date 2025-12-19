# command_ui.gd
# 옥토패스 스타일 커맨드 UI (Boost + Attack/Skills/Defend 통합)
class_name CommandUI
extends Control

signal action_confirmed(skill: SkillData, bp_used: int)
signal cancelled

@onready var boost_container: HBoxContainer = $VBox/BoostContainer
@onready var boost_label: Label = $VBox/BoostContainer/BoostLabel
@onready var boost_indicator: HBoxContainer = $VBox/BoostContainer/BoostIndicator
@onready var command_list: VBoxContainer = $VBox/CommandList
@onready var skill_panel: Panel = $VBox/SkillPanel
@onready var skill_list: VBoxContainer = $VBox/SkillPanel/SkillList
@onready var description_label: Label = $VBox/DescriptionLabel

var battler: Battler
var current_bp_used: int = 0
var max_boost: int = 3  # 최대 부스트 횟수
var selected_skill: SkillData
var command_buttons: Array = []
var skill_buttons: Array = []
var in_skill_menu: bool = false
var boost_icons: Array = []

# 커맨드 목록
enum CommandType { ATTACK, SKILLS, DEFEND }


func _ready() -> void:
	visible = false
	_create_boost_icons()


func _create_boost_icons() -> void:
	# 부스트 아이콘 생성 (최대 3개)
	for i in range(max_boost):
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.color = Color(0.3, 0.3, 0.3)
		boost_indicator.add_child(icon)
		boost_icons.append(icon)


func show_commands(target_battler: Battler) -> void:
	battler = target_battler
	current_bp_used = 0
	in_skill_menu = false
	selected_skill = null

	_build_command_list()
	_update_boost_display()
	skill_panel.visible = false
	visible = true

	if command_buttons.size() > 0:
		await get_tree().process_frame
		command_buttons[0].grab_focus()


func _build_command_list() -> void:
	# 기존 버튼 제거
	for child in command_list.get_children():
		child.queue_free()
	command_buttons.clear()

	# 공격 버튼
	var attack_btn = _create_command_button("공격", CommandType.ATTACK)
	command_list.add_child(attack_btn)
	command_buttons.append(attack_btn)

	# 스킬 버튼
	var skills_btn = _create_command_button("스킬", CommandType.SKILLS)
	command_list.add_child(skills_btn)
	command_buttons.append(skills_btn)

	# 방어 버튼
	var defend_btn = _create_command_button("방어", CommandType.DEFEND)
	command_list.add_child(defend_btn)
	command_buttons.append(defend_btn)


func _create_command_button(text: String, command_type: CommandType) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 35)
	button.pressed.connect(_on_command_pressed.bind(command_type))
	button.focus_entered.connect(_on_command_focused.bind(command_type))
	return button


func _on_command_pressed(command_type: CommandType) -> void:
	match command_type:
		CommandType.ATTACK:
			# 기본 공격 스킬 찾기 또는 첫 번째 공격 스킬
			var attack_skill = _get_basic_attack()
			if attack_skill:
				selected_skill = attack_skill
				action_confirmed.emit(selected_skill, current_bp_used)
				visible = false

		CommandType.SKILLS:
			_show_skill_menu()

		CommandType.DEFEND:
			var defend_skill = _get_defend_skill()
			if defend_skill:
				selected_skill = defend_skill
				action_confirmed.emit(selected_skill, 0)  # 방어는 부스트 없음
				visible = false


func _on_command_focused(command_type: CommandType) -> void:
	match command_type:
		CommandType.ATTACK:
			description_label.text = "적에게 기본 공격 (BP 부스트로 공격력 증가)"
		CommandType.SKILLS:
			description_label.text = "배운 스킬 사용"
		CommandType.DEFEND:
			description_label.text = "방어 자세를 취해 받는 피해 감소, 다음 턴 먼저 행동"


func _get_basic_attack() -> SkillData:
	# 기본 공격 스킬 반환 (첫 번째 스킬로 대체)
	if battler.data.skills.size() > 0:
		return battler.data.skills[0]
	return null


func _get_defend_skill() -> SkillData:
	# 방어 스킬 생성 (없으면 임시 생성)
	var defend = SkillData.new()
	defend.id = "defend"
	defend.display_name = "방어"
	defend.description = "방어 자세"
	defend.sp_cost = 0
	defend.target_type = Enums.TargetType.SELF
	defend.effect_type = Enums.EffectType.BUFF
	return defend


func _show_skill_menu() -> void:
	in_skill_menu = true
	skill_panel.visible = true

	# 기존 스킬 버튼 제거
	for child in skill_list.get_children():
		child.queue_free()
	skill_buttons.clear()

	# 스킬 버튼 생성
	for skill in battler.data.skills:
		var button = Button.new()
		button.text = "%s (SP:%d)" % [skill.display_name, skill.sp_cost]
		button.custom_minimum_size = Vector2(180, 32)

		# SP 부족하면 비활성화
		if battler.current_sp < skill.sp_cost:
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5)

		button.pressed.connect(_on_skill_pressed.bind(skill))
		button.focus_entered.connect(_on_skill_focused.bind(skill))

		skill_list.add_child(button)
		skill_buttons.append(button)

	if skill_buttons.size() > 0:
		await get_tree().process_frame
		skill_buttons[0].grab_focus()


func _on_skill_pressed(skill: SkillData) -> void:
	selected_skill = skill
	action_confirmed.emit(selected_skill, current_bp_used)
	visible = false


func _on_skill_focused(skill: SkillData) -> void:
	description_label.text = skill.description
	if skill.boost_power_bonus > 0:
		description_label.text += " (부스트: 위력+%d%%)" % int(skill.boost_power_bonus * 100)


func _update_boost_display() -> void:
	# 사용 가능한 BP
	var available_bp = battler.current_bp

	# 부스트 레이블 업데이트
	if current_bp_used > 0:
		boost_label.text = "Boost x%d" % current_bp_used
		boost_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		boost_label.text = "Boost [R]"
		boost_label.add_theme_color_override("font_color", Color.WHITE)

	# 부스트 아이콘 업데이트
	for i in range(boost_icons.size()):
		var icon = boost_icons[i]
		if i < current_bp_used:
			icon.color = Color(1.0, 0.6, 0.0)  # 사용 중 (주황)
		elif i < available_bp:
			icon.color = Color(0.4, 0.4, 0.0)  # 사용 가능 (어두운 주황)
		else:
			icon.color = Color(0.25, 0.25, 0.25)  # 사용 불가 (회색)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# R키로 부스트 증가
	if event.is_action_pressed("boost"):
		var available_bp = battler.current_bp
		if current_bp_used < max_boost and current_bp_used < available_bp:
			current_bp_used += 1
			Audio.play_se("select")
			_update_boost_display()
		get_viewport().set_input_as_handled()

	# 취소
	elif event.is_action_pressed("ui_cancel"):
		if in_skill_menu:
			# 스킬 메뉴에서 커맨드로 돌아가기
			in_skill_menu = false
			skill_panel.visible = false
			if command_buttons.size() > 0:
				command_buttons[1].grab_focus()  # 스킬 버튼으로
		else:
			# 부스트 초기화 또는 취소
			if current_bp_used > 0:
				current_bp_used = 0
				Audio.play_se("cancel")
				_update_boost_display()
			else:
				cancelled.emit()
				visible = false
		get_viewport().set_input_as_handled()


func hide_ui() -> void:
	visible = false
