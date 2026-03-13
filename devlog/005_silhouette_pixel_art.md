# [005] シルエット & ピクセルアート実装

**エンジニア:** Rei Suzuki / 鈴木 零
**担当領域:** Flutter Canvas / ベクターシルエット / アイコンデザイン
**日付:** 2026-03-13
**ステータス:** ✅ 完了

---

## 自己紹介

元インディーゲームデベロッパー。8年間ドット絵と格闘し続けた後、
「アセットファイルは負債」という悟りを開いてモバイル開発に転向。
現在は Flutter の `Canvas` API だけで生きている。

**信条:** 「ピクセルは嘘をつかない。コードで描けないシルエットはデザインが甘い。」

SVG も PNG も必要ない。`Path` と `Paint` があれば何でも描ける。
assets ディレクトリが増えるたびに人類は少しずつ死ぬ。

---

## 診断

| 問題 | 詳細 |
|------|------|
| 図鑑が「発見済みのみ」 | 未発見種は空白。達成感ゼロ |
| シルエット画像アセット未存在 | PNG を用意する工数・容量コスト |
| レアリティが DB にあるが UI ゼロ | ゲーミフィケーションの核が見えない |

**解決策:** 画像ファイルは一枚も追加しない。全シルエットを `CustomPainter` の `Path` で描く。

---

## なぜ CustomPainter なのか

- **解像度フリー**: どんな DPI でも完璧にシャープ
- **アセット不要**: pubspec.yaml が汚れない
- **ランタイム制御可能**: 色・不透明度・アニメーション全部 Dart で動く
- **バンドルサイズ**: 32種の PNG セット ≒ 500KB vs Path 定義 ≒ 8KB
- **発見時エフェクト**: `Path` なのでそのまま `AnimatedBuilder` でリビール可能

---

## 実装内容

### `lib/features/zukan/widgets/animal_silhouette.dart` (新規)

シルエット描画システム:

```
AnimalSilhouette(assetKey, size, color)
 ├── _pathBuilders[assetKey] → Path Function(Size)?
 │   ├── 手描きPath: lion / giraffe / elephant / red_panda /
 │   │              giant_panda / penguin / polar_bear / otter /
 │   │              capybara / meerkat (10種)
 │   └── fallback: Icons.pets ベースの汎用シルエット
 └── CustomPaint(painter: _SilhouettePainter(path, color))
```

### `lib/features/zukan/zukan_screen.dart` (更新)

- 全種表示（発見済み + 未発見）に変更
- 未発見: シルエット表示（白 opacity 0.15）+ 種名表示
- 発見済み: 写真 + フィルムLUT適用 + 種名表示
- レアリティバッジ ★1〜4 追加（右上コーナー）
- 発見数カウンター追加（ヘッダー）

---

## 所感・小言

> Maya のグレインアニメーション、12fps のアプローチが正しい。
> 60fps で動かしたくなる気持ちはわかるが、フィルムグレインは「動きすぎ」がダメ。
> 映写機のフレームレートを意識した判断。センスがある。
>
> Kenji の `withValues(alpha:)` 対応も正しい。
> `withOpacity` は deprecated だが、まだ動く。「まだ動く」で放置するチームは崩れる。
>
> 課題 #8（シルエット画像）をブロッカーにしたのは正解。
> でも自分が来た以上、ブロッカーは消した。アセットは一枚もいらない。

---

## 変更ファイル

| ファイル | 変更種別 |
|---------|---------|
| `lib/features/zukan/widgets/animal_silhouette.dart` | 新規 |
| `lib/features/zukan/zukan_screen.dart` | 更新 |
| `devlog/005_silhouette_pixel_art.md` | 新規 |
| `devlog/README.md` | 更新 |
