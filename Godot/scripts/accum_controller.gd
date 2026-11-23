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

const AUTO_GAZE := Vector2(0.503, 0.61)   # 墩台
const AWAY_GAZE := Vector2(0.16, 0.32)    # 空处，用来验「移开视线就重新糊上」

@export_range(0.90, 0.999, 0.001) var decay: float = 0.993:
	set(value):
		decay = clampf(value, 0.90, 0.999)
		_push_params()
@export_range(0.0, 0.95, 0.01) var keep_outside: float = 0.80:
	set(value):
		keep_outside = clampf(value, 0.0, 0.95)
		_push_params()
@export_range(0.02, 1.2, 0.01) var gaze_radius: float = 0.30:
	set(value):
		gaze_radius = maxf(value, 0.02)
		_push_params()
@export_range(0.0, 1.0, 0.01) var noise_strength: float = 1.0:
	set(value):
		noise_strength = clampf(value, 0.0, 1.0)
		_push_params()
@export_range(0.0, 1.0, 0.01) var bank_outside: float = 0.60:
	set(value):
		bank_outside = clampf(value, 0.0, 1.0)
		_push_params()
@export_range(0.0, 1.0, 0.01) var bank_inside: float = 0.16:
	set(value):
		bank_inside = clampf(value, 0.0, 1.0)
		_push_params()
@export_range(0.0, 1.0, 0.01) var veil_outside: float = 0.18:
	set(value):
		veil_outside = clampf(value, 0.0, 1.0)
		_push_params()
@export_range(0.0, 1.0, 0.01) var veil_inside: float = 0.10:
	set(value):
		veil_inside = clampf(value, 0.0, 1.0)
		_push_params()
@export_range(0.0, 0.4, 0.005) var moon_glow: float = 0.06:
	set(value):
		moon_glow = clampf(value, 0.0, 0.4)
		_push_params()
@export var internal_size: Vector2i = Vector2i(320, 180):
	set(value):
		internal_size = Vector2i(clampi(value.x, 160, 640), clampi(value.y, 90, 360))
		_apply_internal_size()

@onready var _scene_view: SubViewport = $SceneView
@onready var _accum_a: SubViewport = $AccumA
@onready var _accum_b: SubViewport = $AccumB
@onready var _display: TextureRect = $Display
@onready var _fog: ColorRect = $SceneView/Fog
@onready var _fill_a: ColorRect = $AccumA/Fill
@onready var _fill_b: ColorRect = $AccumB/Fill
@onready var _marker: Node2D = $GazeLayer/GazeMarker
@onready var _shapes: Node2D = $SceneView/Shapes
@onready var _foreground: Node2D = $NearLayer/Foreground

var _mat_fog: ShaderMaterial
var _mat_a: ShaderMaterial
var _mat_b: ShaderMaterial
var _mat_decode: ShaderMaterial

var _tex_cur: ViewportTexture
var _tex_a: ViewportTexture
var _tex_b: ViewportTexture

var _gaze := Vector2(0.5, 0.5)
var _write_a := true
var _warmup := 2
var _auto_shot := false
var _auto_gaze := AUTO_GAZE


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

	_fit_foreground()
	get_viewport().size_changed.connect(_fit_foreground)

	_auto_shot = "--shot" in OS.get_cmdline_user_args()
	if _auto_shot:
		_run_auto_shot()


func _process(_delta: float) -> void:
	if _auto_shot:
		_gaze = _auto_gaze
	else:
		_gaze = _mouse_uv()
	_marker.aim = _gaze
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
	_fit_foreground()
	_push_params()


func _fit_foreground() -> void:
	if _foreground != null:
		_foreground.scale = get_viewport_rect().size / Vector2(320.0, 180.0)


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
	await get_tree().create_timer(5.0).timeout
	await capture_screenshot("1_inside")
	_auto_gaze = AWAY_GAZE
	await get_tree().create_timer(0.4).timeout
	await capture_screenshot("2_moved")
	await get_tree().create_timer(2.0).timeout
	await capture_screenshot("3_moved_2s")
	get_tree().quit()