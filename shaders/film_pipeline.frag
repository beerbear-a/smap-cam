// film_pipeline.frag - Unified film emulation pipeline (preview/export)
// Parameters map to FilmShaderParams in Dart. Keep uniform order in sync.

#include <flutter/runtime_effect.glsl>

uniform vec2      u_size;
uniform sampler2D u_texture;
uniform float     u_time;
uniform float     u_warmth;
uniform float     u_saturation;
uniform float     u_shadow_lift;
uniform float     u_highlight_rolloff;
uniform float     u_grain_amount;
uniform float     u_vignette_strength;
uniform float     u_halation_strength;
uniform float     u_softness;
uniform float     u_chromatic_aberration;
uniform float     u_milky_highlights;
uniform float     u_contrast;
uniform float     u_blue_crush;
uniform float     u_halation_warmth;
uniform float     u_grain_size;
uniform float     u_image_width;
uniform float     u_image_height;
uniform float     u_distortion;
uniform float     u_shadow_desat;
uniform float     u_color_split;
uniform float     u_crossover;
uniform float     u_bloom_strength;

out vec4 frag_color;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec2 applyBarrel(vec2 uv) {
    vec2 c = uv - 0.5;
    float r2 = dot(c, c);
    return uv + c * r2 * u_distortion;
}

vec2 coverUV(vec2 uv) {
    vec2 distorted = applyBarrel(uv);
    float ia = u_image_width / u_image_height;
    float va = u_size.x / u_size.y;
    if (ia > va) return vec2((distorted.x - 0.5) * (va / ia) + 0.5, distorted.y);
    return vec2(distorted.x, (distorted.y - 0.5) * (ia / va) + 0.5);
}

float fhash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(
        mix(fhash(i), fhash(i + vec2(1, 0)), u.x),
        mix(fhash(i + vec2(0, 1)), fhash(i + vec2(1, 1)), u.x),
        u.y
    );
}

float grainSample(vec2 gcoord, float ch, float frm) {
    vec2 s1 = gcoord + vec2(frm * 0.1371,        ch * 17.0);
    vec2 s2 = gcoord + vec2(frm * 0.1371 + 3.71, ch * 17.0 + 5.3);
    return fhash(s1) + fhash(s2) - 1.0;
}

float filmToe(float x, float lift, float dmin) {
    float floored = max(x, dmin);
    return floored + lift * 0.09 * (1.0 - floored) * (1.0 - floored);
}

float filmShoulder(float x, float start, float rolloff, float cap) {
    float t = clamp((x - start) / max(1.0 - start, 0.001), 0.0, 1.0);
    float curved = 1.0 - pow(max(1.0 - t, 0.0), 1.0 + rolloff * 1.6);
    float shoulder = start + (1.0 - start) * min(curved, cap);
    return mix(x, shoulder, step(start, x));
}

vec3 applyFilmCurve(vec3 c, float sl, float hr, float contrast) {
    float r = filmToe(c.r, sl * 1.20, 0.038);
    float g = filmToe(c.g, sl * 0.82, 0.022);
    float b = filmToe(c.b, sl * 0.48, 0.010);

    r = filmShoulder(r, 0.66 - hr * 0.09, 1.4 + hr * 0.9,  0.958);
    g = filmShoulder(g, 0.69 - hr * 0.07, 1.5 + hr * 0.85, 0.945);
    b = filmShoulder(b, 0.72 - hr * 0.05, 1.6 + hr * 1.0,  0.925);

    vec3 cv = vec3(r, g, b);
    cv = (cv - 0.40) * (1.0 + contrast * 0.30) + 0.40;
    return clamp(cv, 0.0, 1.0);
}

vec3 applyShadowDesaturation(vec3 c, float strength) {
    float l = luma(c);
    float deepShadow = 1.0 - smoothstep(0.04, 0.22, l);
    vec3 monoWarm = vec3(
        l * 0.88 + 0.014,
        l * 0.85 + 0.008,
        l * 0.80 + 0.004
    );
    float amount = clamp(strength, 0.0, 1.0) * 0.70;
    return mix(c, monoWarm, deepShadow * amount);
}

vec3 applyColorSplit(vec3 c, float warmth, float strength) {
    float l = luma(c);
    float shadowMask    = 1.0 - smoothstep(0.00, 0.38, l);
    float highlightMask = smoothstep(0.58, 1.00, l);
    float midMask       = 1.0 - shadowMask - highlightMask;

    float split = clamp(strength, 0.0, 1.0);

    float sg =  0.012 * shadowMask * split;
    float sb =  0.006 * shadowMask * split;
    float sr = -0.004 * shadowMask * split;

    float mr =  warmth * 0.028 * midMask * split;
    float mg =  warmth * 0.010 * midMask * split;
    float mb = -warmth * 0.038 * midMask * split;

    float hr =  warmth * 0.035 * highlightMask * split;
    float hg =  warmth * 0.012 * highlightMask * split;
    float hb = -warmth * 0.050 * highlightMask * split;

    c.r = clamp(c.r + sr + mr + hr, 0.0, 1.0);
    c.g = clamp(c.g + sg + mg + hg, 0.0, 1.0);
    c.b = clamp(c.b + sb + mb + hb, 0.0, 1.0);
    return c;
}

vec3 applyC41GreenCrossover(vec3 c, float amount) {
    float l = luma(c);
    float crossover = smoothstep(0.08, 0.30, l) * (1.0 - smoothstep(0.30, 0.55, l));
    c.g = clamp(c.g + amount * 0.018 * crossover, 0.0, 1.0);
    return c;
}

vec3 applyBlueCrush(vec3 c, float amount) {
    float l = luma(c);
    float crush = amount * (0.55 + (1.0 - smoothstep(0.0, 0.50, l)) * 0.45);
    c.b = clamp(c.b * (1.0 - crush), 0.0, 1.0);
    return c;
}

vec3 applyMilkyHighlights(vec3 c, float amount) {
    float l = luma(c);
    float mask = smoothstep(0.52, 0.97, l);
    vec3 cream = vec3(0.972, 0.958, 0.920);
    return mix(c, cream, mask * amount * 0.55);
}

vec3 applySaturation(vec3 c, float sat) {
    return mix(vec3(luma(c)), c, sat);
}

vec3 sampleLens(vec2 uv) {
    vec2 texel      = 1.0 / u_size;
    vec2 fromCenter = uv - 0.5;
    float edgeDist  = length(fromCenter);

    float edge        = smoothstep(0.12, 0.88, edgeDist * 1.35);
    float blurRadius  = edge * u_softness * 2.8;
    vec2  bOff        = texel * blurRadius;

    vec3 base = texture(u_texture, coverUV(uv)).rgb;
    vec3 soft =
        base * 1.0 +
        texture(u_texture, coverUV(uv + vec2( bOff.x,  0.0))).rgb +
        texture(u_texture, coverUV(uv + vec2(-bOff.x,  0.0))).rgb +
        texture(u_texture, coverUV(uv + vec2( 0.0,  bOff.y))).rgb +
        texture(u_texture, coverUV(uv + vec2( 0.0, -bOff.y))).rgb +
        texture(u_texture, coverUV(uv + bOff               )).rgb * 0.65 +
        texture(u_texture, coverUV(uv - bOff               )).rgb * 0.65 +
        texture(u_texture, coverUV(uv + vec2( bOff.x, -bOff.y))).rgb * 0.65 +
        texture(u_texture, coverUV(uv + vec2(-bOff.x,  bOff.y))).rgb * 0.65;
    soft /= 6.2;

    float ca    = edgeDist * edgeDist * u_chromatic_aberration * 0.026;
    vec2  caDir = normalize(fromCenter + vec2(0.0001)) * ca;

    vec3 chroma;
    chroma.r = texture(u_texture, coverUV(uv + caDir)).r;
    chroma.g = soft.g;
    chroma.b = texture(u_texture, coverUV(uv - caDir * 0.55)).b;

    float chromaBlend = clamp(u_chromatic_aberration * 0.6 + edge * 0.55, 0.0, 1.0);
    return mix(soft, chroma, chromaBlend);
}

vec3 applyHighlightBlooming(vec3 c, vec2 uv, float amount) {
    if (amount <= 0.0) return c;

    float l = luma(c);
    float bloom = smoothstep(0.78, 1.0, l) * amount;
    if (bloom < 0.01) return c;

    vec2 texel = 1.0 / u_size;
    float radius = u_softness * 1.8 + 1.2;

    vec3 blurred =
        texture(u_texture, coverUV(uv + vec2( radius,  0.0) * texel)).rgb +
        texture(u_texture, coverUV(uv + vec2(-radius,  0.0) * texel)).rgb +
        texture(u_texture, coverUV(uv + vec2( 0.0,  radius) * texel)).rgb +
        texture(u_texture, coverUV(uv + vec2( 0.0, -radius) * texel)).rgb;
    blurred /= 4.0;

    blurred.r *= 1.06;
    blurred.b *= 0.92;

    return mix(c, blurred, bloom * 0.28);
}

vec3 applyHalation(vec3 c, vec2 uv) {
    float baseLuma   = luma(c);
    float brightMask = smoothstep(0.68, 0.97, baseLuma) * u_halation_strength;
    if (brightMask < 0.003) return c;

    vec2  texel      = 1.0 / u_size;
    float baseSpread = 4.0 + u_halation_strength * 5.5;
    float spreadR    = baseSpread * 1.00;
    float spreadG    = baseSpread * 0.60;

    float rBleed = 0.0, gBleed = 0.0, totalW = 0.0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            float w = exp(-float(dx*dx + dy*dy) * 0.30);
            totalW += w;

            vec2 offR = vec2(float(dx), float(dy)) * texel * spreadR;
            vec3 scR  = texture(u_texture, coverUV(uv + offR)).rgb;
            float bwR = smoothstep(0.62, 1.0, luma(scR)) * w;
            rBleed   += scR.r * bwR;

            vec2 offG = vec2(float(dx), float(dy)) * texel * spreadG;
            vec3 scG  = texture(u_texture, coverUV(uv + offG)).rgb;
            float bwG = smoothstep(0.62, 1.0, luma(scG)) * w;
            gBleed   += scG.g * bwG * 0.35;
        }
    }
    float norm = totalW > 0.0 ? 1.0 / totalW : 0.0;
    rBleed *= norm;
    gBleed *= norm;

    float amber = u_halation_warmth * 0.4;
    vec3 glow = vec3(
        rBleed * (0.18 + amber * 0.06),
        gBleed * amber,
        0.0
    );
    return clamp(c + glow * brightMask, 0.0, 1.0);
}

float applyVignette(vec2 uv) {
    vec2 c = uv - 0.5;
    float e2 = dot(c * vec2(1.14, 0.88), c * vec2(1.14, 0.88));

    float v     = u_vignette_strength;
    float soft  = smoothstep(0.20, 0.85, e2 / max(v * 0.28 + 0.001, 0.001));
    float hard  = smoothstep(0.15, 1.00, e2 / max(v * 0.46 + 0.001, 0.001));

    float dark  = soft * 0.52 + hard * 0.48;
    return clamp(1.0 - dark * v * 0.90, 0.05, 1.0);
}

vec3 applyFilmGrain(vec3 c, vec2 uv, float time) {
    float l   = luma(c);
    float frm = floor(time * 12.0);

    vec2  px = uv * u_size;

    float coarseScale = max(u_grain_size * 2.8, 1.0);
    vec2  coarseUV    = px / coarseScale;
    float clump = valueNoise(coarseUV + vec2(frm * 0.07, 5.31));
    clump       = valueNoise(vec2(clump * 3.7 + frm * 0.04, coarseUV.y * 0.6 + 2.1));
    clump       = pow(clump, 0.60);

    float gs     = max(u_grain_size, 1.0);
    vec2  gcoord = floor(px / gs);
    float gr = grainSample(gcoord, 0.0, frm);
    float gg = grainSample(gcoord, 1.0, frm);
    float gb = grainSample(gcoord, 2.0, frm);

    vec2  scoord = floor(px / max(u_grain_size * 0.5, 1.0));
    float sr = grainSample(scoord, 3.0, frm);
    float sg = grainSample(scoord, 4.0, frm);
    float sb = grainSample(scoord, 5.0, frm);

    float lumaSq     = l * l;
    float strength   = u_grain_amount * mix(0.090, 0.022, lumaSq);
    float sparkleStr = u_grain_amount * 0.021;
    float clumpMod   = 0.35 + clump * 1.30;

    c.r = clamp(c.r + gr * strength * clumpMod * 1.00 + sr * sparkleStr,        0.0, 1.0);
    c.g = clamp(c.g + gg * strength * clumpMod * 0.91 + sg * sparkleStr * 0.88, 0.0, 1.0);
    c.b = clamp(c.b + gb * strength * clumpMod * 0.84 + sb * sparkleStr * 0.75, 0.0, 1.0);
    return c;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv        = fragCoord / u_size;
    uv.y           = 1.0 - uv.y;

    vec3 color = sampleLens(uv);

    color = applyFilmCurve(color, u_shadow_lift, u_highlight_rolloff, u_contrast);
    color = applyShadowDesaturation(color, u_shadow_desat);
    color = applyC41GreenCrossover(color, u_crossover);
    color = applyBlueCrush(color, u_blue_crush);
    color = applyColorSplit(color, u_warmth, u_color_split);
    color = applyMilkyHighlights(color, u_milky_highlights);
    color = applySaturation(color, u_saturation);

    color = applyHighlightBlooming(color, uv, u_bloom_strength);
    color = applyHalation(color, uv);
    color *= applyVignette(uv);
    color = applyFilmGrain(color, uv, u_time);

    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
