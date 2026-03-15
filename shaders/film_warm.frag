// film_warm.frag  v1  —  Kodak Gold / 期限切れフィルム ゴールデンアワー再現
// Maya Ishikawa — ZootoCam Shader Engine
//
// このシェーダーが再現するもの:
//   「動物園の閉園前の斜光の中で撮った、少し期限切れの Kodak Gold」
//
// 光化学的特性:
//
//   D-min:  極端な暖色床。R >> G > B で D-min を持つ。
//           期限切れフィルムはフォグ (D-min の上昇) が全域に広がる。
//           ハイライトまで僅かにアンバーのフォグが乗る。
//
//   Tone:   低コントラスト + シャドウの浮き上がり (フォグによる)。
//           斜光: ハイライトが非常に強いオレンジに転ぶ。
//
//   Color:  全域オレンジ-アンバー-ゴールド。
//           青チャンネルが強く圧縮 → 空の青さが消える。
//           緑は黄緑に転ぶ (Kodak Gold の緑は黄みがかる)。
//
//   Halation: 非常に強い。アンバー-オレンジが広く滲む。
//             ゴールデンアワーの光源周囲のグロー。
//
//   Grain:  重い。期限切れフィルム → 粒子が凝集し粗くなる。
//           クラスターが大きく、不均一。
//
//   Fog:    期限切れ特有のハイライトフォグ: 明部まで微かにアンバーが乗る。
//
// Uniform layout (film_iso800.frag と同一):
//   u_warmth        → ゴールデン度 (0=普通の暖色, 1=極端な期限切れ感)
//   u_halation_warmth → 0=赤寄り, 1=オレンジ-ゴールド寄り

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
uniform float     u_blue_crush;       // Warm: 非常に強い blue 圧縮
uniform float     u_halation_warmth;  // 0=赤寄り, 1=オレンジ-ゴールド
uniform float     u_grain_size;
uniform float     u_image_width;
uniform float     u_image_height;

out vec4 frag_color;

// ─────────────────────────────────────────────────────────────
// UTILITY
// ─────────────────────────────────────────────────────────────

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// 樽型歪曲 k=0.10 (Kodak QuickSnap と同じ)
vec2 applyBarrel(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return uv + c * r2 * 0.10;
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
// EXPIRED FILM FOG
//
// 期限切れフィルムのフォグ (経年劣化):
//   フィルム乳剤が経年でランダム反応 → 全域に D-min が上昇する。
//   特性: 暖色 (アンバー-オレンジ)、ハイライトにも乗る。
//   量: u_warmth が高いほど強くフォグが乗る。
// ─────────────────────────────────────────────────────────────

vec3 applyExpiredFog(vec3 c, float warmth) {
    // フォグは露光に依らず全域に乗る (均一な暖色霞)
    float fogStrength = warmth * 0.035;
    vec3 fog = vec3(
        fogStrength * 1.00,   // R: フォグが最も赤-アンバー寄り
        fogStrength * 0.55,   // G
        fogStrength * 0.12    // B: フォグのblueは少ない
    );
    return clamp(c + fog, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// WARM TONE CURVE
//
// 期限切れ Kodak Gold の特性曲線:
//   D-min: R >> G > B の極端な暖色床
//          写ルんですより更に強いアンバーフロア
//          期限切れ → フォグによるシャドウ浮き
//   Shoulder: 低コントラスト気味
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

vec3 applyFilmCurve(vec3 c, float sl, float hr, float contrast, float warmth) {
    // D-min: Warm → R が極端に高い (期限切れアンバー)
    // warmth が高いほど D-min のアンバー差が拡大
    float rDmin = 0.058 + warmth * 0.022;   // R: 0.058-0.080
    float gDmin = 0.024 + warmth * 0.008;   // G: 0.024-0.032
    float bDmin = 0.008 + warmth * 0.003;   // B: 0.008-0.011

    float r = filmToe(c.r, sl * 1.40, rDmin);  // R: 最も強いリフト
    float g = filmToe(c.g, sl * 0.90, gDmin);
    float b = filmToe(c.b, sl * 0.45, bDmin);  // B: 最も少ない

    // Shoulder: 低コントラスト (期限切れは軟調)
    r = filmShoulder(r, 0.62 - hr * 0.10, 1.2 + hr * 0.8, 0.968);
    g = filmShoulder(g, 0.65 - hr * 0.08, 1.3 + hr * 0.75, 0.952);
    b = filmShoulder(b, 0.68 - hr * 0.06, 1.4 + hr * 0.7,  0.930);

    vec3 cv = vec3(r, g, b);
    // コントラスト: 期限切れは低コントラスト気味 (contrast を少し引く)
    cv = (cv - 0.42) * (1.0 + (contrast - 0.06) * 0.30) + 0.42;
    return clamp(cv, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// GOLDEN 3-ZONE COLOR SPLIT
//
// 全域がゴールデン-オレンジ-アンバーに転ぶ。
// 青チャンネルが全域で強く圧縮される。
// 緑は黄緑 → 黄色に転ぶ (Kodak Gold の緑)。
// ─────────────────────────────────────────────────────────────

vec3 applyColorSplit(vec3 c, float warmth) {
    float l = luma(c);

    float shadowMask    = 1.0 - smoothstep(0.00, 0.40, l);
    float highlightMask = smoothstep(0.55, 1.00, l);
    float midMask       = 1.0 - shadowMask - highlightMask;

    // シャドウ: 濃いアンバー-オレンジ (ゴールデンアワーの暗部)
    float sr =  warmth * 0.055 * shadowMask;   // 赤強い
    float sg =  warmth * 0.018 * shadowMask;   // 緑少し
    float sb = -warmth * 0.065 * shadowMask;   // 青強く引く

    // ミッドトーン: ゴールデン-黄色 (斜光の中間域)
    float mr =  warmth * 0.048 * midMask;
    float mg =  warmth * 0.022 * midMask;      // 緑 → 黄緑寄り
    float mb = -warmth * 0.058 * midMask;

    // ハイライト: オレンジ-クリーム (飽和した太陽光)
    float hr =  warmth * 0.042 * highlightMask;
    float hg =  warmth * 0.016 * highlightMask;
    float hb = -warmth * 0.060 * highlightMask;

    c.r = clamp(c.r + sr + mr + hr, 0.0, 1.0);
    c.g = clamp(c.g + sg + mg + hg, 0.0, 1.0);
    c.b = clamp(c.b + sb + mb + hb, 0.0, 1.0);
    return c;
}

// ─────────────────────────────────────────────────────────────
// STRONG BLUE CRUSH
//
// ゴールデンアワー + 期限切れ: 青が全域で強く沈む。
// 空の青さが橙色に転ぶ。青い動物の羽根が暗く沈む。
// ─────────────────────────────────────────────────────────────

vec3 applyBlueCrush(vec3 c, float amount) {
    float l = luma(c);
    // Warm: 全域強め (ISO800 の写ルんですより均等な blue 圧縮)
    float crush = amount * (0.60 + (1.0 - smoothstep(0.0, 0.65, l)) * 0.40);
    c.b = clamp(c.b * (1.0 - crush), 0.0, 1.0);
    return c;
}

// ─────────────────────────────────────────────────────────────
// GOLDEN MILKY HIGHLIGHTS
//
// 斜光下のハイライトはクリーム色をさらに超えた
// 「オレンジ-ゴールド」に転ぶ。
// 白い動物が金色に見える: ホッキョクグマが琥珀色に。
// ─────────────────────────────────────────────────────────────

vec3 applyMilkyHighlights(vec3 c, float amount, float warmth) {
    float l = luma(c);
    float mask = smoothstep(0.48, 0.96, l);
    // ゴールデンアワーのハイライト: オレンジ-クリーム
    vec3 goldenCream = vec3(
        0.985,                            // R: 非常に高い
        0.958 - warmth * 0.020,           // G: warmth で少し引く
        0.888 - warmth * 0.040            // B: 強く引く → 琥珀
    );
    return mix(c, goldenCream, mask * amount * 0.65);
}

// ─────────────────────────────────────────────────────────────
// GREEN → YELLOW SHIFT
//
// Kodak Gold の緑は黄色寄り。ゴールデンアワーでさらに強調。
// 動物の緑がかった毛並み / 草木が黄色に転ぶ。
// ─────────────────────────────────────────────────────────────

vec3 applyGreenYellow(vec3 c, float warmth) {
    float l = luma(c);
    // 緑が多い領域を検出 (g > r かつ g > b)
    float greenness = clamp((c.g - max(c.r, c.b)) * 3.0, 0.0, 1.0);
    // 中間輝度帯で強い (葉っぱ・草など)
    float midRange = 1.0 - smoothstep(0.25, 0.75, abs(l - 0.45) * 2.0);
    float shift = warmth * greenness * midRange;
    // 緑 → 黄: R を上げ、B を下げ
    c.r = clamp(c.r + shift * 0.028, 0.0, 1.0);
    c.b = clamp(c.b - shift * 0.022, 0.0, 1.0);
    return c;
}

vec3 applySaturation(vec3 c, float sat) {
    return mix(vec3(luma(c)), c, sat);
}

// ─────────────────────────────────────────────────────────────
// LENS SAMPLE  —  ゴールデンアワーの大気ハザ
//
// 斜光下では大気の霞が周辺ソフトネスを強調する。
// 色収差も暖色光源で赤寄りにシフト。
// ─────────────────────────────────────────────────────────────

vec3 sampleLens(vec2 uv) {
    vec2 texel      = 1.0 / u_size;
    vec2 fromCenter = uv - 0.5;
    float edgeDist  = length(fromCenter);

    // ゴールデンアワー: 中央付近から滲み始める (haze 効果)
    float edge       = smoothstep(0.08, 0.82, edgeDist * 1.40);
    float blurRadius = edge * u_softness * 3.2;  // Kodak より強め
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

    // 色収差: ゴールデンアワーの赤外光で赤チャンネルがより外側へ
    float ca    = edgeDist * edgeDist * u_chromatic_aberration * 0.030;
    vec2  caDir = normalize(fromCenter + vec2(0.0001)) * ca;

    vec3 chroma;
    chroma.r = texture(u_texture, coverUV(uv + caDir * 1.15)).r;  // 赤: より外側
    chroma.g = soft.g;
    chroma.b = texture(u_texture, coverUV(uv - caDir * 0.45)).b;  // 青: 少し内側

    float chromaBlend = clamp(u_chromatic_aberration * 0.65 + edge * 0.55, 0.0, 1.0);
    return mix(soft, chroma, chromaBlend);
}

// ─────────────────────────────────────────────────────────────
// GOLDEN HALATION  —  強烈なアンバー-ゴールドのグロー
//
// ゴールデンアワーの斜光 + 期限切れフィルムの組み合わせ:
//   ハレーションが非常に広く強く出る。
//   色: オレンジ-ゴールド-アンバー (u_halation_warmth で調整)
//
// チャンネル別散乱:
//   R: spread × 1.00 (赤外光: 最広)
//   G: spread × 0.75 (黄-橙に寄与)
//   B: spread × 0.15 (ほぼなし)
// ─────────────────────────────────────────────────────────────

vec3 applyHalation(vec3 c, vec2 uv) {
    float baseLuma   = luma(c);
    float brightMask = smoothstep(0.62, 0.95, baseLuma) * u_halation_strength;
    if (brightMask < 0.003) return c;

    vec2  texel      = 1.0 / u_size;
    float baseSpread = 5.0 + u_halation_strength * 7.0;  // Kodak より広い
    float spreadR    = baseSpread * 1.00;
    float spreadG    = baseSpread * 0.75;

    float rBleed = 0.0, gBleed = 0.0, totalW = 0.0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            float w = exp(-float(dx*dx + dy*dy) * 0.25);
            totalW += w;

            vec2 offR = vec2(float(dx), float(dy)) * texel * spreadR;
            vec3 scR  = texture(u_texture, coverUV(uv + offR)).rgb;
            float bwR = smoothstep(0.58, 1.0, luma(scR)) * w;
            rBleed   += scR.r * bwR;

            vec2 offG = vec2(float(dx), float(dy)) * texel * spreadG;
            vec3 scG  = texture(u_texture, coverUV(uv + offG)).rgb;
            float bwG = smoothstep(0.58, 1.0, luma(scG)) * w;
            gBleed   += scG.g * bwG;
        }
    }
    float norm = totalW > 0.0 ? 1.0 / totalW : 0.0;
    rBleed *= norm;
    gBleed *= norm;

    // アンバー-ゴールドのグロー (u_halation_warmth: 0=オレンジ赤, 1=ゴールド)
    float gold = u_halation_warmth;
    vec3 glow = vec3(
        rBleed * (0.28 + gold * 0.08),           // R: 常に強い
        gBleed * (0.12 + gold * 0.25),           // G: gold が高いとより黄色
        0.0
    );
    return clamp(c + glow * brightMask * 1.2, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// VIGNETTE  —  深いビネット (ゴールデンアワーの周辺暗化)
// ─────────────────────────────────────────────────────────────

float applyVignette(vec2 uv) {
    vec2 c = uv - 0.5;
    float e2 = dot(c * vec2(1.16, 0.86), c * vec2(1.16, 0.86));
    float v    = u_vignette_strength;
    float soft = smoothstep(0.16, 0.80, e2 / max(v * 0.26 + 0.001, 0.001));
    float hard = smoothstep(0.12, 0.96, e2 / max(v * 0.42 + 0.001, 0.001));
    float dark = soft * 0.55 + hard * 0.45;
    return clamp(1.0 - dark * v * 0.95, 0.04, 1.0);
}

// ─────────────────────────────────────────────────────────────
// EXPIRED GRAIN  —  期限切れフィルムの粗大粒子
//
// 経年劣化したフィルム乳剤:
//   銀ハロゲン化物が不均一に凝集 → 大きなクラスター。
//   個別粒子の不規則性が増す。
//   色素カプラーの劣化 → チャンネル間の独立性がやや低下。
//   全体的に重い、ざらついた質感。
// ─────────────────────────────────────────────────────────────

vec3 applyFilmGrain(vec3 c, vec2 uv, float time, float warmth) {
    float l   = luma(c);
    float frm = floor(time * 12.0);

    vec2  px = uv * u_size;

    // 粗粒子クラスター (期限切れ: 大きなクラスター × 3.2)
    float coarseScale = max(u_grain_size * 3.2, 1.0);
    vec2  coarseUV    = px / coarseScale;
    float clump = valueNoise(coarseUV + vec2(frm * 0.07, 5.31));
    clump       = valueNoise(vec2(clump * 4.2 + frm * 0.04, coarseUV.y * 0.5 + 2.1));
    clump       = pow(clump, 0.72);

    // グレインセル + スパークル (float-only, 期限切れ: セル × 1.2 大きめ)
    float gs     = max(u_grain_size * 1.2, 1.0);
    vec2  gcoord = floor(px / gs);
    float gr = grainSample(gcoord, 0.0, frm);
    float gg = grainSample(gcoord, 1.0, frm);
    float gb = grainSample(gcoord, 2.0, frm);

    vec2  scoord = floor(px / max(gs * 0.5, 1.0));
    float sr = grainSample(scoord, 3.0, frm);
    float sg = grainSample(scoord, 4.0, frm);
    float sb = grainSample(scoord, 5.0, frm);

    float lumaSq     = l * l;
    float strength   = u_grain_amount * mix(0.105, 0.028, lumaSq);
    float sparkleStr = u_grain_amount * 0.026;
    float clumpMod   = 0.30 + clump * 1.40;
    float rBoost     = 1.0 + warmth * 0.12;

    c.r = clamp(c.r + gr * strength * clumpMod * rBoost + sr * sparkleStr,        0.0, 1.0);
    c.g = clamp(c.g + gg * strength * clumpMod * 0.88   + sg * sparkleStr * 0.82, 0.0, 1.0);
    c.b = clamp(c.b + gb * strength * clumpMod * 0.75   + sb * sparkleStr * 0.68, 0.0, 1.0);
    return c;
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv        = fragCoord / u_size;
    uv.y           = 1.0 - uv.y;

    // 1. レンズサンプル (大気ハザ + 赤寄り色収差)
    vec3 color = sampleLens(uv);

    // 2. 期限切れフォグ (全域アンバー霞 — 曲線前に乗せる)
    color = applyExpiredFog(color, u_warmth);

    // 3. フィルム特性曲線 (極端アンバー床 + 低コントラスト)
    color = applyFilmCurve(color, u_shadow_lift, u_highlight_rolloff, u_contrast, u_warmth);

    // 4. 強 Blue 圧縮 (ゴールデンアワーの青消失)
    color = applyBlueCrush(color, u_blue_crush);

    // 5. 緑 → 黄緑シフト (Kodak Gold の黄みがかった緑)
    color = applyGreenYellow(color, u_warmth);

    // 6. 3ゾーン カラースプリット (全域ゴールデン-オレンジ)
    color = applyColorSplit(color, u_warmth);

    // 7. ゴールデンハイライト (白が琥珀色に)
    color = applyMilkyHighlights(color, u_milky_highlights, u_warmth);

    // 8. 彩度 (暖色は高く、青は沈む)
    color = applySaturation(color, u_saturation);

    // 9. 強烈なハレーション (アンバー-ゴールドのグロー)
    color = applyHalation(color, uv);

    // 10. ビネット (深め)
    color *= applyVignette(uv);

    // 11. 期限切れグレイン (粗大クラスター + 暖色偏り)
    color = applyFilmGrain(color, uv, u_time, u_warmth);

    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
