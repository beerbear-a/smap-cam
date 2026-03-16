// {{FILM_FILE}}  —  {{FILM_SUBTITLE}}
// Maya Ishikawa — ZootoCam Shader Engine
//
// このファイルは new_lut.dart で生成されたテンプレートです。
// CUSTOMIZE: セクションを順番に調整してください。
//
// Uniform layout (float index):  ← 変更禁止 (FilmShaderPainter と一致させること)
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

// ╔═══ CUSTOMIZE [1]: 樽型歪曲係数 k ═══════════════════
// レンズの歪曲量。プラスチック単玉ほど大きい。
//   写ルんです (k=0.08) > Fuji 安価ズーム (k=0.06) > 一眼 (k≈0.02)
//   0.0 = 歪曲なし、0.12 = ロモカメラ級の強い樽型
// ╚══════════════════════════════════════════════════════
vec2 applyBarrel(vec2 uv) {
    vec2  c  = uv - 0.5;
    float r2 = dot(c, c);
    return uv + c * r2 * 0.07; // ← k値を変える
}

vec2 coverUV(vec2 uv) {
    vec2 distorted = applyBarrel(uv);
    float ia = u_image_width  / u_image_height;
    float va = u_size.x / u_size.y;
    if (ia > va) return vec2((distorted.x - 0.5) * (va / ia) + 0.5, distorted.y);
    else         return vec2(distorted.x, (distorted.y - 0.5) * (ia / va) + 0.5);
}

// ═══════════════════════════════════════════════════════
// NOISE  —  float-only hash (uint禁止: impellerc SPIR-V hangを避ける)
// ═══════════════════════════════════════════════════════

float fhash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(
        mix(fhash(i),               fhash(i + vec2(1,0)), u.x),
        mix(fhash(i + vec2(0,1)),   fhash(i + vec2(1,1)), u.x),
        u.y
    );
}

float grainSample(vec2 gcoord, float ch, float frm) {
    vec2 s1 = gcoord + vec2(frm * 0.1371,        ch * 17.0);
    vec2 s2 = gcoord + vec2(frm * 0.1371 + 3.71, ch * 17.0 + 5.3);
    return fhash(s1) + fhash(s2) - 1.0;
}

// ═══════════════════════════════════════════════════════
// FILM TONE CURVE
// ═══════════════════════════════════════════════════════

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

// ╔═══ CUSTOMIZE [2]: チャンネル別 D-min と Shoulder ════
// 各行は R / G / B チャンネル。
//
// filmToe 第3引数 (dmin): D-min フロアの高さ
//   暖色フィルム: R高め (0.035–0.045), B低め (0.005–0.012)
//   冷色フィルム: B高め (0.030–0.040), R低め (0.010–0.015)
//   B&W:         3チャンネル同値 (0.018–0.022)
//
// filmShoulder 第4引数 (cap): ハイライト上限
//   クリーンな白: 0.970–0.982
//   フィルムらしい: 0.945–0.960
//   強くミルキー: 0.900–0.930
// ╚══════════════════════════════════════════════════════
vec3 applyFilmCurve(vec3 c, float sl, float hr, float contrast) {
    float r = filmToe(c.r, sl * 1.20, 0.035); // R D-min
    float g = filmToe(c.g, sl * 0.82, 0.020); // G D-min
    float b = filmToe(c.b, sl * 0.48, 0.010); // B D-min

    r = filmShoulder(r, 0.66 - hr * 0.09, 1.4 + hr * 0.9,  0.955); // R cap
    g = filmShoulder(g, 0.69 - hr * 0.07, 1.5 + hr * 0.85, 0.945); // G cap
    b = filmShoulder(b, 0.72 - hr * 0.05, 1.6 + hr * 1.0,  0.930); // B cap

    vec3 cv = vec3(r, g, b);
    cv = (cv - 0.40) * (1.0 + contrast * 0.30) + 0.40;
    return clamp(cv, 0.0, 1.0);
}

// ═══════════════════════════════════════════════════════
// SHADOW DESATURATION  —  最暗部での乳剤反応不完全
// ═══════════════════════════════════════════════════════

// ╔═══ CUSTOMIZE [3]: 最暗部の色調 ══════════════════════
// 影の最暗部がどんな色に見えるか。
//   暖色フィルム: R高め G中 B低め (アンバー/コーヒー感)
//   冷色フィルム: B高め G中 R低め (ブルーシャドウ)
//   ニュートラル: 3つ同値 (0.87, 0.87, 0.87)
// ╚══════════════════════════════════════════════════════
vec3 applyShadowDesaturation(vec3 c) {
    float l = luma(c);
    float deepShadow = 1.0 - smoothstep(0.04, 0.22, l);
    vec3 monoWarm = vec3(
        l * 0.87 + 0.012,   // R: アンバー床 (暖色ならR高め)
        l * 0.85 + 0.008,   // G: 中間
        l * 0.81 + 0.005    // B: (冷色なら B を高く, R を低く)
    );
    return mix(c, monoWarm, deepShadow * 0.70);
}

// ╔═══ CUSTOMIZE [4]: 3ゾーン カラースプリット ══════════
// 影 / ミッドトーン / ハイライト それぞれの色シフト。
// 値の読み方: + = その色を足す, - = その色を引く
//
// 例: 写ルんです (暖色)
//   シャドウ:   green+, blue+  →  緑-オリーブ
//   ミッドトーン: red+, blue-  →  アンバー
//   ハイライト:  red+, blue-  →  クリーム
//
// 例: Fuji (冷色)
//   シャドウ:   green+, blue+, red-  →  シアン-ティール
//   ミッドトーン: red-, blue+        →  冷たい緑
//   ハイライト:  blue+               →  冷たい白
// ╚══════════════════════════════════════════════════════
vec3 applyColorSplit(vec3 c, float warmth) {
    float l = luma(c);

    float shadowMask    = 1.0 - smoothstep(0.00, 0.38, l);
    float highlightMask = smoothstep(0.58, 1.00, l);
    float midMask       = 1.0 - shadowMask - highlightMask;

    // ── シャドウ: どんな色の影か ─────────────────────────
    float sg =  0.010 * shadowMask; // 緑成分 (+= 緑オリーブ)
    float sb =  0.005 * shadowMask; // 青成分
    float sr = -0.003 * shadowMask; // 赤成分 (-= 赤を引く)

    // ── ミッドトーン: 中間調の色温度 ──────────────────────
    float mr =  warmth * 0.025 * midMask; // 暖色なら+, 冷色なら-にする
    float mg =  warmth * 0.008 * midMask;
    float mb = -warmth * 0.035 * midMask;

    // ── ハイライト: 白飛び際の色 ──────────────────────────
    float hr =  warmth * 0.030 * highlightMask;
    float hg =  warmth * 0.010 * highlightMask;
    float hb = -warmth * 0.045 * highlightMask;

    c.r = clamp(c.r + sr + mr + hr, 0.0, 1.0);
    c.g = clamp(c.g + sg + mg + hg, 0.0, 1.0);
    c.b = clamp(c.b + sb + mb + hb, 0.0, 1.0);
    return c;
}

// ╔═══ CUSTOMIZE [5]: グリーンクロスオーバー ════════════
// Kodak/Fuji 系 C41 フィルムでシャドウ〜ミッド帯に緑が乗る現象。
//   amount 0.0 = クロスオーバーなし (例: Ilford B&W は不要)
//   amount 1.0 = フルのKodak緑クロスオーバー
// ╚══════════════════════════════════════════════════════
vec3 applyC41GreenCrossover(vec3 c, float amount) {
    float l = luma(c);
    float crossover = smoothstep(0.08, 0.30, l) * (1.0 - smoothstep(0.30, 0.55, l));
    c.g = clamp(c.g + amount * 0.015 * crossover, 0.0, 1.0);
    return c;
}

// ═══════════════════════════════════════════════════════
// BLUE CRUSH
// ═══════════════════════════════════════════════════════

vec3 applyBlueCrush(vec3 c, float amount) {
    float l = luma(c);
    float crush = amount * (0.55 + (1.0 - smoothstep(0.0, 0.50, l)) * 0.45);
    c.b = clamp(c.b * (1.0 - crush), 0.0, 1.0);
    return c;
}

// ═══════════════════════════════════════════════════════
// MILKY HIGHLIGHTS
// ═══════════════════════════════════════════════════════

// ╔═══ CUSTOMIZE [6]: ハイライト乳白色の色 ══════════════
// cream の RGB がハイライトに混ぜられる色。
//   クリーム/アイボリー: vec3(0.972, 0.958, 0.920)  ← 写ルんです
//   冷たい白:            vec3(0.952, 0.965, 0.980)  ← Fuji
//   純白:                vec3(1.000, 1.000, 1.000)
// ╚══════════════════════════════════════════════════════
vec3 applyMilkyHighlights(vec3 c, float amount) {
    float l = luma(c);
    float mask = smoothstep(0.52, 0.97, l);
    vec3 cream = vec3(0.972, 0.958, 0.920); // ← 乳白色の色を変える
    return mix(c, cream, mask * amount * 0.55);
}

vec3 applySaturation(vec3 c, float sat) {
    return mix(vec3(luma(c)), c, sat);
}

// ═══════════════════════════════════════════════════════
// LENS SAMPLE
// ═══════════════════════════════════════════════════════

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

// ╔═══ CUSTOMIZE [7]: ハレーション チャンネル比率 ═══════
// フィルム基材でのRGB各波長の浸透深度比。
//
//   写ルんです (暖色ハレーション): R=1.00, G=0.60, B=0.18
//     → ハレーションが「赤-アンバー」に見える
//
//   Fuji (冷色ハレーション):       R=0.25, G=0.55, B=1.00
//     → ハレーションが「青-紫」に見える
//
//   B&W (中間):                    R=0.60, G=0.60, B=0.60
//     → ルミナンスブルーム（色なし）
//
// spreadR, spreadG の基底は baseSpread で決まる。
// ╚══════════════════════════════════════════════════════
vec3 applyHalation(vec3 c, vec2 uv) {
    float baseLuma   = luma(c);
    float brightMask = smoothstep(0.68, 0.97, baseLuma) * u_halation_strength;
    if (brightMask < 0.003) return c;

    vec2  texel      = 1.0 / u_size;
    float baseSpread = 4.0 + u_halation_strength * 5.5;
    float spreadR    = baseSpread * 1.00; // R 浸透深度 (暖色=高, 冷色=低)
    float spreadG    = baseSpread * 0.60; // G 浸透深度
    // B 浸透深度: 暖色フィルムではほぼ0なので省略 (冷色ならB chも追加)

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
        rBleed  * (0.18 + amber * 0.06), // 暖色フィルムなら R 係数を大きく
        gBleed  * amber,
        0.0                              // 冷色フィルムなら B chを追加
    );
    return clamp(c + glow * brightMask, 0.0, 1.0);
}

// ═══════════════════════════════════════════════════════
// VIGNETTE
// ═══════════════════════════════════════════════════════

float applyVignette(vec2 uv) {
    vec2 c = uv - 0.5;
    float e2 = dot(c * vec2(1.14, 0.88), c * vec2(1.14, 0.88));

    float v    = u_vignette_strength;
    float soft = smoothstep(0.20, 0.85, e2 / max(v * 0.28 + 0.001, 0.001));
    float hard = smoothstep(0.15, 1.00, e2 / max(v * 0.46 + 0.001, 0.001));

    float dark = soft * 0.52 + hard * 0.48;
    return clamp(1.0 - dark * v * 0.90, 0.05, 1.0);
}

// ╔═══ CUSTOMIZE [8]: グレイン クラスタースケール ════════
// 粗粒子クラスターの倍率。ISO感度が高いほど大きく設定。
//   ISO 100–200: 2.0–2.2×  (きめ細かい)
//   ISO 400:     2.4–2.8×  (標準)
//   ISO 800+:    2.8–3.2×  (粗め)
//   期限切れ:     3.0–4.0×  (非常に粗い)
//
// チャンネル係数 (最後の乗算): 1.00/0.91/0.84 が標準。
//   B&W は全チャンネル同値 (1.00/1.00/1.00) にすること。
// ╚══════════════════════════════════════════════════════
vec3 applyFilmGrain(vec3 c, vec2 uv, float time) {
    float l   = luma(c);
    float frm = floor(time * 12.0); // 12fps固定 (変更禁止)

    vec2  px = uv * u_size;

    float coarseScale = max(u_grain_size * 2.5, 1.0); // ← クラスター倍率
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
    float strength   = u_grain_amount * mix(0.085, 0.020, lumaSq);
    float sparkleStr = u_grain_amount * 0.020;
    float clumpMod   = 0.35 + clump * 1.30;

    // ← B&W ならチャンネル係数を全部 1.00 にする
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

    // 3. 最暗部脱色 (色素雲不完全形成 → モノクローム+アンバー床)
    color = applyShadowDesaturation(color);

    // 4. グリーンクロスオーバー (C41フィルムのミッドシャドウ緑シフト)
    color = applyC41GreenCrossover(color, u_warmth);

    // 5. Blue 圧縮
    color = applyBlueCrush(color, u_blue_crush);

    // 6. 3ゾーン カラースプリット
    color = applyColorSplit(color, u_warmth);

    // 7. 乳白色ハイライト
    color = applyMilkyHighlights(color, u_milky_highlights);

    // 8. 彩度
    color = applySaturation(color, u_saturation);

    // 9. ハレーション (フィルム基材散乱、チャンネル別半径)
    color = applyHalation(color, uv);

    // 10. ビネット (楕円、二段暗化)
    color *= applyVignette(uv);

    // 11. フィルムグレイン (3スケール×チャンネル独立×輝度依存)
    color = applyFilmGrain(color, uv, u_time);

    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
