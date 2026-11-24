extends Node2D

## 前景：女墙与垛口，墙顶还有那盆火。
##
## 挂在 NearLayer（Display 之上、注视点之下）。人在墙后，所以它不被雾吃、
## 不进累积——它是「现在」，是整幅画唯一清楚的一层。
##
## 垛口之间是挖空的：那几道缺口什么也不画，露出后面的近水与碎光。
## 缺口一旦填死，前景就是一整条死黑，人也就退回画面外面去了。
##
## 垛口要宽、缝要窄。缝比垛口还宽的时候，这一排就读成栏杆，不是墙——
## 早先 15/19 的比例就是这么废掉的，现在是 21/9。
##
## 坐标按 320×180 画；控制器给 top_y，并按视差系数推 drift（墙是 1.0，动得最多）。

const W := 320.0
const H := 180.0
const BLEED := 18.0

## 一个垛口的宽度与间距。间距 30 在 320 宽上排十一个，缝宽 9。
const MERLON_W := 21.0
const MERLON_PITCH := 30.0
## 垛口高出墙身的高度。控制器给的是垛口顶，墙身顶由它加出来。
const MERLON_H := 15.0
## 墙顶受光面的厚度：人眼越过墙时看见的那道面，是「从上往下看」的直接证据。
const TOP_FACE := 5.0

## 垛口顶的风化起伏，循环取用。整排一条水平线太像切出来的。
const ERRF := [0.0, 0.6, -0.4, 0.4, -0.6, 0.2, 0.7, -0.2, 0.3, -0.5, 0.5]

const STONE := Color(0.050, 0.052, 0.058)
const STONE_DEEP := Color(0.038, 0.040, 0.045)
const STONE_LO := Color(0.031, 0.033, 0.038)
const STONE_MID := Color(0.072, 0.075, 0.082)
const STONE_HI := Color(0.176, 0.181, 0.192)
const MERLON_EDGE := Color(0.112, 0.118, 0.130)

const IRON := Color(0.066, 0.063, 0.062)
const IRON_RIM := Color(0.330, 0.208, 0.116)
const EMBER := Color(0.900, 0.372, 0.100)
const FLAME_OUT := Color(0.870, 0.336, 0.066)
const FLAME_CORE := Color(0.985, 0.726, 0.318)
const WARM := Color(0.420, 0.224, 0.082)

## 垛口顶在 320×180 里的 y，由控制器按 fore_ratio 算。
var top_y := 129.6

## 火盆中心的 x。对准两个垛口之间，火苗才是衬着海、不是衬着石头。
var fire_x := 247.5

## 视差位移；墙系数 1.0，视线一动它动得最多。
var drift := Vector2.ZERO:
	set(value):
		if drift.is_equal_approx(value):
			return
		drift = value
		queue_redraw()

var _t := 0.0


func _process(delta: float) -> void:
	# 火要动，但不是雪花：几条低频正弦叠加，不用逐帧重抽的随机。
	_t += delta
	queue_redraw()


func _draw() -> void:
	var body_top := top_y + MERLON_H
	_draw_body(body_top)
	_draw_top_face(body_top)
	_draw_merlons(body_top)
	_draw_spill(body_top)
	_draw_brazier(body_top)


func _draw_body(body_top: float) -> void:
	# 墙身分四道压暗：上沿比下沿亮一点，一整片平黑就没有厚度了。
	var span := H - body_top + BLEED
	var bands := 4
	for i in bands:
		var c := STONE.lerp(STONE_DEEP, float(i) / float(bands - 1))
		draw_rect(Rect2(-BLEED + drift.x, body_top + span * float(i) / float(bands) + drift.y,
			W + BLEED * 2.0, span / float(bands) + 0.6), c)
	# 砌石：横缝每 6px，竖缝逐行错开。对比压到最低，只留一层不齐。
	var y := body_top + 5.0
	var row := 0
	while y < H + BLEED:
		draw_rect(Rect2(-BLEED + drift.x, y + drift.y, W + BLEED * 2.0, 1.0), STONE_LO)
		var x := -BLEED + 6.0 + float((row * 13) % 19)
		while x < W + BLEED:
			draw_rect(Rect2(x + drift.x, y + drift.y, 1.0, 5.0), STONE_LO)
			x += 34.0
		y += 6.2
		row += 1
	# 两三块返潮的旧石，免得墙身是一整片均匀的黑
	draw_rect(Rect2(64.0 + drift.x, body_top + 11.0 + drift.y, 23.0, 5.0), STONE_MID)
	draw_rect(Rect2(176.0 + drift.x, body_top + 18.0 + drift.y, 17.0, 5.0), STONE_MID)
	draw_rect(Rect2(292.0 + drift.x, body_top + 7.0 + drift.y, 13.0, 5.0), STONE_MID)


func _draw_top_face(body_top: float) -> void:
	# 墙顶的受光面。光落在一条窄面上，而不是一整块墙突然结束——
	# 有没有这一道，决定人是站在墙后，还是站在画外面。
	draw_rect(Rect2(-BLEED + drift.x, body_top - TOP_FACE + drift.y,
		W + BLEED * 2.0, TOP_FACE), STONE_HI)
	# 外棱压一道暗，顶面才有厚度，不像贴上去的一条亮边
	draw_rect(Rect2(-BLEED + drift.x, body_top - 0.9 + drift.y,
		W + BLEED * 2.0, 1.0), STONE_MID)


func _draw_merlons(body_top: float) -> void:
	var mh := body_top - top_y + 1.0
	var x := -BLEED
	var idx := 0
	while x < W + BLEED:
		var px := x + drift.x
		# 每个垛口顶差半像素上下的风化，整排等高会读成切出来的
		var py: float = top_y + drift.y + float(ERRF[idx % ERRF.size()])
		idx += 1
		draw_rect(Rect2(px, py, MERLON_W, mh), STONE)
		# 顶边与左边受光，右侧内面压暗：一个垛口才有两个方向
		draw_rect(Rect2(px, py, MERLON_W, 1.4), MERLON_EDGE)
		draw_rect(Rect2(px, py, 1.2, mh), MERLON_EDGE)
		draw_rect(Rect2(px + MERLON_W - 1.4, py, 1.4, mh), STONE_LO)
		x += MERLON_PITCH


func _draw_spill(body_top: float) -> void:
	# 火光落在墙顶：越靠近盆越暖。这是全画唯一的暖色外溢，
	# 也是「火是真在烧」的证据——只画火苗的话，它像贴纸。
	for i in 8:
		var w := 152.0 - float(i) * 15.0
		draw_rect(Rect2(fire_x - w * 0.5 + drift.x, body_top - TOP_FACE + drift.y,
			w, TOP_FACE), Color(WARM.r, WARM.g, WARM.b, 0.030))
	for i in 3:
		var w2 := 80.0 - float(i) * 22.0
		draw_rect(Rect2(fire_x - w2 * 0.5 + drift.x, body_top - TOP_FACE - 1.6 + drift.y,
			w2, 1.6), Color(WARM.r, WARM.g, WARM.b, 0.028))


func _draw_brazier(body_top: float) -> void:
	# 三档低频叠出来的火势，0.6–1.0 之间起落；不做逐帧随机。
	var fl := 0.80 + 0.10 * sin(_t * 6.1) + 0.06 * sin(_t * 11.7 + 1.1) \
		+ 0.04 * sin(_t * 17.3 + 2.4)
	var cx := fire_x + drift.x
	var base_y := body_top - 0.6 + drift.y
	var lip := base_y - 5.4

	# 盆：上宽下窄的浅斗
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 6.4, lip), Vector2(cx + 6.4, lip),
		Vector2(cx + 3.8, base_y), Vector2(cx - 3.8, base_y),
	]), IRON)
	draw_rect(Rect2(cx - 7.0, lip - 1.2, 14.0, 1.4), IRON_RIM)

	# 火：外焰两簇、主焰一簇、内芯一簇。都是三角形，凸的，不会画不出来。
	var h := 12.0 + 4.0 * fl
	_flame(cx - 3.0, lip, 4.6, h * 0.82, FLAME_OUT)
	_flame(cx + 3.2, lip, 4.0, h * 0.68, FLAME_OUT)
	_flame(cx - 0.2, lip + 0.4, 5.6, h * 1.12, FLAME_OUT)
	_flame(cx + 0.3, lip + 0.6, 2.6, h * 0.70, FLAME_CORE)

	# 炭底
	draw_rect(Rect2(cx - 4.2, lip + 0.2, 8.4, 1.4), EMBER)

	# 外溢的辉光：两圈很淡的暖光。太浓就会把整个垛口压成一块聚光斑。
	draw_circle(Vector2(cx, lip - 2.6), 5.2,
		Color(FLAME_OUT.r, FLAME_OUT.g, FLAME_OUT.b, 0.024))
	draw_circle(Vector2(cx, lip - 2.6), 8.4,
		Color(FLAME_OUT.r, FLAME_OUT.g, FLAME_OUT.b, 0.016))


func _flame(cx: float, base_y: float, w: float, h: float, col: Color) -> void:
	# 尖往一边偏一点，火才不是一根针。三角形永远凸，安全。
	var sway := sin(_t * 4.7 + cx * 0.11) * 0.7
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.5, base_y),
		Vector2(cx + sway, base_y - h),
		Vector2(cx + w * 0.5, base_y),
	]), col)