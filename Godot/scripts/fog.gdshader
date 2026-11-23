shader_type canvas_item;
render_mode unshaded;

// 雾层：读取它下面的静态目标，用一层一直在动的雾把目标遮住。
// 雾必须一直在动，否则累积几秒就收敛成一张静止清晰图，「看得越清越是过去」当场失效。
//
// 两件事分开做：
//   遮挡——每帧重抽的颗粒决定这个像素这一帧被雾吃掉多少（动的，会被累积平均掉）
//   微光——大团的慢雾自己发一点冷光，给黑底一点体积
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.60;   // 遮蔽强度
uniform float glow_strength : hint_range(0.0, 0.8) = 0.34;    // 雾自身的微光
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;

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
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	float t = TIME * time_scale;
	vec2 uv = SCREEN_UV;

	// 慢雾：域扭曲过的多倍频噪声，整体横向漂移，底边更厚（海面起雾）。
	vec2 q = uv * vec2(5.5, 3.2) + vec2(t * 0.022, -t * 0.006);
	float w1 = fbm(q * 0.60 + vec2(t * 0.010, 0.0));
	float w2 = fbm(q * 0.60 + vec2(7.3, 2.1) - vec2(0.0, t * 0.008));
	float n = fbm(q + vec2(w1 * 1.6 - w2 * 0.6, w2 * 0.8));
	n = smoothstep(0.18, 0.82, n);
	n *= mix(0.45, 1.0, smoothstep(0.10, 0.98, uv.y));

	// 每帧重抽的颗粒：这一层在累积里被平均掉，是「看得清／看不清」的分界线。
	vec2 px = floor(uv / SCREEN_PIXEL_SIZE);
	float grain = hash12(px + floor(t * 53.0)) - 0.5;

	// 遮挡密度：颗粒权重很大，所以目标每一帧都会被吃掉一半、露出一半，
	// 轮廓连不起来；只有停止抖动（累积）之后，形状才连成一片。
	float occl = clamp((n - 0.28) * 1.3 + grain * 2.15, 0.0, 1.0);
	float trans = clamp(1.0 - occl * noise_strength * 1.55, 0.0, 1.0);

	// 雾自己的一点冷光。没有它，黑底上只有三个贴纸，看不出「雾」这个介质。
	vec3 fog_col = vec3(0.40, 0.47, 0.54);
	// 雾里的浮光：每帧重抽，累积会把它们抹平。这一层让「外面在动、注视点里不动」看得出来。
	float sparkle = max(grain, 0.0) * 0.30 * (0.35 + 0.65 * n);
	vec3 col = base * trans + fog_col * (glow_strength * n + sparkle);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}