// film_mono_hp5.frag  v1  —  Ilford HP5 Plus 400 銀塩白黒再現
// Maya Ishikawa — ZootoCam Shader Engine
//
// Ilford HP5 Plus 400 の乳剤特性:
//
//   分光感度: パンクロマティック乳剤。全可視波長に感度を持つ。
//             HP5 の赤感度は比較的高め → 赤が明るく、青が暗め。
//             人物の肌/動物の赤系毛並みが明るく再現される。
//
//   D-min:    無彩色。モノクロフィルムの D-min はニュートラルグレー。
//             ただし印画紙の乳白でわずかに温調 (セレン調色風)。
//
//   Tone:     中高コントラスト。HP5 はシャドウ浮きが良い (D-log range 広い)。
//             Kodak Tri-X より少し軟調。
//
//   Grain:    銀塩グレイン: C41 色素雲と異なる独特の質感。
//             粒子の形が不規則で輝き感 (dye cloud でなく metallic silver)。
//             チャンネルは完全に同じ → カラーノイズなし。
//
//   Halation: 無彩色。赤外光の散乱で輝度ブルームのみ。
//             セレン調色を u_halation_warmth で表現 (0=ニュートラル, 1=温調)。
//
// Uniform 解釈:
//   u_warmth       → 銀色調 (0=ニュートラル, 1=セレン温調)
//   u_saturation   → 無視 (強制モノクロ)
//   u_blue_crush   → 使用しない (モノクロ)
//   u_halation_warmth → セレン/冷調分岐
//   u_milky_highlights → ハイライト乳白化 (印画紙の特性)

#include <flutter/runtime_effect.glsl>

uniform vec2      u_size;
uniform sampler2D u_texture;
uniform float     u_time;
uniform float     u_warmth;
uniform float     u_saturation;   // unused (mono)
uniform float     u_shadow_lift;
uniform float     u_highlight_rolloff;
uniform float     u_grain_amount;
uniform float     u_vignette_strength;
uniform float     u_halation_strength;
uniform float     u_softness;
uniform float     u_chromatic_aberration;  // unused (mono)
uniform float     u_milky_highlights;
uniform float     u_contrast;
uniform float     u_blue_crush;    // unused (mono)
uniform float     u_halation_warmth;  // セレン調色: 0=ニュートラル, 1=温調
uniform float     u_grain_size;
uniform float     u_image_width;
uniform float     u_image_height;

out vec4 frag_color;

// ─────────────────────────────────────────────────────────────
// UTILITY
// ─────────────────────────────────────────────────────────────

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// HP5 パンクロマティック分光変換
// HP5 は赤感度が比較的高め + 青感度が低め
// → 赤い毛並みが明るく、青空が暗く再現される (標準 B&W の特性)
float panchroLuma(vec3 c) {
    // HP5 Plus の分光感度近似 (log sensitivity をリニアに戻したもの)
    // 緑: 最高, 赤: 高め, 青: 最も低い (パンクロの一般的傾向)
    return dot(c, vec3(0.334, 0.556, 0.110));
}

// 軽い樽型歪曲 (K=0.05: HP5 はカメラ依存だが適度な値)
vec2 applyBarrel(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return uv + c * r2 * 0.05;
}

vec2 coverUV(vec2 uv) {
    vec2 d = applyBarrel(uv);
    float ia = u_image_width  / u_image_height;
    float va = u_size.x / u_size.y;
    if (ia > va) return vec2((d.x - 0.5) * (va / ia) + 0.5, d.y);
    else         return vec2(d.x, (d.y - 0.5) * (ia / va) + 0.5);
}

// ─────────────────────────────────────────────────────────────
// NOISE
// ─────────────────────────────────────────────────────────────

// float-only hash — uint 不使用、impellerc safe
float fhash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(
        mix(fhash(i), fhash(i + vec2(1,0)), u.x),
        mix(fhash(i + vec2(0,1)), fhash(i + vec2(1,1)), u.x),
        u.y);
}

float grainSample(vec2 gcoord, float ch, float frm) {
    vec2 s1 = gcoord + vec2(frm * 0.1371,        ch * 17.0);
    vec2 s2 = gcoord + vec2(frm * 0.1371 + 3.71, ch * 17.0 + 5.3);
    return fhash(s1) + fhash(s2) - 1.0;
}

// ─────────────────────────────────────────────────────────────
// SILVER GELATIN TONE CURVE
//
// 銀塩ネガ + 印画紙 の特性曲線はカラー C41 と異なる:
//
//   Toe:      シャドウが非常に緩やかに立ち上がる
//             (ネガ乳剤の D-min + 印画紙の toe の合成)
//   Linear:   広い直線域 (HP5 はラティチュードが広い)
//   Shoulder: ハイライトが急峻に圧縮される (印画紙の D-max)
//
// 追加: 局所コントラスト強調 (印画紙現像の局所 micro-contrast)
// ─────────────────────────────────────────────────────────────

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

float applyMonoCurve(float x, float sl, float hr, float contrast) {
    // D-min: モノクロは全チャンネル同一 (印画紙のニュートラル最小濃度)
    float y = filmToe(x, sl * 0.90, 0.025);
    // Shoulder: モノクロ印画紙は急峻 (ハイライトが飛びやすい)
    y = filmShoulder(y, 0.64 - hr * 0.08, 1.6 + hr * 1.2, 0.970);
    // コントラスト
    y = (y - 0.42) * (1.0 + contrast * 0.40) + 0.42;
    return clamp(y, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// LENS SAMPLE (モノクロ: 色収差なし)
// ─────────────────────────────────────────────────────────────

vec3 sampleLens(vec2 uv) {
    vec2 texel     = 1.0 / u_size;
    vec2 fromCenter = uv - 0.5;
    float edgeDist  = length(fromCenter);

    float edge       = smoothstep(0.10, 0.85, edgeDist * 1.40);
    float blurRadius = edge * u_softness * 2.6;
    vec2  bOff       = texel * blurRadius;

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

    // モノクロ: 色収差なし (u_chromatic_aberration は無視)
    return soft;
}

// ─────────────────────────────────────────────────────────────
// SILVER HALATION  —  赤外散乱 + セレン調色
//
// モノクロフィルムのハレーション:
//   赤外光の散乱 → 輝度ブルームのみ。色はなし。
//   セレン調色 (u_halation_warmth > 0.5) で温調のハイライト滲み。
// ─────────────────────────────────────────────────────────────

float applyHalation(float y, vec2 uv) {
    float brightMask = smoothstep(0.72, 0.98, y) * u_halation_strength;
    if (brightMask < 0.003) return y;

    vec2  texel     = 1.0 / u_size;
    float spread    = 3.5 + u_halation_strength * 4.5;

    float bleed = 0.0, totalW = 0.0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            float w = exp(-float(dx*dx + dy*dy) * 0.28);
            totalW += w;
            vec2 s  = coverUV(uv + vec2(float(dx), float(dy)) * texel * spread);
            float sl = panchroLuma(texture(u_texture, s).rgb);
            float bw = smoothstep(0.65, 1.0, sl) * w;
            bleed   += sl * bw;
        }
    }
    float norm  = totalW > 0.0 ? 1.0 / totalW : 0.0;
    bleed      *= norm;

    float glow = bleed * 0.15 * brightMask;
    return clamp(y + glow, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// HIGHLIGHT  —  印画紙の最大濃度 (乳白ハイライト)
// ─────────────────────────────────────────────────────────────

float applyHighlight(float y, float amount) {
    float mask = smoothstep(0.60, 0.98, y);
    // 印画紙: ハイライトがわずかにクリーム/温調
    float warmHighlight = 0.972;
    return mix(y, warmHighlight, mask * amount * 0.35);
}

// ─────────────────────────────────────────────────────────────
// VIGNETTE
// ─────────────────────────────────────────────────────────────

float applyVignette(vec2 uv) {
    vec2 c = uv - 0.5;
    float e2 = dot(c * vec2(1.10, 0.90), c * vec2(1.10, 0.90));
    float v    = u_vignette_strength;
    float soft = smoothstep(0.18, 0.82, e2 / max(v * 0.26 + 0.001, 0.001));
    float hard = smoothstep(0.12, 1.00, e2 / max(v * 0.44 + 0.001, 0.001));
    float dark = soft * 0.54 + hard * 0.46;
    return clamp(1.0 - dark * v * 0.92, 0.04, 1.0);
}

// ─────────────────────────────────────────────────────────────
// SILVER GRAIN  —  銀塩グレイン
//
// HP5 Plus 400 の銀塩粒子:
//   C41 の色素雲グレインと異なる「金属銀」の輝き感。
//   チャンネル完全同一: カラーノイズは一切発生しない。
//   ただし粒子の輝度変動は C41 より強い (metallic reflection)。
//
//   粒子サイズ: ISO400 → ISO800 より細かい
//   クラスター: 銀塩はより均等 (C41 の色素雲より拡散)
//   スパークル: 金属銀特有の高周波輝き (ISO800 より強め)
// ─────────────────────────────────────────────────────────────

float applyMonoGrain(float y, vec2 uv, float time) {
    float frm = floor(time * 12.0);
    vec2  px  = uv * u_size;

    // 粗粒子クラスター (銀塩: 均等寄り × 2.0)
    float coarseScale = max(u_grain_size * 2.0, 1.0);
    vec2  coarseUV    = px / coarseScale;
    float clump = valueNoise(coarseUV + vec2(frm * 0.07, 5.31));
    clump       = valueNoise(vec2(clump * 3.0 + frm * 0.04, coarseUV.y * 0.65 + 2.1));
    clump       = pow(clump, 0.45);

    // グレインセル + スパークル (float-only)
    float gs       = max(u_grain_size, 1.0);
    vec2  gcoord   = floor(px / gs);
    float gFine    = grainSample(gcoord, 0.0, frm);
    float gSparkle = grainSample(floor(px / max(u_grain_size * 0.5, 1.0)), 1.0, frm);

    float lumaSq     = y * y;
    float strength   = u_grain_amount * mix(0.095, 0.025, lumaSq);
    float sparkleStr = u_grain_amount * 0.026;
    float clumpMod   = 0.38 + clump * 1.24;

    return clamp(y + gFine * strength * clumpMod + gSparkle * sparkleStr, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// TONE TINTING  —  セレン調色 / 冷調
//
// セレン調色 (selenium toning): 銀粒子がセレン化銀に変わり、
// 画像がわずかに赤紫-暖調になる。長期保存性が増す処理。
// 印画紙を冷調現像 (グリセン現像液) すると逆に青みがかる。
//
// u_halation_warmth: 0.0 = 冷調(青), 0.5 = ニュートラル, 1.0 = セレン温調
// ─────────────────────────────────────────────────────────────

vec3 applyToning(float y, float warmth) {
    // ニュートラルグレー基準
    vec3 neutral = vec3(y);

    // セレン温調 (u_halation_warmth → warmth ≈ 1.0)
    vec3 seleniumTone = vec3(
        y * 1.02 + 0.006,   // R: わずかに暖
        y * 0.99 + 0.001,   // G: ほぼ同じ
        y * 0.96 - 0.003    // B: わずかに引く
    );

    // 冷調 (warmth ≈ 0.0)
    vec3 coolTone = vec3(
        y * 0.96 - 0.004,   // R: わずかに引く
        y * 0.99 + 0.002,   // G: ほぼ同じ
        y * 1.03 + 0.008    // B: わずかに上げる
    );

    if (warmth >= 0.5) {
        return mix(neutral, seleniumTone, (warmth - 0.5) * 2.0 * 0.45);
    } else {
        return mix(neutral, coolTone, (0.5 - warmth) * 2.0 * 0.35);
    }
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv        = fragCoord / u_size;
    uv.y           = 1.0 - uv.y;

    // 1. レンズサンプル (ソフトネスのみ, 色収差なし)
    vec3 rgb = sampleLens(uv);

    // 2. パンクロマティック変換 → 輝度値
    float y = panchroLuma(rgb);

    // 3. 銀塩トーンカーブ (Toe + Linear + Shoulder)
    y = applyMonoCurve(y, u_shadow_lift, u_highlight_rolloff, u_contrast);

    // 4. ハイライト乳白化 (印画紙の D-max 特性)
    y = applyHighlight(y, u_milky_highlights);

    // 5. ハレーション (輝度ブルームのみ)
    y = applyHalation(y, uv);

    // 6. ビネット
    y *= applyVignette(uv);

    // 7. 銀塩グレイン (全チャンネル同一 + 高周波スパークル)
    y = applyMonoGrain(y, uv, u_time);

    // 8. 色調 (セレン/冷調) + warmth による微妙な銀色
    vec3 color = applyToning(y, u_halation_warmth);

    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
