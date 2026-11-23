shader_type canvas_item;
render_mode unshaded;

// 把累积缓冲的编码还原成屏幕颜色：v = 0.5 + 0.30 * scene + 雾信号。
// 底座 0.5 解出来是纯黑——所以注视点里累积干净的那一块，底色是真的黑。
uniform float base_offset = 0.5;
uniform float scene_scale = 0.30;

void fragment() {
	vec3 v = texture(TEXTURE, UV).rgb;
	COLOR = vec4(clamp((v - vec3(base_offset)) / scene_scale, 0.0, 1.0), 1.0);
}
