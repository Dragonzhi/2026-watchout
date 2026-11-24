extends Control

## 累积凝视原型。
##
## 三层分工：
##   闪烁层 fog.gdshader —— 零均值加法信号，进累积，只负责「动」。
##   底雾   decode.gdshader —— 正的、慢的、不累积，负责「看不清」，靠近注视点擦薄。
##   累积   accumulate.gdshader —— 圈内 keep→decay 把闪烁抹平，圈外 keep→keep_outside 只慢平滑。
##
## 结构：SceneView（雾＋目标）→ AccumA／AccumB 交替累积 → Display 解码并叠底雾。
## 硬约束：一个 SubViewport 只读另一个的上一帧、写自己；写完交换角色，绝不读自己。

# 自查用的三个注视位置：海面、女墙、火盆。
const GAZE_SEA := Vector2(0.520, 0.520)   # 海面正中，离地平线远一点
const GAZE_WALL := Vector2(0.335, 0.880)  # 墙身
const GAZE_FIRE := Vector2(0.773, 0.800)  # 火盆

@export_group("构图")

## 女墙（含垛口）占画面高度的比例。
##
## 越大，人越贴着墙：0.20 是趴在垛口上往外看，0.40 是墙到胸口、石滩被吃掉半条。
## 三层的高度全部由它和 Mid Ratio 推出来，改一个，另外两层跟着让位。
@export_range(0.20, 0.40, 0.005) var fore_ratio: float = 0.28:
	set(value):
		fore_ratio = clampf(value, 0.20, 0.40)
		_layout()

## 石滩过渡带的高度比例。它坐在海与女墙之间，越薄越像远景、越厚越像脚边。
@export_range(0.06, 0.20, 0.005) var mid_ratio: float = 0.12:
	set(value):
		mid_ratio = clampf(value, 0.06, 0.20)
		_layout()

## 注视点带动整体位移的最大幅度，单位是 320×180 空间里的像素。
##
## 幅度只能是「小」：位移一大，累积就把整屏抹成拖影，看起来像回到雪花那天。
@export_range(0.0, 14.0, 0.1) var drift_amount: float = 6.5:
	set(value):
		drift_amount = clampf(value, 0.0, 14.0)

## 位移跟住注视点的速度。越小越黏越慢；1.4 大约两秒才走完大半。
##
## 慢是硬要求，不是手感偏好：快移的层会被累积糊成拖影。
@export_range(0.2, 6.0, 0.05) var drift_speed: float = 1.4:
	set(value):
		drift_speed = clampf(value, 0.2, 6.0)

## 女墙的视差系数。人就贴在它后面，视线一动它动得最多。
@export_range(0.0, 1.5, 0.01) var parallax_near: float = 1.0

## 石滩的视差系数。夹在墙与海中间，动一半。
@export_range(0.0, 1.5, 0.01) var parallax_mid: float = 0.55

## 海面的视差系数。它最远，几乎不动——它一动，整屏就跟着晃。
@export_range(0.0, 1.5, 0.01) var parallax_far: float = 0.25

@export_group("累积")

## 圈内累积系数：每帧保留多少过去。
##
## 越接近 1，累积越慢、显影要等得越久，但留下来的噪点越少；
## 调低会立刻显影，也会立刻看出闪烁。0.99 左右是「盯几秒才成形」。
@export_range(0.90, 0.999, 0.001) var decay: float = 0.993:
	set(value):
		decay = clampf(value, 0.90, 0.999)
		_push_params()

## 圈外的累积系数。故意不是 0——完全不平滑的话，闪烁层就是原地跳的雪花。
##
## 0.80 大致是「平滑，但收敛明显慢」：雾还在动，只是不闪。
@export_range(0.0, 0.95, 0.01) var keep_outside: float = 0.80:
	set(value):
		keep_outside = clampf(value, 0.0, 0.95)
		_push_params()

@export_group("注视点")

## 注视半径，按屏幕高度的比例计；也是清窗的半径。
##
## 0.30 ≈ 屏幕高度的 30%。调小更聚光，调到 1.0 以上接近整屏都清。
@export_range(0.02, 1.2, 0.01) var gaze_radius: float = 0.30:
	set(value):
		gaze_radius = maxf(value, 0.02)
		_push_params()

@export_group("雾")

## 圈外远岸浓度：雾的主体，负责「看不清」。
##
## 和 Bank Inside 一起决定清窗的落差。0.6–0.9 之间试。
@export_range(0.0, 1.0, 0.01) var bank_outside: float = 0.60:
	set(value):
		bank_outside = clampf(value, 0.0, 1.0)
		_push_params()

## 注视圈内远岸被擦到多薄。
##
## 0 会挖成一个黑洞，看着像手电；0.12–0.2 是「雾薄了，但还在」。
@export_range(0.0, 1.0, 0.01) var bank_inside: float = 0.16:
	set(value):
		bank_inside = clampf(value, 0.0, 1.0)
		_push_params()

## 圈外近帘浓度：漂得比远岸快 2.5 倍的那层薄雾。
##
## 视差靠它——近处雾动得快，才有「雾有厚度」的感觉。
@export_range(0.0, 1.0, 0.01) var veil_outside: float = 0.18:
	set(value):
		veil_outside = clampf(value, 0.0, 1.0)
		_push_params()

## 圈内残留的近帘。窗里的地板亮度基本由它决定。
##
## 0 = 窗内纯黑；0.08–0.12 会让窗里还留一层来去可见的薄雾。
@export_range(0.0, 1.0, 0.01) var veil_inside: float = 0.10:
	set(value):
		veil_inside = clampf(value, 0.0, 1.0)
		_push_params()

## 雾面上那条斜向月光亮带的强度，给雾一个光源方向。
##
## 0 = 整屏死平；0.06–0.12 有层次；再高就开始像白天。
@export_range(0.0, 0.4, 0.005) var moon_glow: float = 0.06:
	set(value):
		moon_glow = clampf(value, 0.0, 0.4)
		_push_params()

## 闪烁层振幅的倍率。闪烁层自身峰值固定在编码空间 0.08，这里只是整体缩放。
##
## 0 = 雾完全静止（累积就没东西可抹，不要这么用）；1.0 = 默认。
@export_range(0.0, 1.0, 0.01) var noise_strength: float = 1.0:
	set(value):
		noise_strength = clampf(value, 0.0, 1.0)
		_push_params()

@export_group("画质")

## 内部分辨率。场景与累积都在这上面跑，最后由 TextureRect 用 Nearest 放大到全屏。
##
## 320×180 是这个原型的风格基线；改大更锐利，改小更粗。
@export var internal_size: Vector2i = Vector2i(320, 180):
	set(value):
		internal_size = Vector2i(clampi(value.x, 160, 640), clampi(value.y, 90, 360))
		_apply_internal_size()

@export_group("")

@onready var _scene_view: SubViewport = $SceneView
@onready var _accum_a: SubViewport = $AccumA
@onready var _accum_b: SubViewport = $AccumB
@onready var _display: TextureRect = $Display
@onready var _fog: ColorRect = $SceneView/Fog
@onready var _fill_a: ColorRect = $AccumA/Fill
@onready var _fill_b: ColorRect = $AccumB/Fill
@onready var _marker: Node2D = $GazeLayer/GazeMarker
@onready var _shapes := $SceneView/Shapes
@onready var _mid := $NearLayer/Midground
@onready var _fore := $NearLayer/Foreground

var _mat_fog: ShaderMaterial
var _mat_a: ShaderMaterial
var _mat_b: ShaderMaterial
var _mat_decode: ShaderMaterial

var _tex_cur: ViewportTexture
var _tex_a: ViewportTexture
var _tex_b: ViewportTexture

var _gaze := Vector2(0.5, 0.5)
## 当前整体位移（带阻尼）。三个视差层各取它的一份，方向相反。
var _drift := Vector2.ZERO
var _write_a := true
var _warmup := 2
var _auto_shot := false
var _auto_gaze := GAZE_SEA


func _ready() -> void:
	_mat_fog = _fog.material as ShaderMaterial
	_mat_a = _fill_a.material as ShaderMaterial
	_mat_b = _fill_b.material as ShaderMaterial
	_mat_decode = _display.material as ShaderMaterial

	# 320×180 的内部缓冲放大到全屏，必须 nearest——风格的一半在这里。
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.stretch_mode = TextureRect.STRETCH_SCALE

	_apply_internal_size()

	_tex_cur = _scene_view.get_texture()
	_tex_a = _accum_a.get_texture()
	_tex_b = _accum_b.get_texture()

	# 两侧缓冲互相读对方的上一帧，永远不读自己。
	_mat_a.set_shader_parameter("cur_tex", _tex_cur)
	_mat_a.set_shader_parameter("prev_tex", _tex_b)
	_mat_b.set_shader_parameter("cur_tex", _tex_cur)
	_mat_b.set_shader_parameter("prev_tex", _tex_a)

	_display.texture = _tex_cur
	_push_params()

	print("[gaze] display rect=", _display.get_rect(), " viewport=", get_viewport_rect().size,
		" internal=", internal_size)

	_layout()
	_fit_near_layers()
	get_viewport().size_changed.connect(_fit_near_layers)

	_auto_shot = "--shot" in OS.get_cmdline_user_args()
	if _auto_shot:
		_run_auto_shot()


func _process(delta: float) -> void:
	if _auto_shot:
		_gaze = _auto_gaze
	else:
		_gaze = _mouse_uv()
	_marker.aim = _gaze
	_update_drift(delta)
	_push_params()
	_swap_buffers()


func _mouse_uv() -> Vector2:
	var size := get_viewport_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var p := get_viewport().get_mouse_position() / size
	return Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, 1.0))


func _swap_buffers() -> void:
	# 硬约束：同一个 SubViewport 不能既读自己上一帧又写回。
	# 本帧只让一个写、另一个只读；下一帧交换角色。
	if _warmup > 0:
		var prime_a := _warmup == 2
		_warmup -= 1
		_set_update(_accum_a, prime_a)
		_set_update(_accum_b, not prime_a)
		if prime_a:
			_mat_a.set_shader_parameter("prime", 1.0)
		else:
			_mat_b.set_shader_parameter("prime", 1.0)
		_display.texture = _tex_a if prime_a else _tex_b
		if _warmup == 0:
			_mat_a.set_shader_parameter("prime", 0.0)
			_mat_b.set_shader_parameter("prime", 0.0)
		return

	_write_a = not _write_a
	_set_update(_accum_a, _write_a)
	_set_update(_accum_b, not _write_a)
	_display.texture = _tex_a if _write_a else _tex_b


func _set_update(vp: SubViewport, on: bool) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _push_params() -> void:
	if not is_node_ready() or _mat_a == null:
		return
	var aspect := float(internal_size.x) / float(internal_size.y)
	for m in [_mat_a, _mat_b]:
		var mat := m as ShaderMaterial
		mat.set_shader_parameter("gaze_uv", _gaze)
		mat.set_shader_parameter("gaze_radius", gaze_radius)
		mat.set_shader_parameter("decay", decay)
		mat.set_shader_parameter("keep_outside", keep_outside)
		mat.set_shader_parameter("aspect", aspect)
	if _mat_fog != null:
		_mat_fog.set_shader_parameter("noise_strength", noise_strength)
	if _mat_decode != null:
		_mat_decode.set_shader_parameter("gaze_uv", _gaze)
		_mat_decode.set_shader_parameter("gaze_radius", gaze_radius)
		_mat_decode.set_shader_parameter("aspect", aspect)
		_mat_decode.set_shader_parameter("internal_size", Vector2(internal_size))
		_mat_decode.set_shader_parameter("bank_outside", bank_outside)
		_mat_decode.set_shader_parameter("bank_inside", bank_inside)
		_mat_decode.set_shader_parameter("veil_outside", veil_outside)
		_mat_decode.set_shader_parameter("veil_inside", veil_inside)
		_mat_decode.set_shader_parameter("moon_glow", moon_glow)


func _apply_internal_size() -> void:
	if not is_node_ready():
		return
	_scene_view.size = internal_size
	_accum_a.size = internal_size
	_accum_b.size = internal_size
	var s := Vector2(internal_size)
	for rect in [_fog, _fill_a, _fill_b]:
		var c := rect as Control
		c.position = Vector2.ZERO
		c.size = s
	# 形状是按 320×180 画的，换内部分辨率时整体缩放，构图不跑。
	_shapes.scale = s / Vector2(320.0, 180.0)
	_fit_near_layers()
	_layout()
	_push_params()


func _fit_near_layers() -> void:
	# 近景两层按 320×180 画，整体缩放到窗口。
	# 节点位置留在原点：位移在各自的 _draw() 里做，否则会被缩放乘第二遍。
	var s := get_viewport_rect().size / Vector2(320.0, 180.0)
	for n in [_mid, _fore]:
		if n != null:
			n.scale = s


func _layout() -> void:
	# 三层高度全从两个比例推出来：改一个，另外两层跟着让位。
	if not is_node_ready():
		return
	var h := 180.0
	var fore_top := h * (1.0 - fore_ratio)
	if _fore != null:
		_fore.top_y = fore_top
	if _mid != null:
		_mid.top_y = fore_top - h * mid_ratio
		_mid.height = h * mid_ratio
		_mid.queue_redraw()


func _update_drift(delta: float) -> void:
	# 注视点推一个很小的整体位移，重阻尼跟过去。
	# 三层的系数不同，所以视线一动它们就错开——纵深感是从这儿来的，不是画出来的。
	var target := (_gaze - Vector2(0.5, 0.5)) * 2.0 * drift_amount
	_drift = _drift.lerp(target, 1.0 - exp(-delta * drift_speed))
	if _shapes != null:
		# 海在累积里：位移取整。亚像素的西微挪动会被累积抹成整片拖影。
		_shapes.drift = Vector2(
			round(-_drift.x * parallax_far), round(-_drift.y * parallax_far))
	if _mid != null:
		_mid.drift = -_drift * parallax_mid
	if _fore != null:
		_fore.drift = -_drift * parallax_near


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F12:
		capture_screenshot()


func capture_screenshot(prefix := "gaze") -> void:
	# 必须先等这一帧画完，否则抓到的是全黑的空纹理。
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := dir.path_join("%s_%s.png" % [prefix, stamp])
	var err := img.save_png(path)
	if err == OK:
		print("[shot] ", path)
	else:
		push_error("[shot] 保存失败：%d" % err)


func _run_auto_shot() -> void:
	# 自查用，走和 F12 完全同一条路径：
	# 1 盯着墩台五秒 → 2 把视线移到空处 → 3 同一块再等两秒。
	await get_tree().create_timer(4.0).timeout
	await capture_screenshot("1_gaze_sea")
	_auto_gaze = GAZE_WALL
	await get_tree().create_timer(3.5).timeout
	await capture_screenshot("2_gaze_wall")
	_auto_gaze = GAZE_FIRE
	await get_tree().create_timer(3.0).timeout
	await capture_screenshot("3_gaze_fire")
	fore_ratio = 0.40
	_auto_gaze = GAZE_WALL
	await get_tree().create_timer(3.0).timeout
	await capture_screenshot("4_wall_040")
	get_tree().quit()