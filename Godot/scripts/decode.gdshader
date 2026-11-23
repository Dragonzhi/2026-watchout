shader_type canvas_item;
render_mode unshaded;

// 累积缓冲的还原 + 不累积的雾。
//
// 雾分三层，靠视差做出厚度：
//   远岸 bank —— 大尺度、慢、浓；注视遮罩把它从 0.80 擦到 0.16（「看不清」的主力）
//   近帘 veil —— 中尺度、快 2.5 倍、薄；遮罩只擦三到四成，
//                所以注视窗里不是纯黑，是「雾薄了，而且还在淌」
//   月光 moon —— 很淡的斜向亮带，给雾一个光源方向，免得整屏死平
uniform vec2 gaze_uv = vec2(0.5, 0.5);
uniform float gaze_radius : hint_range(0.02, 1.2) = 0.30;
uniform float aspect = 1.7777778;
uniform vec2 internal_size = vec2(320.0, 180.0);
uniform float bank_outside : hint_range(0.0, 1.0) = 0.80;
uniform float bank_inside : hint_range(0.0, 1.0) = 0.16;
uniform float veil_outside : hint_range(0.0, 1.0) = 0.26;
uniform float veil_inside : hint_range(0.0, 1.0) = 0.10;
uniform float moon_glow : hint_range(0.0, 0.4) = 0.06;
uniform float time_scale : hint_range(0.0, 4.0) = 1.0;

const float SCENE_SCALE = 0.45;
const vec3 FOG_COL = vec3(0.30, 0.34, 0.38);

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
	vec3 v = texture(TEXTURE, UV).rgb;
	vec3 scene = clamp((v - vec3(0.5)) / SCENE_SCALE, 0.0, 1.0);

	float t = TIME * time_scale * 0.1;
	vec2 cuv = (floor(UV * internal_size) + 0.5) / internal_size;   // 按内部像素取

	// 远岸：大团、慢
	float bank = fbm(cuv * vec2(3.0, 1.8) + vec2(t * 0.55, -t * 0.20));
	bank = smoothstep(0.22, 0.86, bank);

	// 近帘：中尺度、快 2.5 倍——视差就靠它
	float veil = fbm(cuv * vec2(7.0, 4.2) + vec2(-t * 1.40, t * 0.60));
	veil = smoothstep(0.25, 0.90, veil);

	// 清窗：两倍频揉边，且跟着雾自己的结构走（雾团处还得费劲）
	vec2 d = (UV - gaze_uv) * vec2(aspect, 1.0);
	float w1 = value_noise(UV * vec2(5.0, 3.0) + vec2(TIME * 0.015, 0.0));
	float w2 = value_noise(UV * vec2(17.0, 10.0) - vec2(0.0, TIME * 0.021));
	float wobble = 1.0 + (w1 - 0.5) * 0.70 + (w2 - 0.5) * 0.30;
	float clear = 1.0 - smoothstep(gaze_radius * 0.18, gaze_radius * 1.25, length(d) * wobble);
	clear *= 0.55 + 0.45 * bank;

	float bank_d = mix(bank_outside, bank_inside, clear);
	float veil_d = mix(veil_outside, veil_inside, clear) * (0.55 + 0.75 * veil);
	float dens = clamp(bank_d + veil_d, 0.0, 1.0);

	// 月光：一条斜向亮带
	float moon = smoothstep(0.10, 0.95, 1.0 - abs(UV.y - 0.30) * 2.2) * (0.55 + 0.45 * UV.x);

	vec3 fog_col = FOG_COL * (0.62 + 0.35 * bank + 0.25 * veil);
	fog_col += vec3(0.55, 0.60, 0.66) * moon * moon_glow;

	COLOR = vec4(mix(scene, fog_col, dens), 1.0);
}