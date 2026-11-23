extends Node2D

## 雾里三个静止目标。它们不动；雾在动。
## 累积把动的东西平均掉，不动的东西才浮出来——所以「盯久了会显影」。
## 现在只是占位剪影，后面换成真的船／墩／礁。
##
## 轮廓刻意做碎：桅索、栏杆、砌石、碎礁。同样的低对比下，
## 边缘越多越难认出「是什么」；再加一圈 1px 的暗边，当距离羽化用。

const INK := Color(0.185, 0.170, 0.140)
const SHADE := Color(0.105, 0.098, 0.082)
const RIM := Color(0.052, 0.048, 0.042)
const FAR := 0.88   # 礁石更远一档，整体压暗


func _draw() -> void:
	_draw_boat()
	_draw_tower()
	_draw_reef()


func _draw_boat() -> void:
	# 船身：船底被近景压掉，留下的是一条斜的船舷和帆。
	var hull := PackedVector2Array([
		Vector2(44, 128), Vector2(106, 128), Vector2(99, 142), Vector2(52, 142),
	])
	_poly(hull, INK)
	_poly(PackedVector2Array([
		Vector2(52, 136), Vector2(99, 136), Vector2(96, 142), Vector2(55, 142),
	]), SHADE)
	# 艉柱
	_rect(Rect2(101, 116, 3, 13), INK)
	# 桅与帆
	_rect(Rect2(72, 96, 2, 33), INK)
	_poly(PackedVector2Array([
		Vector2(75, 99), Vector2(75, 125), Vector2(96, 122),
	]), INK)
	_poly(PackedVector2Array([
		Vector2(75, 114), Vector2(75, 125), Vector2(96, 122), Vector2(86, 116),
	]), SHADE)
	# 桅索：两根线，把船的形状拉散
	_rect(Rect2(74, 100, 1, 27), SHADE)
	_rect(Rect2(84, 108, 26, 1), SHADE)
	# 桅顶三角旗
	_poly(PackedVector2Array([
		Vector2(74, 96), Vector2(84, 98), Vector2(74, 100),
	]), SHADE)


func _draw_tower() -> void:
	# 塔身
	_rect(Rect2(150, 104, 20, 44), INK)
	_rect(Rect2(150, 104, 5, 44), SHADE)
	# 平台
	_rect(Rect2(146, 98, 28, 7), INK)
	_rect(Rect2(146, 98, 6, 7), SHADE)
	# 垛口
	for i in 3:
		_rect(Rect2(146 + i * 10, 90, 6, 9), INK)
		_rect(Rect2(146 + i * 10, 90, 2, 9), SHADE)
	# 砌石错缝：两处缺口，让塔身不是一块砖
	_rect(Rect2(160, 112, 7, 2), SHADE)
	_rect(Rect2(153, 124, 6, 2), SHADE)
	_rect(Rect2(161, 136, 6, 2), SHADE)
	# 外侧挑出一根瞭望横木
	_rect(Rect2(170, 110, 12, 2), SHADE)
	_rect(Rect2(180, 110, 2, 5), SHADE)


func _draw_reef() -> void:
	var reef := Color(INK.r, INK.g, INK.b).darkened(1.0 - FAR)
	var reef_shade := Color(SHADE.r, SHADE.g, SHADE.b).darkened(1.0 - FAR)
	# 主礁
	_poly(PackedVector2Array([
		Vector2(220, 150), Vector2(226, 137), Vector2(234, 127), Vector2(244, 123),
		Vector2(252, 129), Vector2(258, 138), Vector2(264, 150),
	]), reef)
	# 旁边一块矮的
	_poly(PackedVector2Array([
		Vector2(266, 150), Vector2(272, 140), Vector2(281, 139), Vector2(288, 150),
	]), reef_shade)
	# 立着的一块尖岩，把轮廓打散
	_poly(PackedVector2Array([
		Vector2(238, 123), Vector2(241, 113), Vector2(246, 116), Vector2(245, 125),
	]), reef_shade)


func _poly(pts: PackedVector2Array, fill: Color) -> void:
	# 先在外圈铺一层更暗的边（羽化），再填主体
	var center := Vector2.ZERO
	for p in pts:
		center += p
	center /= float(pts.size())
	var grown := PackedVector2Array()
	for p in pts:
		grown.append(p + (p - center).normalized() * 1.2)
	draw_colored_polygon(grown, RIM)
	draw_colored_polygon(pts, fill)


func _rect(r: Rect2, fill: Color) -> void:
	draw_rect(Rect2(r.position - Vector2(1.2, 1.2), r.size + Vector2(2.4, 2.4)), RIM)
	draw_rect(r, fill)