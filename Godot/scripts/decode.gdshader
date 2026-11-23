shader_type canvas_item;
render_mode unshaded;

// 累积缓冲的还原 + 一层不累积的底雾。
// 底雾是正的、慢的、一直存在的；它在注视点附近被擦薄。
// 挪开视线，那块立刻被重新糊上——「看不清」由它负责，不由闪烁负责。
uniform vec2 gaze_uv = vec2(0.5, 0.5);
uniform float gaze_radius : hint_range(0.02, 1.2) = 0.30;
uniform float aspect = 1.7777778;
uniform vec2 internal_size = vec2(320.0, 180.0);
uniform float density_outside : hint_range(0.0, 1.0) = 0.66;
uniform float density_inside : hint_range(0.0, 1.0) = 0.12;
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

	// 底雾按内部分辨率的格子取，跟 320×180 的颗粒对齐
	vec2 cell = floor(UV * internal_size) + 0.5;
	vec2 cuv = cell / internal_size;
	float n1 = fbm(cuv * vec2(3.0, 1.8) + vec2(t * 0.55, -t * 0.20));
	float n2 = fbm(cuv * vec2(9.0, 5.5) + vec2(-t * 1.10, t * 0.45));
	float n = clamp(n1 * 0.72 + n2 * 0.28, 0.0, 1.0);
	n = smoothstep(0.24, 0.86, n);

	// 揉开的清窗：边界不是正圆，和 accumulate 里那套完全同一条公式，两边对齐
	vec2 d = (UV - gaze_uv) * vec2(aspect, 1.0);
	float wobble = 1.0 + (value_noise(UV * vec2(5.0, 3.0) + vec2(TIME * 0.015, 0.0)) - 0.5) * 0.85;
	float clear = 1.0 - smoothstep(gaze_radius * 0.18, gaze_radius * 1.25, length(d) * wobble);

	// 底边厚：雾从海面起来
	float thick = mix(0.80, 1.00, smoothstep(0.0, 0.90, UV.y));
	// 浓度几乎恒定，结构放在颜色里。
	// 浓度也跟着噪声抖的话，雾薄的地方物体就露出来了——那就糊不住了。
	float density = mix(density_outside, density_inside, clear) * thick;
	float dens = clamp(density, 0.0, 1.0);
	vec3 fog_col = FOG_COL * (0.75 + 0.75 * n);

	COLOR = vec4(mix(scene, fog_col, dens), 1.0);
}