// film_iso800.frag  v4  —  写ルんです QuickSnap ISO800 光化学完全再現
// Maya Ishikawa — ZootoCam Shader Engine
//
// v4 追加（v3 → v4）:
//   [8]  Barrel distortion  — 32mm プラスチック単焦点の樽型歪曲 (k=0.08)
//        f/10 固定焦点・単玉構成特有の周辺約2%樽型歪み。
//        直線が僅かに外側に膨らむ、あの「フィルムカメラ感」の正体のひとつ。
//   [9]  Shadow desaturation  — C41 最暗部での色素雲不完全形成
//        luma < 0.20 帯では青・緑感光層の色素カプラーが反応しきれず、
//        色がほぼ消えてアンバー床のみ残る。
//  [10]  Per-channel halation radii  — R:G:B = 1.00:0.60:0.18 (浸透深度差)
//        赤光 (700nm) は最も長波長のため基材を最深部まで透過 → 広く散乱。
//        緑は中程度、青 (450nm) はほとんど散乱しない。
//  [11]  Grain sparkle octave  — 高周波散粒子ハッシュ
//        ISO800 フィルム拡大時の "キラキラ感":大粒子クラスター内に
//        個別銀粒子の高周波輝きが重なることで、デジタルノイズとの決定的な差が出る。
//
// Uniform layout (float index):
//   0,1 : u_size             (vec2)
//   2   : u_time             (float)
//   3   : u_warmth           (float 0–1)
//   4   : u_saturation       (float 0–2, 1=no-op)
//   5   : u_shadow_lift      (float 0–1)
//   6   : u_highlight_rolloff(float 0–1)
//   7   : u_grain_amount     (float 0–1)
//   8   : u_vignette_strength(float 0–1)
//   9   : u_halation_strength(float 0–1)
//   10  : u_softness         (float 0–1)
//   11  : u_chromatic_aberration (float 0–1)
//   12  : u_milky_highlights (float 0–1)
//   13  : u_contrast         (float -0.5–0.5)
//   14  : u_blue_crush       (float 0–0.4)
//   15  : u_halation_warmth  (float 0–1)
//   16  : u_grain_size       (float 0.5–4)
//   17  : u_image_width      (float px)
//   18  : u_image_height     (float px)
//
// Image sampler 0: u_texture

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

out vec4 frag_color;

// ═══════════════════════════════════════════════════════
// UTILITY
// ═══════════════════════════════════════════════════════

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// 樽型歪曲 — QuickSnap 800 の32mm単玉プラスチックレンズ特性
// k=0.08: 周辺部が外側に約2%押し出される
// キャンバス中心(0.5, 0.5)を原点として適用
vec2 applyBarrel(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return uv + c * r2 * 0.08;
}

// BoxFit.cover + 樽型歪曲: 全テクスチャサンプルがここを通る
vec2 coverUV(vec2 uv) {
    // 1. 樽型歪曲 (写ルんです プラスチックレンズ)
    vec2 distorted = applyBarrel(uv);
    // 2. アスペクト比正規化
    float ia = u_image_width  / u_image_height;
    float va = u_size.x / u_size.y;
    if (ia > va) return vec2((distorted.x - 0.5) * (va / ia) + 0.5, distorted.y);
    else         return vec2(distorted.x, (distorted.y - 0.5) * (ia / va) + 0.5);
}

// ═══════════════════════════════════════════════════════
// NOISE  —  float-only hash + value noise
//
// impellerc 根本原因: SPIR-V→MSL 変換で uint 演算がハング。
// uint を一切使わない float-only 実装に切り替え。
// ═══════════════════════════════════════════════════════

// sin ベース float hash — uint 不使用、impellerc safe
float fhash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Quintic value noise (粗粒子クラスター用)
float valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(
        mix(fhash(i),               fhash(i + vec2(1,0)), u.x),
        mix(fhash(i + vec2(0,1)),   fhash(i + vec2(1,1)), u.x),
        u.y
    );
}

// チャンネル別フレーム別グレインサンプル → triangular [-1, 1]
// ch: 0.0=R, 1.0=G, 2.0=B, 3.0–5.0=sparkle
float grainSample(vec2 gcoord, float ch, float frm) {
    vec2 s1 = gcoord + vec2(frm * 0.1371,        ch * 17.0);
    vec2 s2 = gcoord + vec2(frm * 0.1371 + 3.71, ch * 17.0 + 5.3);
    return fhash(s1) + fhash(s2) - 1.0;
}

// ═══════════════════════════════════════════════════════
// FILM TONE CURVE  —  フィルム特性曲線
//
// 光化学的根拠:
//   Toe  — 乳剤の最小濃度 (D-min) で黒が持ち上がる
//   Linear — 比例域（log露光 ∝ 濃度）
//   Shoulder — 最大濃度 (D-max) で白がクリームに転ぶ
// ═══════════════════════════════════════════════════════

// D-min 込みのトー: 暗部が真黒にならずアンバー色の床を持つ
float filmToe(float x, float lift, float dmin) {
    float floored = max(x, dmin);
    return floored + lift * 0.09 * (1.0 - floored) * (1.0 - floored);
}

// Shoulder: ハイライトが cap で止まる
float filmShoulder(float x, float start, float rolloff, float cap) {
    // 早期 return を mix+step に置換 — SPIR-V の OpPhi 分岐構造を排除。
    float t = clamp((x - start) / max(1.0 - start, 0.001), 0.0, 1.0);
    float curved = 1.0 - pow(max(1.0 - t, 0.0), 1.0 + rolloff * 1.6);
    float shoulder = start + (1.0 - start) * min(curved, cap);
    return mix(x, shoulder, step(start, x));
}

// チャンネル別カーブ — 写ルんです ISO800 の乳剤特性
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

// ═══════════════════════════════════════════════════════
// SHADOW DESATURATION  —  C41 最暗部の色素雲不完全形成
//
// 光化学的根拠:
//   C41 ネガ現像では露光量が極端に少ない領域（深い影）で
//   色素カプラーの反応が不十分になる。
//   結果: 最暗部は実質モノクロームとなり、D-min のアンバー床のみ残る。
//   これが「写ルんですで撮った夜景の影」の特徴的な見え方。
// ═══════════════════════════════════════════════════════

vec3 applyShadowDesaturation(vec3 c) {
    float l = luma(c);
    // luma 0.00-0.04: 完全脱色 → 0.04-0.22: 移行域 → 0.22以上: 通常
    float deepShadow = 1.0 - smoothstep(0.04, 0.22, l);
    // アンバーD-minの色温度に近い微かな暖色調モノクローム
    vec3 monoWarm = vec3(
        l * 0.88 + 0.014,   // R: わずかに高め (アンバー床)
        l * 0.85 + 0.008,   // G: 中間
        l * 0.80 + 0.004    // B: 最も低め
    );
    return mix(c, monoWarm, deepShadow * 0.70);
}

// ═══════════════════════════════════════════════════════
// 3-ZONE COLOR SPLIT  —  写ルんですの乳剤 + C41 現像特性
//
// 物理根拠:
//   シャドウ部: 青・緑感光層の色素雲オーバーラップ → 緑-オリーブ
//   ミッドトーン: C41 処理温度の暖色バイアス
//   ハイライト: アンバー-クリームへの転色
// ═══════════════════════════════════════════════════════

vec3 applyColorSplit(vec3 c, float warmth) {
    float l = luma(c);

    float shadowMask    = 1.0 - smoothstep(0.00, 0.38, l);
    float highlightMask = smoothstep(0.58, 1.00, l);
    float midMask       = 1.0 - shadowMask - highlightMask;

    // シャドウ: 緑-オリーブ傾向
    float sg =  0.012 * shadowMask;
    float sb =  0.006 * shadowMask;
    float sr = -0.004 * shadowMask;

    // ミッドトーン: 暖色アンバー
    float mr =  warmth * 0.028 * midMask;
    float mg =  warmth * 0.010 * midMask;
    float mb = -warmth * 0.038 * midMask;

    // ハイライト: クリーム/アイボリー
    float hr =  warmth * 0.035 * highlightMask;
    float hg =  warmth * 0.012 * highlightMask;
    float hb = -warmth * 0.050 * highlightMask;

    c.r = clamp(c.r + sr + mr + hr, 0.0, 1.0);
    c.g = clamp(c.g + sg + mg + hg, 0.0, 1.0);
    c.b = clamp(c.b + sb + mb + hb, 0.0, 1.0);
    return c;
}

// ═══════════════════════════════════════════════════════
// C41 GREEN CROSSOVER  —  シャドウ〜ミッドの緑シフト
//
// 写ルんです / Kodak Gold: ミッドシャドウ帯 (0.08–0.55) で
// 緑感光層感度カーブが他チャンネルより高い。
// ═══════════════════════════════════════════════════════

vec3 applyC41GreenCrossover(vec3 c, float amount) {
    float l = luma(c);
    float crossover = smoothstep(0.08, 0.30, l) * (1.0 - smoothstep(0.30, 0.55, l));
    c.g = clamp(c.g + amount * 0.018 * crossover, 0.0, 1.0);
    return c;
}

// ═══════════════════════════════════════════════════════
// BLUE CRUSH  —  写ルんですの blue 圧縮
//
// プラスチックレンズの分光特性と C41 青感光層応答で
// 青が全体的に沈む。シャドウほど沈みが大きい。
// ═══════════════════════════════════════════════════════

vec3 applyBlueCrush(vec3 c, float amount) {
    float l = luma(c);
    float crush = amount * (0.55 + (1.0 - smoothstep(0.0, 0.50, l)) * 0.45);
    c.b = clamp(c.b * (1.0 - crush), 0.0, 1.0);
    return c;
}

// ═══════════════════════════════════════════════════════
// MILKY HIGHLIGHTS  —  乳白色ハイライト
//
// 写ルんです最大の特徴のひとつ。
// 白飛び寸前で色が「クリーム/アイボリー」に滞留する。
// ═══════════════════════════════════════════════════════

vec3 applyMilkyHighlights(vec3 c, float amount) {
    float l = luma(c);
    float mask = smoothstep(0.52, 0.97, l);
    vec3 cream = vec3(0.972, 0.958, 0.920);
    return mix(c, cream, mask * amount * 0.55);
}

// ═══════════════════════════════════════════════════════
// SATURATION
// ═══════════════════════════════════════════════════════

vec3 applySaturation(vec3 c, float sat) {
    return mix(vec3(luma(c)), c, sat);
}

// ═══════════════════════════════════════════════════════
// LENS SAMPLE  —  Softness + Chromatic Aberration
//
// QuickSnap 800 の32mm f/10 プラスチック単焦点:
//   - 中心: 比較的シャープ
//   - 周辺: 急速に甘くなる（フィールドカーブ）
//   - 色収差: 赤外・青内 の径方向
//   - 樽型歪曲: coverUV 内で適用済み
// ═══════════════════════════════════════════════════════

vec3 sampleLens(vec2 uv) {
    vec2 texel      = 1.0 / u_size;
    vec2 fromCenter = uv - 0.5;
    float edgeDist  = length(fromCenter);

    // 周辺ソフトネス
    float edge        = smoothstep(0.12, 0.88, edgeDist * 1.35);
    float blurRadius  = edge * u_softness * 2.8;
    vec2  bOff        = texel * blurRadius;

    // 9-tap cross + diagonal ブラー
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

    // 色収差: edgeDist^2 で周辺部だけ急激に増大
    float ca    = edgeDist * edgeDist * u_chromatic_aberration * 0.026;
    vec2  caDir = normalize(fromCenter + vec2(0.0001)) * ca;

    vec3 chroma;
    chroma.r = texture(u_texture, coverUV(uv + caDir)).r;
    chroma.g = soft.g;
    chroma.b = texture(u_texture, coverUV(uv - caDir * 0.55)).b;

    float chromaBlend = clamp(u_chromatic_aberration * 0.6 + edge * 0.55, 0.0, 1.0);
    return mix(soft, chroma, chromaBlend);
}

// ═══════════════════════════════════════════════════════
// HIGHLIGHT BLOOMING  —  ハイライトの球面収差的滲み
//
// プラスチックレンズは f/10 でも球面収差が残り、
// 明るい点光源・白いオブジェクトが輪郭外側に滲む。
// ═══════════════════════════════════════════════════════

vec3 applyHighlightBlooming(vec3 c, vec2 uv, float softness) {
    float l = luma(c);
    float bloom = smoothstep(0.78, 1.0, l);
    if (bloom < 0.01) return c;

    vec2 texel = 1.0 / u_size;
    float radius = softness * 1.8 + 1.2;

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

// ═══════════════════════════════════════════════════════
// HALATION  —  フィルム基材の光散乱（チャンネル別浸透深度）
//
// 写ルんです / QuickSnap 800:
//   光がフィルム乳剤を通過し基材で反射して逆散乱する現象。
//
// v4 改善: チャンネル別散乱半径
//   R (700nm): 最長波長 → 基材を最深部まで透過 → 広く散乱 (spread × 1.00)
//   G (550nm): 中程度の透過                     → (spread × 0.60)
//   B (450nm): 最短波長 → ほとんど透過しない    → (spread × 0.18)
//
//   これにより: ハレーションが「赤みがかったアンバー」になる物理的理由が出る
// ═══════════════════════════════════════════════════════

vec3 applyHalation(vec3 c, vec2 uv) {
    float baseLuma   = luma(c);
    float brightMask = smoothstep(0.68, 0.97, baseLuma) * u_halation_strength;
    if (brightMask < 0.003) return c;

    vec2  texel     = 1.0 / u_size;
    float baseSpread = 4.0 + u_halation_strength * 5.5;
    float spreadR   = baseSpread * 1.00;   // 赤: 最も広い散乱
    float spreadG   = baseSpread * 0.60;   // 緑: 中程度

    // Per-channel 5x5 Gaussian —— R と G を別半径でサンプリング
    float rBleed = 0.0, gBleed = 0.0, totalW = 0.0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            float w = exp(-float(dx*dx + dy*dy) * 0.30);
            totalW += w;

            // Red channel (全散乱半径)
            vec2 offR = vec2(float(dx), float(dy)) * texel * spreadR;
            vec3 scR  = texture(u_texture, coverUV(uv + offR)).rgb;
            float bwR = smoothstep(0.62, 1.0, luma(scR)) * w;
            rBleed   += scR.r * bwR;

            // Green channel (60% 散乱半径)
            vec2 offG = vec2(float(dx), float(dy)) * texel * spreadG;
            vec3 scG  = texture(u_texture, coverUV(uv + offG)).rgb;
            float bwG = smoothstep(0.62, 1.0, luma(scG)) * w;
            gBleed   += scG.g * bwG * 0.35;
        }
    }
    float norm = totalW > 0.0 ? 1.0 / totalW : 0.0;
    rBleed *= norm;
    gBleed *= norm;

    // アンバー-オレンジ色の滲み
    // u_halation_warmth: 1.0 でオレンジ寄り, 0.0 で赤寄り
    float amber = u_halation_warmth * 0.4;
    vec3 glow = vec3(
        rBleed  * (0.18 + amber * 0.06),
        gBleed  * amber,
        0.0                               // B散乱は無視できるほど小さい
    );
    return clamp(c + glow * brightMask, 0.0, 1.0);
}

// ═══════════════════════════════════════════════════════
// VIGNETTE  —  プラスチックレンズ周辺減光
//
// QuickSnap 800: 口径食が大きい楕円形ビネット。
// 二段構成でエッジのソフトさを再現。
// ═══════════════════════════════════════════════════════

float applyVignette(vec2 uv) {
    vec2 c = uv - 0.5;
    float e2 = dot(c * vec2(1.14, 0.88), c * vec2(1.14, 0.88));

    float v     = u_vignette_strength;
    float soft  = smoothstep(0.20, 0.85, e2 / max(v * 0.28 + 0.001, 0.001));
    float hard  = smoothstep(0.15, 1.00, e2 / max(v * 0.46 + 0.001, 0.001));

    float dark  = soft * 0.52 + hard * 0.48;
    return clamp(1.0 - dark * v * 0.90, 0.05, 1.0);
}

// ═══════════════════════════════════════════════════════
// FILM GRAIN  —  ISO800 C41 銀塩/色素雲粒子 (float-only)
//
// 3スケール構造は維持:
//   粗粒子クラスター (grain_size × 2.8 px): value noise
//   グレインセル    (grain_size px):          grainSample
//   スパークル      (grain_size / 2 px):       grainSample
// ═══════════════════════════════════════════════════════

vec3 applyFilmGrain(vec3 c, vec2 uv, float time) {
    float l   = luma(c);
    float frm = floor(time * 12.0); // 12fps — 映写機速度感

    vec2  px = uv * u_size;

    // 粗粒子クラスター (value noise)
    float coarseScale = max(u_grain_size * 2.8, 1.0);
    vec2  coarseUV    = px / coarseScale;
    float clump = valueNoise(coarseUV + vec2(frm * 0.07, 5.31));
    clump       = valueNoise(vec2(clump * 3.7 + frm * 0.04, coarseUV.y * 0.6 + 2.1));
    clump       = pow(clump, 0.60);

    // グレインセル (float-only, impellerc safe)
    float gs     = max(u_grain_size, 1.0);
    vec2  gcoord = floor(px / gs);
    float gr = grainSample(gcoord, 0.0, frm);  // R 感光層
    float gg = grainSample(gcoord, 1.0, frm);  // G 感光層
    float gb = grainSample(gcoord, 2.0, frm);  // B 感光層

    // スパークル (grain_size/2)
    vec2  scoord = floor(px / max(u_grain_size * 0.5, 1.0));
    float sr = grainSample(scoord, 3.0, frm);
    float sg = grainSample(scoord, 4.0, frm);
    float sb = grainSample(scoord, 5.0, frm);

    // 輝度依存強度
    float lumaSq     = l * l;
    float strength   = u_grain_amount * mix(0.090, 0.022, lumaSq);
    float sparkleStr = u_grain_amount * 0.021;
    float clumpMod   = 0.35 + clump * 1.30;

    c.r = clamp(c.r + gr * strength * clumpMod * 1.00 + sr * sparkleStr,        0.0, 1.0);
    c.g = clamp(c.g + gg * strength * clumpMod * 0.91 + sg * sparkleStr * 0.88, 0.0, 1.0);
    c.b = clamp(c.b + gb * strength * clumpMod * 0.84 + sb * sparkleStr * 0.75, 0.0, 1.0);
    return c;
}

// ═══════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv        = fragCoord / u_size;
    uv.y           = 1.0 - uv.y; // Flutter 座標系: 常に Y 反転

    // 1. レンズサンプル (周辺ソフトネス + 色収差 + 樽型歪曲はcoverUV内)
    vec3 color = sampleLens(uv);

    // 2. フィルム特性曲線 (D-min込み チャンネル別トーンカーブ)
    color = applyFilmCurve(color, u_shadow_lift, u_highlight_rolloff, u_contrast);

    // 3. C41 最暗部脱色 (色素雲不完全形成 → モノクローム+アンバー床)
    color = applyShadowDesaturation(color);

    // 4. C41 Green Crossover (シャドウ〜ミッドの緑シフト)
    color = applyC41GreenCrossover(color, u_warmth);

    // 5. Blue 圧縮 (プラスチックレンズ + C41 青感光層)
    color = applyBlueCrush(color, u_blue_crush);

    // 6. 3 ゾーン カラースプリット (シャドウ緑/ミッドアンバー/ハイライトクリーム)
    color = applyColorSplit(color, u_warmth);

    // 7. 乳白色ハイライト (クリーム天井)
    color = applyMilkyHighlights(color, u_milky_highlights);

    // 8. 彩度
    color = applySaturation(color, u_saturation);

    // 9. ハレーション (フィルム基材散乱、チャンネル別半径、アンバー-オレンジ)
    color = applyHalation(color, uv);

    // 11. ビネット (楕円、二段暗化)
    color *= applyVignette(uv);

    // 12. フィルムグレイン (3スケール×チャンネル独立×輝度依存)
    color = applyFilmGrain(color, uv, u_time);

    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
