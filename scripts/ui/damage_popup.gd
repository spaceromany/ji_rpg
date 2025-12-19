# damage_popup.gd
# 데미지 팝업 UI
class_name DamagePopup
extends Control

@onready var label: Label = $Label

var velocity: Vector2 = Vector2(0, -100)
var lifetime: float = 1.0


func _ready() -> void:
	# 페이드 아웃 애니메이션
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	position += velocity * delta
	velocity.y += 200 * delta  # 중력


func setup_damage(amount: int, is_critical: bool = false, is_weakness: bool = false) -> void:
	label.text = str(amount)

	# 크리티컬/약점에 따른 색상
	if is_critical:
		label.modulate = Color.YELLOW
		label.add_theme_font_size_override("font_size", 32)
		label.text += "!"
	elif is_weakness:
		label.modulate = Color.ORANGE
	else:
		label.modulate = Color.WHITE


func setup_heal(amount: int) -> void:
	label.text = "+" + str(amount)
	label.modulate = Color.GREEN


func setup_text(text: String, color: Color = Color.WHITE) -> void:
	label.text = text
	label.modulate = color


static func create_damage(parent: Node, pos: Vector2, amount: int, is_critical: bool = false, is_weakness: bool = false) -> DamagePopup:
	var popup = preload("res://scenes/ui/damage_popup.tscn").instantiate()
	popup.position = pos
	parent.add_child(popup)
	popup.setup_damage(amount, is_critical, is_weakness)
	return popup


static func create_heal(parent: Node, pos: Vector2, amount: int) -> DamagePopup:
	var popup = preload("res://scenes/ui/damage_popup.tscn").instantiate()
	popup.position = pos
	parent.add_child(popup)
	popup.setup_heal(amount)
	return popup


static func create_break(parent: Node, pos: Vector2) -> DamagePopup:
	var popup = preload("res://scenes/ui/damage_popup.tscn").instantiate()
	popup.position = pos
	parent.add_child(popup)
	popup.setup_text("BREAK!", Color.RED)
	popup.label.add_theme_font_size_override("font_size", 36)
	return popup
