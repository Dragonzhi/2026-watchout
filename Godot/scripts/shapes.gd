extends Node2D

## 远景：天与海。画在 SceneView 里，所以它会被雾吃、也会被累积——
## 「盯久了才看得清」说的是这一层。近景两层不在这儿，它们在 Display 之上。
##
## 三件事决定这层像不像海，不是颜色：
##   渐变按 1px 一行画——大块的色带在 320×180 上会读成扫描线；
##   涌线的间距越往下越宽（透视），海才有进深，否则是一块灰板；
##   近水里有碎光，而且必须落在垛口能看见的那一条里（y 130–145），
##   「海的光」是从那儿透进前景的，不是一团平均亮。
##
## 所有坐标按 320×180 画；控制器按内部分辨率缩放本节点，并按视差系数推 drift。

const W := 320.0
const H := 180.0
const BLEED := 16.0
const HORIZON_Y := 72.0

const SKY_HIGH := Color(0.520, 0.548, 0.592)
const SKY_LOW := Color(0.638, 0.658, 0.690)
const HORIZON := Color(0.740, 0.756, 0.776)
const SEA_FAR := Color(0.618, 0.634, 0.660)
const SEA_NEAR := Color(0.216, 0.228, 0.250)
const SWELL := Color(0.780, 0.795, 0.815)
const GLINT := Color(0.600, 0.612, 0.632)

## 碎光：(x, y, 宽度)。y 全落在 131–143，也就是垛口能看见的那一条。
## 位置写死——它得每帧一样，累积才记得住。
const GLINTS := [
	[7.0, 134.0, 3.0], [24.0, 140.0, 4.0], [38.0, 133.0, 3.0],
	[56.0, 142.0, 5.0], [71.0, 136.0, 3.0], [86.0, 139.0, 4.0],
	[104.0, 132.0, 3.0], [119.0, 143.0, 4.0], [135.0, 137.0, 5.0],
	[152.0, 134.0, 3.0], [168.0, 141.0, 4.0], [184.0, 136.0, 3.0],
	[201.0, 142.0, 5.0], [217.0, 133.0, 3.0], [233.0, 139.0, 4.0],
	[249.0, 135.0, 3.0], [266.0, 143.0, 4.0], [281.0, 137.0, 5.0],
	[298.0, 134.0, 3.0], [313.0, 141.0, 4.0],
]

## 视差位移，单位是 320×180 空间里的像素；由控制器按注视点推。
## 海是最远的一层，系数 0.25，几乎不动——它一动，整屏就跟着晃。
var drift := Vector2.ZERO:
	set(value):
		if drift.is_equal_approx(value):
			return
		drift = value
		queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_sea()
	_draw_glints()


func _draw_sky() -> void:
	for i in int(HORIZON_Y):
		var t := float(i) / HORIZON_Y
		draw_rect(Rect2(-BLEED + drift.x, float(i) + drift.y,
			W + BLEED * 2.0, 1.2), SKY_HIGH.lerp(SKY_LOW, t))
	# 地平线：一条细亮线，是整幅画的远极
	draw_rect(Rect2(-BLEED + drift.x, HORIZON_Y - 1.0 + drift.y,
		W + BLEED * 2.0, 1.5), HORIZON)


func _draw_sea() -> void:
	var span := H - HORIZON_Y
	for i in int(span):
		var t := float(i) / span
		draw_rect(Rect2(-BLEED + drift.x, HORIZON_Y + float(i) + drift.y,
			W + BLEED * 2.0, 1.2), SEA_FAR.lerp(SEA_NEAR, pow(t, 0.72)))

	# 涌线：间隔随距离拉开（透视）。这是「海有进深」唯一的证据，
	# 三层错开的时候，眼睛就是拿这几条线当标尺的。
	var y := HORIZON_Y + 3.0
	var k := 0
	while y < H:
		var col := Color(SWELL.r, SWELL.g, SWELL.b, 0.105 + 0.022 * minf(float(k), 4.0))
		var amp := 0.5 + float(k) * 0.14
		var prev := Vector2.ZERO
		var first := true
		var x := -BLEED
		while x <= W + BLEED:
			var yy := y + sin(x * 0.043 + float(k) * 1.9) * amp
			var p := Vector2(x + drift.x, yy + drift.y)
			if not first:
				draw_line(prev, p, col, 1.2)
			prev = p
			first = false
			x += 10.0
		y += 1.8 + float(k) * 1.24
		k += 1


func _draw_glints() -> void:
	# 碎光：垛口里那点「亮」从这里来。平均亮度给不出这个——
	# 有光点，缺口才像透过去的，而不是一块灰面板。
	for g in GLINTS:
		var gx := float(g[0]) + drift.x
		var gy := float(g[1]) + drift.y
		draw_rect(Rect2(gx, gy, float(g[2]), 1.0), GLINT)
		draw_rect(Rect2(gx + 1.0, gy - 1.0, maxf(float(g[2]) - 2.0, 1.0), 1.0),
			Color(GLINT.r, GLINT.g, GLINT.b, 0.5))
		draw_rect(Rect2(gx + 1.0, gy + 1.0, maxf(float(g[2]) - 2.0, 1.0), 1.0),
			Color(GLINT.r, GLINT.g, GLINT.b, 0.35))
