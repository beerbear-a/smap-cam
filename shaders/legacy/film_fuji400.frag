// film_fuji400.frag  v2  —  Fujifilm Superia 400 C41 光化学再現（VSCO+Dazz強化）
// Maya Ishikawa — ZootoCam Shader Engine
//
// Fujifilm Superia 400 の乳剤特性 (Kodak ISO800 との対比):
//
//   D-min: G > B > R の順で暗部が持ち上がる → シャドウに緑-シアン床
//          (Kodak のアンバー床とは逆)
//
//   Tone:  よりリニアな中間域。ハイライトがクリーンに飛ぶ。
//          Kodak の「乳白ハイライト」は少なく、白に近い。
//
//   Color: 彩度高め・緑が鮮やか・青チャンネルが生きている。
//          Fuji の「ビビッドな緑」は動物の毛並みや植物で顕著。
//
//   Crossover: Fuji 緑感光層は Kodak とは異なる帯域でシャドウに乗る。
//              より浅いシャドウ帯で強く、深いシャドウでは逆に引く。
//
//   Halation:  少ない（反ハレーション層が優秀）。
//              発生時: 青-紫 寄り（長波長を通す Kodak と逆）。
//
//   Barrel:    k=0.06（Kodak QuickSnap の 0.08 より小さい）。
//
// Uniform layout (film_iso800.frag と同一):
//   0,1:u_size  2:u_time  3:u_warmth  4:u_saturation
//   5:u_shadow_lift  6:u_highlight_rolloff  7:u_grain_amount
//   8:u_vignette_strength  9:u_halation_strength  10:u_softness
//   11:u_chromatic_aberration  12:u_milky_highlights  13:u_contrast
//   14:u_blue_crush (Fuji: これは blue BOOST として解釈)
//   15:u_halation_warmth (Fuji: 0=青, 1=中性)
//   16:u_grain_size  17:u_image_width  18:u_image_height

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
uniform float     u_blue_crush;   // Fuji: blue_boost (値が小さいほど blue を守る)
uniform float     u_halation_warmth;
uniform float     u_grain_size;
uniform float     u_image_width;
uniform float     u_image_height;

out vec4 frag_color;

// ─────────────────────────────────────────────────────────────
// UTILITY
// ─────────────────────────────────────────────────────────────

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// Fuji 固有: Fujifilm の分光感度特性（緑を少し重く）
float fujiLuma(vec3 c) { return dot(c, vec3(0.268, 0.614, 0.118)); }

// 樽型歪曲 k=0.06 (Kodak 0.08 より少し穏やか)
vec2 applyBarrel(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return uv + c * r2 * 0.06;
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
// FUJI TONE CURVE
//
// Fuji Superia 400 の乳剤特性曲線:
//   D-min (暗部床): G > B > R の順 → シアン-緑床
//   Linear region: Kodak より広い (露出宽容度が高い)
//   Shoulder: Kodak より急峻 → ハイライトがクリーンに飛ぶ
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

// Fuji D-min: G > B > R (逆アンバー = シアン床)
// Fuji shoulder: より急峻な肩 → クリーンなハイライト
vec3 applyFilmCurve(vec3 c, float sl, float hr, float contrast) {
    // D-min: Fuji のシャドウ床はシアン-緑 (Kodak のアンバーと逆)
    // v2: VSCO 相当の faded 黒を出すため D-min を 3× に引き上げ
    float r = filmToe(c.r, sl * 0.55, 0.038);   // R: 0.012 → 0.038 (暗部でRが沈む)
    float g = filmToe(c.g, sl * 1.10, 0.095);   // G: 0.035 → 0.095 (暗部で緑-シアン)
    float b = filmToe(c.b, sl * 0.85, 0.072);   // B: 0.026 → 0.072 (シアン成分)

    // Shoulder: Fuji は Kodak より急峻な肩 → クリーンな白
    // cap を高めに設定 (0.982, 0.975, 0.968) → クリーンな白に近い
    r = filmShoulder(r, 0.70 - hr * 0.06, 1.8 + hr * 0.8,  0.982);
    g = filmShoulder(g, 0.71 - hr * 0.05, 1.9 + hr * 0.75, 0.975);
    b = filmShoulder(b, 0.72 - hr * 0.04, 2.0 + hr * 0.7,  0.968);

    vec3 cv = vec3(r, g, b);
    cv = (cv - 0.40) * (1.0 + contrast * 0.30) + 0.40;
    return clamp(cv, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// FUJI SHADOW DESATURATION
//
// Fuji のシャドウはシアン床を持つが、極端な暗部では
// やはり色素形成が不完全。ただし Kodak より浅い帯域で。
// ─────────────────────────────────────────────────────────────

vec3 applyShadowDesaturation(vec3 c) {
    float l = luma(c);
    // Fuji: やや浅い帯域 (0.02-0.18) → Kodak より早く通常色に戻る
    float deepShadow = 1.0 - smoothstep(0.02, 0.18, l);
    // シアン寄りのモノクローム: B > G > R
    vec3 monoFuji = vec3(
        l * 0.78 + 0.008,   // R: 最も低め (シアン床)
        l * 0.87 + 0.020,   // G: 高め
        l * 0.84 + 0.016    // B: やや高め
    );
    return mix(c, monoFuji, deepShadow * 0.62);
}

// ─────────────────────────────────────────────────────────────
// FUJI 3-ZONE COLOR SPLIT
//
// Fuji Superia の特徴的な色分布:
//   シャドウ: シアン-緑 (Fuji の「青みがかった影」)
//   ミッドトーン: わずかにクール → ニュートラル
//   ハイライト: クリーン白 (Kodak の乳白とは異なる)
// ─────────────────────────────────────────────────────────────

vec3 applyColorSplit(vec3 c, float warmth) {
    float l = luma(c);

    float shadowMask    = 1.0 - smoothstep(0.00, 0.35, l);
    float highlightMask = smoothstep(0.62, 1.00, l);
    float midMask       = 1.0 - shadowMask - highlightMask;

    // シャドウ: シアン-緑 (warmth が低いほど強くシアン寄り)
    // v2: VSCO Film 400H 相当のシアンシャドウに強化
    float coolness = 1.0 - warmth;
    float sg =  coolness * 0.032 * shadowMask;   // 0.022 → 0.032 green 上げ
    float sb =  coolness * 0.028 * shadowMask;   // 0.018 → 0.028 blue 上げ (シアン)
    float sr = -coolness * 0.016 * shadowMask;   // 0.010 → 0.016 red 下げ

    // ミッドトーン: わずかにクール (warmth=0で最もクール)
    float mr = -coolness * 0.012 * midMask;      // 0.008 → 0.012
    float mg =  coolness * 0.008 * midMask;      // 0.005 → 0.008
    float mb =  coolness * 0.015 * midMask;      // 0.010 → 0.015

    // ハイライト: クリーン → warmth が高いと少し暖色に
    float hr =  warmth * 0.012 * highlightMask;
    float hg =  warmth * 0.005 * highlightMask;
    float hb = -warmth * 0.008 * highlightMask;

    c.r = clamp(c.r + sr + mr + hr, 0.0, 1.0);
    c.g = clamp(c.g + sg + mg + hg, 0.0, 1.0);
    c.b = clamp(c.b + sb + mb + hb, 0.0, 1.0);
    return c;
}

// ─────────────────────────────────────────────────────────────
// FUJI GREEN CROSSOVER
//
// Fuji の緑感光層クロスオーバー: Kodak と異なり、
// より浅いシャドウ帯 (0.05-0.35) で強くなり、
// 深いシャドウでは逆に冷える（シアンに転ぶ）。
// これが「Fuji の緑が生き生きしている」理由。
// ─────────────────────────────────────────────────────────────

vec3 applyFujiGreenCrossover(vec3 c, float amount) {
    float l = luma(c);
    // Fuji 緑クロスオーバー: 0.05-0.40 帯（Kodak の 0.08-0.55 より浅い）
    // v2: crossover 帯域を広げ + 係数強化 → Dazz の「Fuji グリーン」感
    float crossover = smoothstep(0.05, 0.22, l) * (1.0 - smoothstep(0.22, 0.48, l));
    // 緑をリフト + 青をわずかに + 赤を引く → Fuji の「酸っぱいシアン-緑」
    c.g = clamp(c.g + amount * 0.038 * crossover, 0.0, 1.0);  // 0.024 → 0.038
    c.b = clamp(c.b + amount * 0.012 * crossover, 0.0, 1.0);  // 新規: 青も少し
    c.r = clamp(c.r - amount * 0.010 * crossover, 0.0, 1.0);  // 0.006 → 0.010
    return c;
}

// ─────────────────────────────────────────────────────────────
// FUJI MILKY HIGHLIGHTS
//
// Fuji のハイライトは Kodak より白く、あまり乳白化しない。
// ただし極端なハイライトではわずかにシアン-白に収束する。
// ─────────────────────────────────────────────────────────────

vec3 applyMilkyHighlights(vec3 c, float amount) {
    float l = luma(c);
    float mask = smoothstep(0.62, 0.98, l);
    // Fuji ハイライト: クリーンな白 (Kodak の 0.972/0.958/0.920 クリームより白い)
    vec3 fujiWhite = vec3(0.986, 0.982, 0.975);
    return mix(c, fujiWhite, mask * amount * 0.30); // Kodak の 0.55 より少ない
}

vec3 applySaturation(vec3 c, float sat) {
    return mix(vec3(luma(c)), c, sat);
}

// ─────────────────────────────────────────────────────────────
// FUJI LENS SAMPLE  —  色収差 + 周辺ソフトネス
// ─────────────────────────────────────────────────────────────

vec3 sampleLens(vec2 uv) {
    vec2 texel      = 1.0 / u_size;
    vec2 fromCenter = uv - 0.5;
    float edgeDist  = length(fromCenter);

    float edge       = smoothstep(0.15, 0.90, edgeDist * 1.30);
    float blurRadius = edge * u_softness * 2.5;
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

    // Fuji 色収差: Kodak より少ない (ca 係数を 0.018 に)
    float ca    = edgeDist * edgeDist * u_chromatic_aberration * 0.018;
    vec2  caDir = normalize(fromCenter + vec2(0.0001)) * ca;

    vec3 chroma;
    chroma.r = texture(u_texture, coverUV(uv + caDir)).r;
    chroma.g = soft.g;
    chroma.b = texture(u_texture, coverUV(uv - caDir * 0.50)).b;

    float chromaBlend = clamp(u_chromatic_aberration * 0.5 + edge * 0.50, 0.0, 1.0);
    return mix(soft, chroma, chromaBlend);
}

// ─────────────────────────────────────────────────────────────
// FUJI HALATION  —  少量・冷色系散乱
//
// Fuji の反ハレーション層は優秀なため halation は少ない。
// 発生時: 短波長 (青-紫) が長波長 (赤) より残る。
// Kodak とは逆の「冷色ハレーション」。
//
// チャンネル別浸透深度 (Fuji 基材):
//   R: spread × 0.45  (最も少ない — Fuji が赤ハレを抑えている)
//   G: spread × 0.70
//   B: spread × 1.00  (最大 — 青が散乱)
// ─────────────────────────────────────────────────────────────

vec3 applyHalation(vec3 c, vec2 uv) {
    float baseLuma   = luma(c);
    float brightMask = smoothstep(0.68, 0.97, baseLuma) * u_halation_strength;
    if (brightMask < 0.003) return c;

    vec2  texel      = 1.0 / u_size;
    // v2: spread を拡大 → Dazz 相当の視認できる光の滲みに
    float baseSpread = 6.0 + u_halation_strength * 8.0;  // 3+4 → 6+8
    float spreadR    = baseSpread * 0.45;   // Fuji: 赤が最も少ない
    float spreadB    = baseSpread * 1.00;   // 青が最大 (冷色ハレーション)

    // v2: 3×3 → 5×5 カーネルに拡大（視認できるハレーション範囲）
    float rBleed = 0.0, bBleed = 0.0, totalW = 0.0;
    for (int dx = -2; dx <= 2; dx++) {
        for (int dy = -2; dy <= 2; dy++) {
            float w = exp(-float(dx*dx + dy*dy) * 0.28);
            totalW += w;

            vec2 offR = vec2(float(dx), float(dy)) * texel * spreadR;
            vec3 scR  = texture(u_texture, coverUV(uv + offR)).rgb;
            float bwR = smoothstep(0.62, 1.0, luma(scR)) * w;
            rBleed   += scR.r * bwR;

            vec2 offB = vec2(float(dx), float(dy)) * texel * spreadB;
            vec3 scB  = texture(u_texture, coverUV(uv + offB)).rgb;
            float bwB = smoothstep(0.62, 1.0, luma(scB)) * w;
            bBleed   += scB.b * bwB;
        }
    }
    float norm = totalW > 0.0 ? 1.0 / totalW : 0.0;
    rBleed *= norm;
    bBleed *= norm;

    // u_halation_warmth: 0=青-紫ハレーション, 1=中性
    // v2: glow 係数を強化 → 視認できる青-紫の滲み
    float warmFactor = u_halation_warmth;
    vec3 glow = vec3(
        rBleed * 0.08 * warmFactor,                    // 赤: 0.06 → 0.08
        bBleed * (1.0 - warmFactor) * 0.14,            // 緑: 0.10 → 0.14
        bBleed * (0.20 + (1.0 - warmFactor) * 0.14)   // 青: 0.14+0.10 → 0.20+0.14
    );
    return clamp(c + glow * brightMask, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────
// VIGNETTE  —  楕円ビネット（Fuji: 少し控えめ）
// ─────────────────────────────────────────────────────────────

float applyVignette(vec2 uv) {
    vec2 c = uv - 0.5;
    float e2 = dot(c * vec2(1.12, 0.90), c * vec2(1.12, 0.90));
    float v    = u_vignette_strength;
    float soft = smoothstep(0.22, 0.88, e2 / max(v * 0.30 + 0.001, 0.001));
    float hard = smoothstep(0.18, 1.00, e2 / max(v * 0.48 + 0.001, 0.001));
    float dark = soft * 0.50 + hard * 0.50;
    return clamp(1.0 - dark * v * 0.85, 0.08, 1.0);
}

// ─────────────────────────────────────────────────────────────
// FUJI GRAIN  —  ISO400 C41 銀塩粒子
//
// Fuji Superia 400 は ISO800 の写ルんですより細かい粒子。
// クラスターが小さく、より均等な分布。
// チャンネル独立性は同じ（C41 感光層の分離）。
// ─────────────────────────────────────────────────────────────

vec3 applyFilmGrain(vec3 c, vec2 uv, float time) {
    float l   = luma(c);
    float frm = floor(time * 12.0);

    vec2  px = uv * u_size;

    // 粗粒子クラスター (Fuji: 小さめ × 2.2)
    float coarseScale = max(u_grain_size * 2.2, 1.0);
    vec2  coarseUV    = px / coarseScale;
    float clump = valueNoise(coarseUV + vec2(frm * 0.07, 5.31));
    clump       = valueNoise(vec2(clump * 3.2 + frm * 0.04, coarseUV.y * 0.7 + 2.1));
    clump       = pow(clump, 0.50);

    // グレインセル + スパークル (float-only)
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
    float strength   = u_grain_amount * mix(0.070, 0.018, lumaSq);
    float sparkleStr = u_grain_amount * 0.017;
    float clumpMod   = 0.40 + clump * 1.20;

    c.r = clamp(c.r + gr * strength * clumpMod * 0.88 + sr * sparkleStr,        0.0, 1.0);
    c.g = clamp(c.g + gg * strength * clumpMod * 0.95 + sg * sparkleStr * 0.92, 0.0, 1.0);
    c.b = clamp(c.b + gb * strength * clumpMod * 1.00 + sb * sparkleStr * 0.85, 0.0, 1.0);
    return c;
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv        = fragCoord / u_size;
    uv.y           = 1.0 - uv.y;

    // 1. レンズサンプル (周辺ソフトネス + 色収差 + 樽型歪曲)
    vec3 color = sampleLens(uv);

    // 2. フィルム特性曲線 (Fuji: シアン床 + クリーンハイライト)
    color = applyFilmCurve(color, u_shadow_lift, u_highlight_rolloff, u_contrast);

    // 3. 最暗部脱色 (Fuji: シアン寄りモノクローム)
    color = applyShadowDesaturation(color);

    // 4. Fuji 緑クロスオーバー (浅いシャドウ帯・緑-シアン持ち上げ)
    color = applyFujiGreenCrossover(color, u_warmth);

    // 5. 3ゾーン カラースプリット (Fuji: シアンシャドウ / クール中間 / クリーン白)
    color = applyColorSplit(color, u_warmth);

    // 6. ハイライト (Fuji: クリーン白寄り)
    color = applyMilkyHighlights(color, u_milky_highlights);

    // 7. 彩度 (Fuji: 高めの彩度)
    color = applySaturation(color, u_saturation);

    // 8. ハレーション (Fuji: 少量・青-紫寄り)
    color = applyHalation(color, uv);

    // 9. ビネット
    color *= applyVignette(uv);

    // 10. フィルムグレイン (ISO400: 細かめ・均等)
    color = applyFilmGrain(color, uv, u_time);

    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
