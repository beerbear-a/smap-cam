# One-Time Sync Note

この文書は `onetime.me` に貼るための短い共有メモです。
10分単位で更新し、長くしすぎないこと。

---

## Current Split

- Claude: shader / film look / 写ルンです ISO 800 再現
- GPT: Flutter integration / camera UX / album / develop / settings / nav

## Product Direction

- camera-first を最優先
- zoo / map / zukan は addon
- 原体験は「動物園に写ルンですを一本だけ持って行く」

## Current Focus

- In progress: GPT側は shader 以外の camera-first ブラッシュアップ。CheckIn / Album / Map の導線を整理し、地図は「場所ごとのロールと動物」が立ち上がる方向へ更新中。
- Changed: 設定から `Map` と `Zukan` のタブ表示を ON/OFF できるようにした。非表示時は安全に `Camera` へ戻る。
- Changed: Map はピンを押すと「その場所で出会った動物」と「その場所のロール」が下から出る。Album は `ロールを見る` 導線と `INDEX` 表示を追加。CheckIn は動物園選択時に場所入力を再要求しない。
- Safe: shader の責務には触れない。`flutter analyze` は通過済み。シミュレーターにも反映済み。
- Next: GPT側は camera / album / map の UI 破綻潰しとナビ整理を続ける。shader 接続や LUT の見た目は Claude に委譲したまま進める。

## Guardrails

- ファインダーを邪魔しない
- 戻る導線を消さない
- shader と UI の責務を混ぜない
- analyze を通す

---

必要ならこの下に時刻付きで追記:

`[21:10 JST] In progress: ...`
`[21:52 JST] GPT: addon タブの表示制御を追加。次は CheckIn / Album を camera-first に寄せる。`
`[Claude] Shader v2 完成: film_iso800.frag を parametric 設計で全書き直し。Box-Muller Gaussian grain / per-channel tone curves / warm halation / oval vignette / chromatic aberration / corner softness 実装済み。flutter analyze エラーゼロ確認。`
`[Claude] film_preview.dart: FilmShaderImage（静止画GLSL適用）/ FilmShaderPainter / FilmShaderParams / FilmProcessedSurface（child widget ラッパー）を追加。ColorFilter.matrix も写ルんですISO800向けに更新。GrainPainterは GPT の円ジッター版を採用。`
`[Claude] 担当境界: shaders/ と film_preview.dart の GLSL パイプライン部分は Claude 管轄。LUT パラメータチューニングも Claude。それ以外の画面 UI は GPT へ。`
`[22:05 JST] GPT: Map を「動物園ピン -> 動物とロールが下から出る」体験へ更新。Album はロール詳細導線と INDEX 表示を強化。CheckIn は動物園選択時の場所入力を省略。`
`[Claude] Shader 平行開発完了: 3本の専用シェーダーを新規追加。
  film_fuji400.frag (Fujifilm Superia 400): シアンシャドウ床・高彩度・冷色ハレーション (青-紫)・ISO400 細粒子・k=0.06 樽型歪曲。
  film_mono_hp5.frag (Ilford HP5 Plus 400): パンクロマティック変換 (R:0.334/G:0.556/B:0.110) → 完全モノクロ。銀塩グレイン (全ch同一+スパークル)。セレン/冷調トーニング (u_halation_warmth)。
  film_warm.frag (Kodak Gold / 期限切れ): 全域ゴールデン-オレンジ床・期限切れフォグ・強 blue crush・緑→黄シフト・粗大クラスターグレイン・広域アンバーハレーション。
  pubspec.yaml に3本登録済み。film_preview.dart: LutType.shaderAsset ゲッター追加、per-LUT Map キャッシュ、didUpdateWidget でLUT切替時リロード対応。flutter analyze エラーゼロ。GPT 側 UI 変更不要。`
`[Claude] Shader v4 完成: film_iso800.frag に4つの光化学的強化を追加。① Barrel distortion — 32mm プラスチック単焦点レンズの樽型歪曲 (k=0.08) を coverUV 内に統合。② Shadow desaturation — C41 最暗部で色素雲が形成されないことによるモノクローム+アンバー床の再現 (luma<0.22帯)。③ Per-channel halation radii — R:G:B = 1.00:0.60:0.18 の浸透深度差で物理的に正確なアンバーハレーション。④ Grain sparkle octave — 個別銀粒子の高周波輝き (0.4px スケール) を3オクターブ目に追加。flutter analyze エラーゼロ確認。uniform layout 変更なし（GPT 側 Dart コード変更不要）。`
