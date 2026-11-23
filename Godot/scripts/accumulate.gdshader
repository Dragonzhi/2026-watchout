shader_type canvas_item;
render_mode unshaded;

// 累积缓冲的一侧。
// 一个 SubViewport 只读 prev_tex（另一个 SubViewport 的上一帧）并写自己，
// 绝不读自己上一帧——读自己写回会形成反馈，画面会烧成一片。
uniform sampler2D cur_tex : filter_nearest;   // 本帧的雾与目标（SceneView）
uniform sampler2D prev_tex : filter_nearest;  // 另一侧缓冲的上一帧
uniform vec2 gaze_uv = vec2(0.5, 0.5);        // 注视点，0..1
uniform float gaze_radius : hint_range(0.02, 1.5) = 0.30;
uniform float decay : hint_range(0.0, 0.999) = 0.99;
uniform float aspect : hint_range(0.5, 4.0) = 1.7777778;
uniform float prime : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// 把 x 乘上宽高比，注视圈在 16:9 里才是圆的而不是扁的。
	vec2 d = (UV - gaze_uv) * vec2(aspect, 1.0);
	float focus = 1.0 - smoothstep(0.0, gaze_radius, length(d));

	// acc = mix(prev, cur, w)。这里写等价形式：
	// keep 是「保留过去」的权重，w = 1 - keep。
	float keep = mix(0.0, decay, focus);
	keep = mix(keep, 0.0, prime);

	vec3 cur = texture(cur_tex, UV).rgb;
	vec3 prev = texture(prev_tex, UV).rgb;

	// 注视点内 keep -> decay：逐帧累积，动雾被平均掉，目标显影。
	// 注视点外 keep -> 0：每帧直接退回当前噪声，永远看不清。
	// 注意：这里不能再乘任何「注视点内提亮」。缓冲区是反馈回路，
	// 每一帧乘一次增益会指数放大，几秒后注视点内会烧成一片白。
	COLOR = vec4(mix(cur, prev, keep), 1.0);
}