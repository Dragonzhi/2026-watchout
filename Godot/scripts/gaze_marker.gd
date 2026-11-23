extends Node2D

## 注视点指示。挂在 CanvasLayer 下，按屏幕坐标画。
## 只做原型期的可见性提示，不算正式 UI。

const RING_COLOR := Color(1.0, 0.94, 0.84, 0.26)
const DOT_COLOR := Color(1.0, 0.94, 0.84, 0.45)
const RADIUS := 24.0

var aim := Vector2(0.5, 0.5)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p := aim * get_viewport().get_visible_rect().size
	draw_arc(p, RADIUS, 0.0, TAU, 48, RING_COLOR, 1.4, true)
	draw_circle(p, 1.6, DOT_COLOR)
	for i in 4:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 4.0)
		draw_line(p + dir * (RADIUS + 4.0), p + dir * (RADIUS + 9.0), RING_COLOR, 1.0, true)
