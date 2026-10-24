shader_type spatial;
// Arena geometry: vertex colour times a pattern drawn in world space, so the meshes need no
// textures. UV.x picks the pattern (0 plain, 1 floor tiles, 2 bricks, 3 metal panels, 4 rock,
// 5 planks, 6 brass filigree, 7 marble, 8 oil-slick metal), UV.y scales it.
render_mode cull_back;

uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.1) * 0.3 + noise(p * 4.3 + 7.7) * 0.15;
}

// distance to the nearest grid line of a grid with cells of size s
float grid(vec2 p, vec2 s) {
	vec2 f = abs(fract(p / s) - 0.5) * s;
	return min(s.x * 0.5 - f.x, s.y * 0.5 - f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 p = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	int pat = int(UV.x + 0.5);
	float sc = max(UV.y, 0.05);
	p /= sc;
	float shade = 1.0;
	float rough = 0.8;
	float metal = 0.0;
	if (pat == 1) {
		float d = grid(p, vec2(2.0));
		vec2 cell = floor(p / 2.0);
		shade = mix(0.55, 1.0, smoothstep(0.02, 0.07, d)) * (0.9 + 0.12 * hash(cell));
		shade *= 0.92 + 0.08 * noise(p * 3.0);
		rough = 0.6;
	} else if (pat == 2) {
		float row = floor(p.y / 0.5);
		vec2 q = vec2(p.x + mod(row, 2.0) * 0.6, p.y);
		float d = grid(q, vec2(1.2, 0.5));
		shade = mix(0.5, 1.0, smoothstep(0.015, 0.05, d)) * (0.85 + 0.2 * hash(floor(q / vec2(1.2, 0.5))));
		shade *= 0.9 + 0.1 * noise(p * 6.0);
	} else if (pat == 3) {
		float d = grid(p, vec2(2.0, 1.0));
		vec2 f = fract(p / vec2(2.0, 1.0)) * vec2(2.0, 1.0);
		float rivet = 0.0;
		vec2 rc = min(f, vec2(2.0, 1.0) - f);
		rivet = 1.0 - smoothstep(0.03, 0.05, length(rc - vec2(0.12)));
		shade = mix(0.6, 1.0, smoothstep(0.01, 0.04, d)) * (0.92 + 0.1 * hash(floor(p / vec2(2.0, 1.0)))) + rivet * 0.3;
		shade *= 0.9 + 0.1 * noise(p * 1.5);
		rough = 0.45;
		metal = 0.55;
	} else if (pat == 4) {
		shade = 0.7 + 0.45 * fbm(p * 0.9);
		shade *= 0.85 + 0.2 * noise(p * 5.0);
		rough = 0.95;
	} else if (pat == 5) {
		float d = abs(fract(p.x / 0.35) - 0.5) * 0.35;
		shade = mix(0.6, 1.0, smoothstep(0.0, 0.025, 0.175 - d)) * (0.88 + 0.14 * hash(vec2(floor(p.x / 0.35), floor(p.y / 2.4 + hash(vec2(floor(p.x / 0.35), 1.0))))));
		shade *= 0.9 + 0.12 * noise(vec2(p.x * 12.0, p.y * 0.8));
		rough = 0.7;
	} else if (pat == 6) {
		float s = sin(p.x * 2.4 + sin(p.y * 1.6) * 2.0) * sin(p.y * 2.4 + sin(p.x * 1.6) * 2.0);
		shade = 0.75 + 0.3 * smoothstep(0.55, 0.75, abs(s));
		shade *= 0.92 + 0.1 * noise(p * 2.0);
		rough = 0.35;
		metal = 0.8;
	} else if (pat == 7) {
		float v = abs(sin(p.x * 1.3 + fbm(p * 0.7) * 6.0));
		shade = 0.82 + 0.18 * smoothstep(0.0, 0.25, v) - 0.08 * fbm(p * 2.0);
		float d = grid(p, vec2(3.0));
		shade *= mix(0.7, 1.0, smoothstep(0.01, 0.04, d));
		rough = 0.25;
	} else if (pat == 8) {
		float d = grid(p, vec2(3.0, 1.5));
		shade = mix(0.5, 1.0, smoothstep(0.02, 0.06, d)) * (0.75 + 0.35 * fbm(p * 0.6));
		rough = 0.3;
		metal = 0.6;
	} else {
		shade = 0.92 + 0.1 * noise(p * 2.0);
	}
	// large-scale grime so big surfaces are not flat
	shade *= mix(1.0, 0.82 + 0.25 * noise(wpos.xz * 0.15 + wpos.y * 0.1), detail);
	ALBEDO = COLOR.rgb * shade;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
}
