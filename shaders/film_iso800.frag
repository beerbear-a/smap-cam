#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

// ─── Utility ───────────────────────────────────────────────

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// ─── Tone Curve (S字カーブ: シャドウ持ち上げ + ハイライト圧縮) ──

float toneCurve(float x) {
    // Shadows: lift  /  Highlights: compress
    float shadow    = x * 0.95 + 0.04;
    float highlight = 1.0 - pow(1.0 - x, 1.3);
    float t = smoothstep(0.0, 0.5, x);
    return mix(shadow, highlight, t);
}

// ─── Color Bias (暖色シフト ISO800 Kodak風) ────────────────

vec3 colorBias(vec3 c) {
    c.r = clamp(c.r + 0.05, 0.0, 1.0);
    c.g = clamp(c.g + 0.02, 0.0, 1.0);
    c.b = clamp(c.b - 0.08, 0.0, 1.0);
    return c;
}

// ─── Film Grain (ISO800相当 σ≈0.08) ────────────────────────

vec3 filmGrain(vec3 c, vec2 uv) {
    float grainSeed = uTime * 0.1;
    float grain = rand(uv + grainSeed) * 2.0 - 1.0;
    float strength = 0.08 * (1.0 - c.r * 0.5);  // shadows get more grain
    return clamp(c + vec3(grain) * strength, 0.0, 1.0);
}

// ─── Vignette (四隅暗化) ────────────────────────────────────

float vignette(vec2 uv) {
    vec2 centered = uv - 0.5;
    float dist    = length(centered);
    float radius  = 0.70;
    float feather = 0.40;
    return smoothstep(radius, radius - feather, dist);
}

// ─── Halation (ハイライト赤チャンネル滲み) ──────────────────

vec3 halation(vec3 c, vec2 uv) {
    float luma = dot(c, vec3(0.299, 0.587, 0.114));

    // bright areas bleed red
    float bloom = smoothstep(0.75, 1.0, luma);

    // Sample surrounding pixels for spread
    vec2 texel = 1.0 / uResolution;
    float r = 0.0;
    float samples = 0.0;
    for (int dx = -2; dx <= 2; dx++) {
        for (int dy = -2; dy <= 2; dy++) {
            vec2 offset = vec2(float(dx), float(dy)) * texel * 3.0;
            vec3 s = texture(uTexture, uv + offset).rgb;
            float w = exp(-float(dx*dx + dy*dy) * 0.4);
            r += s.r * w;
            samples += w;
        }
    }
    r /= samples;

    float halationStrength = bloom * 0.15;
    c.r = clamp(c.r + r * halationStrength, 0.0, 1.0);
    c.g = clamp(c.g - halationStrength * 0.02, 0.0, 1.0);
    return c;
}

// ─── Main ──────────────────────────────────────────────────

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Flip Y (Flutter coordinate system)
    uv.y = 1.0 - uv.y;

    vec4 texColor = texture(uTexture, uv);
    vec3 color = texColor.rgb;

    // 1. Tone curve per channel
    color.r = toneCurve(color.r);
    color.g = toneCurve(color.g);
    color.b = toneCurve(color.b);

    // 2. Color bias (warm/cool shift)
    color = colorBias(color);

    // 3. Film grain
    color = filmGrain(color, uv);

    // 4. Vignette
    float vig = vignette(uv);
    color *= vig;

    // 5. Halation
    color = halation(color, uv);

    fragColor = vec4(color, texColor.a);
}
