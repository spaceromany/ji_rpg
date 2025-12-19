# sample_data.gd
# 테스트용 샘플 데이터 생성 유틸리티
class_name SampleData
extends RefCounted


static func create_basic_attack() -> SkillData:
	var skill = SkillData.new()
	skill.id = "basic_attack"
	skill.display_name = "기본 공격"
	skill.description = "기본적인 물리 공격"
	skill.sp_cost = 0
	skill.element = Enums.ElementType.SWORD
	skill.target_type = Enums.TargetType.SINGLE_ENEMY
	skill.effect_type = Enums.EffectType.DAMAGE
	skill.base_power = 100
	skill.hit_count = 1
	skill.boost_power_bonus = 0.5
	skill.boost_hit_bonus = 0
	return skill


static func create_double_slash() -> SkillData:
	var skill = SkillData.new()
	skill.id = "double_slash"
	skill.display_name = "이중 베기"
	skill.description = "검으로 2회 연속 공격. BP 사용 시 타격 횟수 증가."
	skill.sp_cost = 4
	skill.element = Enums.ElementType.SWORD
	skill.target_type = Enums.TargetType.SINGLE_ENEMY
	skill.effect_type = Enums.EffectType.DAMAGE
	skill.base_power = 80
	skill.hit_count = 2
	skill.boost_power_bonus = 0.0
	skill.boost_hit_bonus = 1  # BP당 1회 추가 타격
	return skill


static func create_fire_spell() -> SkillData:
	var skill = SkillData.new()
	skill.id = "fire_spell"
	skill.display_name = "파이어"
	skill.description = "적 하나에게 화염 마법 공격"
	skill.sp_cost = 8
	skill.element = Enums.ElementType.FIRE
	skill.target_type = Enums.TargetType.SINGLE_ENEMY
	skill.effect_type = Enums.EffectType.DAMAGE
	skill.base_power = 150
	skill.hit_count = 1
	skill.boost_power_bonus = 0.5
	skill.boost_hit_bonus = 0
	return skill


static func create_heal_spell() -> SkillData:
	var skill = SkillData.new()
	skill.id = "heal"
	skill.display_name = "힐"
	skill.description = "아군 한 명의 HP를 회복"
	skill.sp_cost = 6
	skill.element = Enums.ElementType.LIGHT
	skill.target_type = Enums.TargetType.SINGLE_ALLY
	skill.effect_type = Enums.EffectType.HEAL
	skill.base_power = 120
	skill.hit_count = 1
	skill.boost_power_bonus = 0.5
	skill.boost_hit_bonus = 0
	return skill


static func create_attack_buff() -> SkillData:
	var skill = SkillData.new()
	skill.id = "attack_up"
	skill.display_name = "공격력 강화"
	skill.description = "아군 한 명의 공격력 30% 증가 (3턴)"
	skill.sp_cost = 4
	skill.element = Enums.ElementType.LIGHT
	skill.target_type = Enums.TargetType.SINGLE_ALLY
	skill.effect_type = Enums.EffectType.BUFF
	skill.stat_type = Enums.StatType.ATK
	skill.stat_modifier = 0.3
	skill.duration = 3
	return skill


static func create_warrior() -> BattlerData:
	var data = BattlerData.new()
	data.id = "warrior"
	data.display_name = "전사"
	data.max_hp = 150
	data.max_sp = 40
	data.atk = 20
	data.def = 15
	data.matk = 5
	data.mdef = 10
	data.spd = 12
	data.crit_rate = 0.1
	data.weapon_elements = [Enums.ElementType.SWORD, Enums.ElementType.AXE]
	data.skills = [
		create_basic_attack(),
		create_double_slash()
	]
	return data


static func create_mage() -> BattlerData:
	var data = BattlerData.new()
	data.id = "mage"
	data.display_name = "마법사"
	data.max_hp = 80
	data.max_sp = 100
	data.atk = 5
	data.def = 8
	data.matk = 25
	data.mdef = 15
	data.spd = 10
	data.crit_rate = 0.05
	data.weapon_elements = [Enums.ElementType.STAFF]
	data.skills = [
		create_basic_attack(),
		create_fire_spell(),
		create_heal_spell()
	]
	return data


static func create_goblin() -> BattlerData:
	var data = BattlerData.new()
	data.id = "goblin"
	data.display_name = "고블린"
	data.max_hp = 60
	data.max_sp = 20
	data.atk = 12
	data.def = 8
	data.matk = 3
	data.mdef = 5
	data.spd = 14
	data.crit_rate = 0.05
	data.max_shield = 2
	data.weaknesses = [
		Enums.ElementType.SWORD,
		Enums.ElementType.FIRE
	]
	data.skills = [create_basic_attack()]
	return data


static func create_boss_orc() -> BattlerData:
	var data = BattlerData.new()
	data.id = "orc_boss"
	data.display_name = "오크 대장"
	data.max_hp = 300
	data.max_sp = 50
	data.atk = 25
	data.def = 20
	data.matk = 5
	data.mdef = 15
	data.spd = 8
	data.crit_rate = 0.15
	data.max_shield = 5
	data.weaknesses = [
		Enums.ElementType.SPEAR,
		Enums.ElementType.ICE,
		Enums.ElementType.LIGHT
	]
	data.skills = [create_basic_attack()]
	return data
