shader_type canvas_item;
render_mode unshaded;

// 这一层输出的不是屏幕颜色，是一帧「带偏移的编码」：
//     v = 0.5 + 0.30 * scene + fog_signal       （fog_signal 的均值 ≈ 0）
// Display 上的 decode.gdshader 把它减掉底座再放大回去。
//
// 为什么非这么绕：8 位缓冲没有负数。雾要被累积平均掉、又不能在注视圈里留下一层灰，
// 就必须是零均值信号——亮的雾团（正）和暗的雾团（负）一样多。
// 累积之后信号归零，露出来的就是底下的东西本身；周围那一帧里，正的一半把它糊掉、
// 负的一半直接把它抹黑。
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;   // 雾的振幅（编码空间）
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;

const vec3 FOG_COL = vec3(0.60, 0.67, 0.74);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 平滑插值的值噪声：放大 4 倍后是软团，不是沙点。
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p = p * 2.03 + vec2(11.3, 7.7);
		a *= 0.5;
	}
	return v / 0.9375;
}

void fragment() {
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	float t = TIME * time_scale;
	vec2 uv = SCREEN_UV;

	// ── 形：域扭曲的多倍频噪声，横向慢漂，底边更厚（海面起雾）
	vec2 q = uv * vec2(4.6, 2.7) + vec2(t * 0.026, -t * 0.006);
	float w1 = fbm(q * 0.62 + vec2(t * 0.011, 0.0));
	float w2 = fbm(q * 0.62 + vec2(7.3, 2.1) - vec2(0.0, t * 0.009));
	float big = fbm(q + vec2(w1 * 1.5 - w2 * 0.5, w2 * 0.9));
	float mid = fbm(uv * vec2(12.0, 7.0) + vec2(-t * 0.045, t * 0.018) + w1 * 0.6);
	float raw = big * 0.65 + mid * 0.35;
	float shape = smoothstep(0.28, 0.84, raw);                  // 雾团的结构，0..1
	float thick = mix(0.55, 1.30, smoothstep(0.0, 0.88, uv.y));  // 底边厚的只是振幅，不是均值

	// ── 动：十来个内像素一团的软噪声，每帧换相位。
	// 刻意不用逐像素哈希——那在 Nearest 放大后是满屏沙点，就是「灰尘」的来源。
	float phase = floor(t * 22.0);
	float boil = value_noise(uv * vec2(26.0, 15.0) + vec2(phase * 4.13, phase * 2.71));

	// ── 零均值信号：亮的雾团（正）与暗的雾团（负）一样多，累积之后什么都不留。
	// 底边更厚只放大振幅、不抬高均值，否则注视圈里会慢慢积出一层灰。
	float signal = ((shape - 0.46) * 0.80 + (boil - 0.50) * 0.78) * thick;

	vec3 enc = vec3(0.5) + scene * 0.30 + FOG_COL * signal * noise_strength * 0.36;
	COLOR = vec4(clamp(enc, 0.0, 1.0), 1.0);
}