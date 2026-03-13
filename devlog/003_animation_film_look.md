# [003] アニメーション & フィルムルック実装

**エンジニア:** Maya Ishikawa / 石川 摩耶
**担当領域:** Flutter アニメーション / GLSL シェーダー / 映像・写真理論
**日付:** 2026-03-13
**ステータス:** ✅ 完了

---

## 自己紹介

東京→NY で映像制作10年、その後 Apple Motion チームに参加。現在フリーで Flutter シェーダーアニメーション専門。
Kodachrome 64 を使い切るまでカメラを手放さなかった人間として、
「**フィルムの魂はグレインと光のにじみの中にある**」を信じている。

---

## 診断

`film_iso800.frag` が書かれていながら一度も使われていない。これは罪だ。

| 問題 | 詳細 |
|------|------|
| シェーダー未接続 | `film_iso800.frag` が pubspec に登録されているが Flutter から呼ばれていない |
| カメラプレビューが素の `Texture` | フィルム感ゼロ。デジタルカメラと区別がつかない |
| LUT 切替 UI なし | フィルムストック選択機能が PRD にあるが実装ゼロ |
| DevelopScreen が地味 | テキストがパルスするだけ。現像プロセスの神秘性がない |

---

## フィルム光学の基礎知識（なぜこの実装なのか）

### グレイン vs デジタルノイズ
- **デジタルノイズ**: 全ピクセル均等・高周波・パターンなし
- **フィルムグレイン**: 銀塩粒子の化学分布 → **シャドウ部で強く、ハイライトで弱い** / 12fps 相当でランダム変化（映写機の速度）
- → `_GrainPainter` でスタンプベースグレイン（4×4px ブロック）を 12fps で更新

### ビネット
- レンズの周辺光量落ちは物理的必然（cos⁴ の法則）
- 広角 = 強い、標準 = 弱い
- → `_VignettePainter` で RadialGradient（3ストップ: 0.4/0.72/1.0）

### 光学的ソフトネス
- フィルムレンズは解像度よりも「広がり」がある（非点収差・球面収差）
- デジタルは完璧に鋭い → フィルム感がない
- → `BackdropFilter(blur: 0.3px)` で光学的広がりをシミュレート

### カラーサイエンス（ColorFilter.matrix）
各フィルムストックの特性を 5×4 行列で近似:
- **Kodak Gold 200**: 暖色（R+1.10）、シャドウリフト（+8）、低コントラスト
- **Fuji Superia**: シアンシャドウ（B+1.08）、中高彩度、緑よりの肌色
- **Ilford HP5**: 輝度変換行列 `Y = 0.299R + 0.587G + 0.114B`（BT.601標準）

### ハレーション（Halation）
フィルムベースの裏面で光が反射し、ハイライトに赤い滲みが出る現象。
→ `film_iso800.frag` シェーダー内で実装済み（5×5 ガウシアンサンプリング）

---

## 実装内容

### 1. `lib/features/camera/widgets/film_preview.dart` (新規)

```
FilmPreviewWidget
 ├── Texture(textureId)              # 生カメラ映像
 ├── ColorFiltered(matrix)           # フィルムストックカラーグレード (GPU)
 ├── BackdropFilter(blur: 0.3)       # 光学的ソフトネス
 ├── CustomPaint(_VignettePainter)   # ビネット (RadialGradient)
 ├── AnimatedBuilder                 # 12fps Ticker
 │   └── CustomPaint(_GrainPainter) # アニメーショングレイン
 └── focusIndicator (from parent)    # フォーカスレティクル
```

`LutType` enum (natural/fuji/mono) に:
- `label`, `subtitle`: UI 表示名
- `colorMatrix`: ColorFilter 用 20 要素行列
- `vignetteStrength`: ビネット強度

### 2. `lib/features/camera/widgets/lut_selector.dart` (新規)
- `AnimatedContainer` でフィルムストック切替チップ
- 選択時: `HapticFeedback.selectionClick()`
- ラベル名 + フィルム番号表示

### 3. `lib/features/camera/camera_notifier.dart` (更新)
- `CameraState` に `LutType selectedLut` 追加（デフォルト: natural）
- `CameraNotifier.setLut(LutType)` メソッド追加

### 4. `lib/features/camera/camera_screen.dart` (更新)
- `_TappableCameraPreview` → `FilmPreviewWidget` に置き換え
- **シャッターフラッシュ**: `FadeTransition` 白フラッシュ（180ms forward → reverse）
- **フォーカスレティクル**: 4コーナー型 `_FocusReticlePainter`（スケール+フェードイン）
- LUT セレクターをシャッター上部に配置
- 戻るボタン追加（ヘッダー左）

### 5. `lib/features/develop/develop_screen.dart` (全面更新)
**現像中アニメーション**:
- フィルムストリップが流れる背景 (`_FilmStripPainter`)
- 暗室ランプ（暗赤色グロー）
- 化学処理プログレスバー（薄赤）
- 現像ステージテキスト: D-76 → 停止液 → 定着液 → 水洗い

**現像完了**:
- FadeTransition でスムーズ表示
- 写真タイルに `ColorFiltered` でフィルムストック適用
- 各タイルがスタガー（55ms 間隔）でフェードイン+スケールアップ
- フィルムストック名バッジ表示

---

## 技術的補足: なぜ FragmentShader を live preview に使わなかったのか

`film_iso800.frag` は `uniform sampler2D uTexture` でカメラフレームを受け取る設計。
Flutter の `Texture` ウィジェットはプラットフォームテクスチャをレンダリングするが、
`dart:ui Image` としてフレームごとにアクセスするには `RenderRepaintBoundary.toImage()` が必要で、
60fps では ~16ms の追加コストが生じてしまう。

代替として:
- カラーグレード: `ColorFilter.matrix`（Skia/Impeller GPU パス）
- グレイン: Dart CustomPainter（12fps で負荷軽減）
- ビネット: `RadialGradient` CustomPainter
- 光学ソフトネス: `BackdropFilter(blur: 0.3)`

**静止画（DevelopScreen）では** `ColorFilter.matrix` で LUT を適用済み。
将来フェーズで `FragmentProgram.fromAsset('shaders/film_iso800.frag')` を使った
静止画の高品質レンダリングパイプラインを追加予定。

---

## 所感・小言

> Kenji（前担当）の cleanup は丁寧だった。`withOpacity` の修正やハプティクス整備は正しい。
> ただ、カメラ起動時のローディングが `CircularProgressIndicator` + テキストのまま残っていた。
> 今回のコードで `LOADING` のミニマルスタイルに変えた。細部が積み重なってプロダクトになる。
>
> `film_iso800.frag` は美しく書けている。ハレーションのガウシアンサンプリングは
> 本物のフィルム物理を理解している人が書いた。誰が書いたか知らないが、敬意を表する。

---

## 変更ファイル

| ファイル | 変更種別 |
|---------|---------|
| `lib/features/camera/widgets/film_preview.dart` | 新規 |
| `lib/features/camera/widgets/lut_selector.dart` | 新規 |
| `lib/features/camera/camera_notifier.dart` | 更新 |
| `lib/features/camera/camera_screen.dart` | 全面更新 |
| `lib/features/develop/develop_screen.dart` | 全面更新 |
