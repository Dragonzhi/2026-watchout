extends Node2D

## 中景：石滩。压成一条过渡带，坐在海面与女墙之间。
##
## 挂在 NearLayer 里、在 Display 之上——它离得近，雾该薄；也因为它在动，
## 一动就会在累积里拖影，所以干脆不进累积。
##
## 它是「陆」，所以压成灰褐、比水暗：水反射天，陆不反射。
## 早先按中性灰画，结果和海面同值，读起来像海断成了两截。
## 上沿一道浪线，下沿被女墙压住，不画收边。
##
## 坐标按 320×180 画；控制器给 top_y 与 height，并按视差系数推 drift。

const W := 320.0
const BLEED := 16.0

const FOAM := Color(0.352, 0.364, 0.380)
const FOAM_LOW := Color(0.198, 0.204, 0.214)
const SAND := Color(0.152, 0.144, 0.126)
const SAND_HI := Color(0.204, 0.194, 0.170)
const SAND_LO := Color(0.100, 0.092, 0.078)

## 过渡带上沿在 320×180 里的 y，由控制器按 mid_ratio 算。
var top_y := 108.0

## 过渡带高度，同样由控制器算。
var height := 21.6

## 视差位移；石滩系数 0.55，比海快、比墙慢。
var drift := Vector2.ZERO:
	set(value):
		if drift.is_equal_approx(value):
			return
		drift = value
		queue_redraw()


func _draw() -> void:
	var ox := drift.x
	var oy := drift.y
	var n := 64
	var step := (W + BLEED * 2.0) / float(n)

	# 岸线不是一条整齐的带子：每处有自己的进深，中间留几道内湾。
	# 整条等高、下沿又正好压在垛口顶上，看起来就像搁板——水看得出从缺口里穿过去，
	# 岸才不是架在墙上的。
	for i in n:
		var x0 := -BLEED + step * float(i)
		var x1 := x0 + step
		var y0 := top_y + _edge(x0)
		var y1 := top_y + _edge(x1)
		var h0 := height * _depth(x0)
		var h1 := height * _depth(x1)
		var a := Vector2(x0 + ox, y0 + oy)
		var b := Vector2(x1 + ox, y1 + oy)
		if h0 > 0.6 or h1 > 0.6:
			draw_colored_polygon(PackedVector2Array([
				a, b, Vector2(x1 + ox, y1 + h1 + oy), Vector2(x0 + ox, y0 + h0 + oy),
			]), SAND)
			if h0 > 3.0 and h1 > 3.0:
				draw_colored_polygon(PackedVector2Array([
					a, b, b + Vector2(0.0, 2.4), a + Vector2(0.0, 2.4),
				]), SAND_HI)
		# 浪线跟岸走，不跟带子走：内湾处只剩这一道白
		if (i % 13) >= 3:
			draw_colored_polygon(PackedVector2Array([
				a, b, b + Vector2(0.0, 1.6), a + Vector2(0.0, 1.6),
			]), FOAM)
		draw_colored_polygon(PackedVector2Array([
			a + Vector2(0.0, 1.6), b + Vector2(0.0, 1.6),
			b + Vector2(0.0, 2.4), a + Vector2(0.0, 2.4),
		]), FOAM_LOW)

	# 露出水面的几块石背。只画在岸够厚的地方——
	# 不判进深的话，内湾里会浮着几根没有来处的暗条。
	_patch(18.0, 7.0, 30.0, 2.8, SAND_HI, ox, oy)
	_patch(131.0, 10.0, 21.0, 2.4, SAND_HI, ox, oy)
	_patch(243.0, 6.0, 34.0, 2.8, SAND_HI, ox, oy)
	_patch(76.0, 13.0, 42.0, 2.6, SAND_LO, ox, oy)
	_patch(196.0, 14.0, 26.0, 2.2, SAND_LO, ox, oy)


func _patch(x: float, y: float, w: float, h: float, col: Color, ox: float, oy: float) -> void:
	# 岸的进深必须真的盖住这块石头，否则它会浮在水上
	if height * _depth(x + w * 0.5) < y + h + 2.0:
		return
	draw_rect(Rect2(x + ox, top_y + y + oy, w, h), col)


func _depth(x: float) -> float:
	# 每处岸的进深：0 是只有一道浪线的内湾，1 是整条带子。
	return clampf(0.58 + 0.34 * sin(x * 0.021 + 0.7) + 0.26 * sin(x * 0.059 + 2.1), 0.0, 1.0)


func _edge(x: float) -> float:
	return sin(x * 0.037) * 1.6 + sin(x * 0.093 + 1.3) * 0.9 + sin(x * 0.211) * 0.35