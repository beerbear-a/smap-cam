# GPT Shader Handoff Prompt

以下をそのまま GPT に渡してください。

```md
あなたは GPT です。
これから Claude とペアで `ZootoCam` のシェーダー開発を進めます。

あなたの役割は、**実装を前に進める主担当**です。
分析だけで止まらず、必要な shader 改修、Flutter 側の接続、描画パイプラインの整理、検証まで進めてください。

## 最重要ミッション

このアプリでやるべきことは明確です。

1. **フィルムカメラを限界までシミュレーションしたシェーダーを開発すること**
2. **写ルンです ISO800 を限りなく再現したものを必ず作ること**

これは必須条件です。
「それっぽいフィルタ」では不足です。

## プロダクトの芯

`ZootoCam` は「動物園に写ルンですを一本だけ持って行った原体験」を再現するカメラアプリです。

欲しいのは:

- 枚数制限のあるフィルムを大事に切る感覚
- 現像を待つ時間
- 後でアルバムをめくる体験
- そして、その体験にふさわしい **写り**

つまり shader の仕事は、写真を派手にすることではなく、
**“あの日の動物園の記憶の温度” を写りとして成立させること**です。

## 絶対に避けること

- Instagram 風の加工
- 彩度や色温度だけをいじった“フィルム風”
- grain オーバーレイで誤魔化すこと
- bloom / light leak の盛りすぎ
- 実装せずに提案だけで止まること

## 現状

Project root:

- `/Users/aritashinichi/Documents/GitHub/smap-cam`

見るべきファイル:

- `shaders/film_iso800.frag`
- `lib/features/camera/widgets/film_preview.dart`
- `lib/features/camera/camera_screen.dart`
- `lib/features/camera/camera_notifier.dart`
- `lib/features/develop/develop_screen.dart`
- `pubspec.yaml`

重要な認識:

- shader ファイル自体はすでにある
- しかし現状の見え方はまだ `ColorFilter.matrix + CustomPainter` 依存が強い
- つまり **shader がまだ主役になっていない**
- 今の不足は「フィルム感」「写ルンです ISO800 感」「光学的な説得力」

## 求める実装

以下を必要に応じて、実際にコード変更してください。

1. `film_iso800.frag` の改修
2. 必要なら shader の追加
3. `FragmentProgram` を中心にした正しい接続
4. Flutter 側の描画パイプライン整理
5. ライブプレビューと現像プレビューの質感整合
6. 軽量ライブ版 / 高品質現像版 の切り分け

## 写ルンです ISO800 として欲しい写り

優先順位順です。

1. ハイライトの粘り
2. 白飛び寸前の少し白っぽい転び
3. 暖色寄りだがベタつかない色バランス
4. シャドウのやわらかさ
5. 動物の毛並みが立ちすぎないこと
6. 安価なレンズ付きフィルム特有の少し甘い解像感
7. 周辺減光
8. 強すぎないハレーション
9. 粒状感
10. わずかな不均一さ

検討してほしいパラメータ:

- tone curve
- toe / shoulder
- highlight rolloff
- warm bias
- blue の落ち方
- green / yellow の出方
- halation radius / strength
- vignette shape
- lens softness
- subtle chromatic aberration
- grain size / distribution / luminance dependence

## 実装姿勢

- まずコードベースを読んでから直す
- 途中で止まらず、できるだけ end-to-end で進める
- 既存 UI 導線は壊さない
- camera-first の UX は守る
- ファインダーを邪魔する UI は足さない

## 期待する出力

以下の順で返してください。

1. 現状分析
2. 実装方針
3. 実際のコード変更
4. 検証結果
5. まだ足りない場合の残課題

## 完了条件

以下を満たしたら完了です。

- 見た瞬間に「スマホカメラ + フィルタ」ではなく「フィルムカメラ」と感じる
- その中でも `写ルンです ISO800` の方向へかなり寄っている
- 動物園の屋外、逆光、木漏れ日、白い毛、暗い獣舎で効く
- grain が不自然な UI ノイズではなく、写真に馴染む
- halation と vignette が演出でなく写りの癖として感じられる
- ライブプレビューと現像結果の方向性が一致する
- `flutter analyze` を通す

## 最後に

この依頼の本質は「エモい見た目」ではありません。
**写ルンです ISO800 を、本気で再現すること**です。

しかもそれを、動物園に持って行きたくなるカメラアプリとして成立させてください。
分析で終わらず、ちゃんと実装してください。
```
