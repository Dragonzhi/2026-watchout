extends Node2D

## 近景剪影。挂在根上的 NearLayer 里（Display 之上、注视点之下）——
## 它在你眼前，所以不该被雾吃，也不进累积。
## 它压掉三个目标的下半截：轮廓不完整，才认不出是什么。
## 坐标按 320×180 画，控制器按窗口尺寸整体缩放，保持像素颗粒。

const NEAR := Color(0.055, 0.058, 0.066)
const NEAR_HI := Color(0.105, 0.110, 0.122)

# 岸线的上缘：(x, y)。故意在三样东西的底座前面各自抬起一块。
const TOP := [
	Vector2(0, 156), Vector2(10, 151), Vector2(19, 155), Vector2(28, 150),
	Vector2(36, 154), Vector2(45, 149), Vector2(53, 152), Vector2(62, 147),
	Vector2(70, 151), Vector2(78, 145), Vector2(86, 150), Vector2(95, 146),
	Vector2(103, 140), Vector2(110, 149), Vector2(117, 145), Vector2(124, 152),
	Vector2(132, 147), Vector2(140, 153), Vector2(148, 148), Vector2(155, 137),
	Vector2(161, 134), Vector2(168, 143), Vector2(175, 139), Vector2(182, 148),
	Vector2(190, 152), Vector2(198, 147), Vector2(206, 153), Vector2(214, 149),
	Vector2(222, 155), Vector2(230, 150), Vector2(238, 142), Vector2(245, 134),
	Vector2(252, 140), Vector2(259, 145), Vector2(266, 152), Vector2(274, 148),
	Vector2(282, 154), Vector2(290, 150), Vector2(298, 155), Vector2(306, 151),
	Vector2(313, 156), Vector2(320, 152),
]


func _draw() -> void:
	# 凹多边形不能一次画出来（draw_colored_polygon 只可靠地吃凸形），
	# 所以按列拆成一串四边形，每块都是凸的。
	for i in TOP.size() - 1:
		var a: Vector2 = TOP[i]
		var b: Vector2 = TOP[i + 1]
		draw_colored_polygon(PackedVector2Array([
			a, b, Vector2(b.x, 180.0), Vector2(a.x, 180.0),
		]), NEAR)

	# 顶缘几片受光的碎岩，给近景一点体积，免得看着像一条黑边
	_stone(Vector2(62, 147), Vector2(70, 151), Vector2(78, 145), Vector2(70, 143))
	_stone(Vector2(148, 148), Vector2(155, 137), Vector2(161, 134), Vector2(158, 146))
	_stone(Vector2(238, 142), Vector2(245, 134), Vector2(252, 140), Vector2(246, 147))
	_stone(Vector2(298, 155), Vector2(306, 151), Vector2(313, 156), Vector2(305, 158))


func _stone(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), NEAR_HI)