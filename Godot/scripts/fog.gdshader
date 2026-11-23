shader_type canvas_item;
render_mode unshaded;

// 闪烁层：零均值加法信号，进累积缓冲。
// 它只负责「动」——振幅压到编码空间峰值 0.08，自己不许变成雪花。
// 「看不清」由 decode.gdshader 里那层不累积的底雾负责。
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;

const float SCENE_SCALE = 0.45;
const float FLICKER_PEAK = 0.08;
const vec3 FOG_COL = vec3(0.62, 0.68, 0.74);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

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

	// 时域整体降速十倍：一秒钟内看不出雾在变。
	float t = TIME * time_scale * 0.1;
	vec2 uv = SCREEN_UV;

	// 雾团的结构：域扭曲的多倍频噪声，慢漂，底边略厚
	vec2 q = uv * vec2(4.6, 2.7) + vec2(t * 0.28, -t * 0.07);
	float w1 = fbm(q * 0.62 + vec2(t * 0.12, 0.0));
	float w2 = fbm(q * 0.62 + vec2(7.3, 2.1) - vec2(0.0, t * 0.10));
	float big = fbm(q + vec2(w1 * 1.5 - w2 * 0.5, w2 * 0.9));
	float mid = fbm(uv * vec2(12.0, 7.0) + vec2(-t * 0.50, t * 0.20) + w1 * 0.6);
	float shape = smoothstep(0.28, 0.84, big * 0.65 + mid * 0.35);

	// 沸腾：软噪声在慢慢淌，不再每帧重掷相位
	float boil = value_noise(uv * vec2(26.0, 15.0) + vec2(t * 3.0, -t * 2.0));

	// 底边更厚只放大振幅，不抬高均值
	float thick = mix(0.55, 1.15, smoothstep(0.0, 0.88, uv.y));

	// 零均值信号：正负一样多，累积之后什么都不留
	float signal = ((shape - 0.46) * 0.80 + (boil - 0.50) * 0.55) * thick;

	vec3 enc = vec3(0.5) + scene * SCENE_SCALE + FOG_COL * clamp(signal, -1.0, 1.0) * FLICKER_PEAK * noise_strength;
	COLOR = vec4(clamp(enc, 0.0, 1.0), 1.0);
}