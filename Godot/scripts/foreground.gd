extends Node2D

## 近景剪影。挂在根上的 NearLayer 里（Display 之上、注视点之下）——
## 它在你眼前，所以不该被雾吃，也不进累积。
##
## 作用：压掉三个目标的下座，让轮廓不完整。
## 形态是一段低伏的石台 + 几块圆石：石台顶面几乎是平的，圆石是半椭圆，
## 这样读起来是「岸」，不是「山脉」。坐标按 320×180 画，控制器按窗口缩放。

const NEAR := Color(0.050, 0.053, 0.060)
const NEAR_HI := Color(0.098, 0.104, 0.115)

# 石台：几乎平的一条线，只有 1–2 px 的起伏
const LEDGE := [
	Vector2(0, 153), Vector2(18, 152), Vector2(34, 154), Vector2(50, 152),
	Vector2(66, 153), Vector2(84, 151), Vector2(102, 153), Vector2(120, 152),
	Vector2(138, 153), Vector2(156, 151), Vector2(174, 153), Vector2(192, 152),
	Vector2(210, 154), Vector2(228, 152), Vector2(246, 153), Vector2(264, 151),
	Vector2(282, 153), Vector2(300, 152), Vector2(320, 153),
]

# 圆石：(中心 x, 底边 y, 宽, 高)。各自挡在一个目标的下座前面。
const BOULDERS := [
	[30.0, 153.0, 24.0, 6.0],
	[72.0, 152.0, 38.0, 9.0],
	[104.0, 152.0, 15.0, 4.0],
	[148.0, 152.0, 21.0, 5.0],
	[168.0, 152.0, 36.0, 10.0],
	[202.0, 152.0, 17.0, 4.5],
	[236.0, 153.0, 24.0, 6.5],
	[257.0, 153.0, 34.0, 9.0],
	[292.0, 153.0, 22.0, 5.5],
	[312.0, 153.0, 13.0, 3.5],
]


func _draw() -> void:
	# 石台先铺满底部
	for i in LEDGE.size() - 1:
		var a: Vector2 = LEDGE[i]
		var b: Vector2 = LEDGE[i + 1]
		draw_colored_polygon(PackedVector2Array([
			a, b, Vector2(b.x, 180.0), Vector2(a.x, 180.0),
		]), NEAR)

	# 圆石：半椭圆，压在同一层里，轮廓连成一片
	for rock in BOULDERS:
		var cx: float = rock[0]
		var by: float = rock[1]
		var w: float = rock[2]
		var h: float = rock[3]
		draw_colored_polygon(_dome(cx, by, w, h), NEAR)
		# 受光面：同一块石头左上方的一小片，别做成蘑菇帽
		draw_colored_polygon(_dome(cx - w * 0.20, by - 0.5, w * 0.34, h * 0.45), NEAR_HI)


func _dome(cx: float, by: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := 8
	for i in segments + 1:
		var angle := PI - PI * float(i) / float(segments)
		pts.append(Vector2(cx + cos(angle) * w * 0.5, by - sin(angle) * h))
	return pts