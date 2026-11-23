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
// 圈外 keep 不是 0：完全不平滑的话，闪烁层就是一层原地跳的雪花。
// 0.80 是「平滑，但收敛得很慢」，仍然看得出在动。
uniform float keep_outside : hint_range(0.0, 0.99) = 0.80;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
	           mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// 把 x 乘上宽高比，注视圈在 16:9 里才是圆的而不是扁的。
	vec2 d = (UV - gaze_uv) * vec2(aspect, 1.0);
	// 清出来的边界不能是正圆——正圆一眼就是镜头。用慢噪声把半径揉一下，
	// 让雾像是被揉开的，不是被一个圈擦掉的。
	float wobble = 1.0 + (value_noise(UV * vec2(5.0, 3.0) + vec2(TIME * 0.015, 0.0)) - 0.5) * 0.85;
	float focus = 1.0 - smoothstep(gaze_radius * 0.30, gaze_radius * 1.10, length(d) * wobble);

	// acc = mix(prev, cur, w)。这里写等价形式：
	// keep 是「保留过去」的权重，w = 1 - keep。
	float keep = mix(keep_outside, decay, focus);
	keep = mix(keep, 0.0, prime);

	vec3 cur = texture(cur_tex, UV).rgb;
	vec3 prev = texture(prev_tex, UV).rgb;

	// 注视点内 keep -> decay：逐帧累积，动雾被平均掉，目标显影。
	// 注视点外 keep -> 0：每帧直接退回当前噪声，永远看不清。
	// 注意：这里不能再乘任何「注视点内提亮」。缓冲区是反馈回路，
	// 每一帧乘一次增益会指数放大，几秒后注视点内会烧成一片白。
	// 试过在这里加半个色阶的抖动去压等高线，结果在暗部变成一层看得见的沙点，撤掉了。
	// 现在靠「边界用噪声揉开」来避免正圆的镜头感，不靠抖动。
	float dither = 0.0;

	COLOR = vec4(clamp(mix(cur, prev, keep) + dither, 0.0, 1.0), 1.0);
}