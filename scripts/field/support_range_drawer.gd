# support_range_drawer.gd
# 지원 범위 원을 그리는 노드
extends Node2D

var parent_unit: Node2D = null


func setup(unit: Node2D) -> void:
	parent_unit = unit


func _draw() -> void:
	if not parent_unit or not parent_unit.data:
		return

	var support_range = parent_unit.data.support_range
	var is_player = parent_unit.data.is_player

	# 플레이어는 파란색, 적은 빨간색 (반투명)
	var circle_color: Color
	if is_player:
		circle_color = Color(0.3, 0.5, 1.0, 0.15)  # 파란색 반투명
	else:
		circle_color = Color(1.0, 0.3, 0.3, 0.15)  # 빨간색 반투명

	# 채워진 원
	draw_circle(Vector2.ZERO, support_range, circle_color)

	# 테두리
	var border_color = circle_color
	border_color.a = 0.4
	_draw_circle_outline(Vector2.ZERO, support_range, border_color, 2.0)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points = 64
	var prev_point = center + Vector2(radius, 0)

	for i in range(1, points + 1):
		var angle = TAU * i / points
		var next_point = center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(prev_point, next_point, color, width)
		prev_point = next_point


func _process(_delta: float) -> void:
	# 원을 다시 그리기 (유닛이 움직일 때)
	queue_redraw()
