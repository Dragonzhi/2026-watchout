extends Node2D

## 雾里三个静止目标。它们不动；雾在动。
## 累积把动的东西平均掉，不动的东西才浮出来——所以「盯久了会显影」。
## 现在只是占位剪影，后面换成真的船／墩／礁。

const INK := Color(0.58, 0.53, 0.44)


func _draw() -> void:
	# 左：船（船身＋桅帆）
	draw_colored_polygon(PackedVector2Array([
		Vector2(42, 126), Vector2(108, 126), Vector2(98, 140), Vector2(52, 140),
	]), INK)
	draw_rect(Rect2(73, 96, 2, 30), INK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(76, 98), Vector2(76, 124), Vector2(98, 122),
	]), INK)

	# 中：墩台（塔身＋垛口）
	draw_rect(Rect2(151, 100, 18, 34), INK)
	draw_rect(Rect2(147, 92, 26, 8), INK)
	for i in 3:
		draw_rect(Rect2(147 + i * 10, 84, 6, 8), INK)

	# 右：礁石
	draw_colored_polygon(PackedVector2Array([
		Vector2(222, 142), Vector2(227, 130), Vector2(236, 121), Vector2(245, 120),
		Vector2(253, 127), Vector2(258, 136), Vector2(264, 142),
	]), INK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(266, 142), Vector2(272, 134), Vector2(281, 133), Vector2(288, 142),
	]), INK)