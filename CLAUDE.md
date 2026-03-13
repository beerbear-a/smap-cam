# ZOOSMAP — エンジニア向けガイド

> 動物好きのためのカメラ × 記録アプリ
> 「撮って、記録して、発信する。」

---

## プロダクト概念

### コアコンセプト

```
カメラロール（5,000枚）に埋もれる思い出
         ↓
「あのレッサーパンダ、いつどこで会ったっけ？」
         ↓
種 × 動物園 × 日時 × 写真 × メモ で即引き出せる
```

**カメラは記録のエントリーポイント。主役は記録・図鑑・マップ。**

### 設計思想
- **Discovery Over Impression** — いいね数より、発見の感動
- **Quiet Observation** — リアルタイム共有より、静かな記録
- **Knowledge as Love** — 知ることで、動物を愛せるようになる

---

## アーキテクチャ概要

```
┌─────────────────────────────────────┐
│          Flutter UI Layer            │
│  Camera / Checkin / Zukan / Map /   │
│  Journal / Share / Settings         │
└──────────────┬──────────────────────┘
               │ Riverpod StateNotifier
┌──────────────▼──────────────────────┐
│       Application Layer             │
│  CameraNotifier / CheckinNotifier   │
│  MapNotifier / FilmSessionNotifier  │
└──────────┬──────────────────────────┘
           │
┌──────────▼──────────┐ ┌─────────────────────┐
│  Platform Channel   │ │   Local Storage     │
│  zootocam/camera    │ │                     │
│  iOS: AVFoundation  │ │  SQLite (sqflite)   │
│  Android: CameraX   │ │  FileSystem (photos)│
└─────────────────────┘ └─────────────────────┘
```

### 3つの設計原則
1. **Offline First** — 動物園の中は電波が弱い。全コア機能はSQLiteローカルで完結
2. **Camera First** — カメラ起動2秒以内。シャッターチャンスを逃さない
3. **Local Data** — ユーザーデータは端末内完結（MVP）。プライバシー保護 + コスト削減

---

## ディレクトリ構造

```
lib/
├── core/
│   ├── models/         # Dart モデル（FilmSession, Photo, Zoo, Species, Encounter）
│   ├── database/       # SQLite ヘルパー + シードデータ
│   ├── services/       # CameraService（Platform Channel）, LocationService
│   └── utils/          # ルーティング
│
├── features/
│   ├── camera/         # カメラ画面・LUTセレクター・シャッター
│   ├── checkin/        # 動物園チェックイン（GPS自動検出 + 手動）
│   ├── develop/        # フィルム現像画面（撮影後の処理）
│   ├── journal/        # 動物タグ付け・メモ
│   ├── zukan/          # 図鑑（ポケモン図鑑方式）
│   ├── map/            # Mapboxマップ + コンタクトシート書き出し
│   ├── share/          # ShareService + ContactSheetService
│   └── settings/       # ユーザー設定（username・透かし）
│
shaders/
└── film_iso800.frag    # GLSL: トーンカーブ・カラーバイアス・フィルムグレイン・
                        #       ビネット・ハレーション
```

---

## 技術スタック

| 領域 | ライブラリ / 技術 |
|------|-----------------|
| UI フレームワーク | Flutter (Dart) |
| 状態管理 | flutter_riverpod ^2.5 |
| DB | sqflite ^2.3（ローカルSQLite） |
| カメラ | Platform Channel → iOS: AVFoundation / Android: CameraX |
| 画像処理 | Flutter FragmentProgram（GLSL シェーダー） |
| 地図 | mapbox_maps_flutter ^2.3 |
| 位置情報 | geolocator ^12.0 |
| シェア | share_plus ^9.0 |
| ストレージパス | path_provider ^2.1 |

---

## 写真エンジン（最重要）

このアプリの技術的コアは **GLSL シェーダーパイプライン** です。

```
shaders/film_iso800.frag
├── Tone Curve  — S字カーブでシャドウ持ち上げ・ハイライト圧縮
├── Color Bias  — 暖色シフト（Kodak ISO800風）
├── Film Grain  — ISO800相当のフィルムグレイン（σ≈0.08）
├── Vignette    — 四隅暗化
└── Halation    — ハイライト赤チャンネル滲み
```

**LUTは現在1種。追加はシェーダーファイルを `shaders/` に追加して `pubspec.yaml` の `shaders:` セクションに登録する。**

将来的にこの写真エンジンは `packages/core_camera` + `packages/core_lut` として分離し、FestivalCAM・TravelCAM 等のエコシステムアプリが共用する予定。

---

## データモデル

### 主要テーブル

| テーブル | 役割 |
|---------|------|
| `animals` | 種マスター（JAZA 5,756種） |
| `zoos` | 動物園マスター（JAZA 加盟施設） |
| `zoo_animals` | 動物園×種マッピング |
| `encounters` | 出会い記録（ユーザーデータ核心） |
| `film_sessions` | フィルム1本 = 動物園訪問1回 |
| `photos` | 写真ファイルパス + タグ情報 |

### レアリティ算出
```
飼育施設数  レアリティ
20施設以上  ★1（よく会える）
5〜19施設   ★2（そこそこ）
2〜4施設    ★3（希少）
1施設       ★4（伝説レア）
```

### 画像ファイル管理
```
{Documents}/zoosmap/photos/{date}/
├── original/  {uuid}.jpg    ← 常に保存（非破壊編集）
└── processed/ {uuid}_lut.jpg ← Export時に生成
```

---

## Platform Channel

チャンネル名: `zootocam/camera`

| メソッド | 引数 | 戻り値 |
|---------|------|--------|
| `initializeCamera` | — | `{textureId: int}` |
| `takePicture` | `{savePath: String}` | `String`（保存パス） |
| `setFlash` | `{enabled: bool}` | `void` |
| `setFocusPoint` | `{x, y: double}` | `void` |
| `startCamera` | — | `void` |
| `stopCamera` | — | `void` |

---

## 実装済み機能（MVP状況）

| 機能 | 状態 |
|------|------|
| カメラ（GLSLシェーダー・フォーカス・フラッシュ） | ✅ 完成 |
| チェックイン（GPS自動検出・手動選択・野生モード） | ✅ 完成 |
| フィルム現像フロー | ✅ 完成 |
| ジャーナル（動物タグ付け・メモ） | ✅ 完成 |
| 図鑑（コレクション・グリッド表示） | ✅ 完成 |
| マップ（Mapbox・ピンタップ→詳細） | ✅ 完成 |
| コンタクトシート書き出し | ✅ 完成 |
| シェア（透かし・share_plus） | ✅ 完成 |
| 設定（username・透かしプレビュー） | ✅ 完成 |
| LUT追加（2種目以降） | 🔜 未着手 |
| 買い切り（¥370 Pro） | 🔜 未着手 |
| DBシード（JAZA動物データ） | 🔜 未着手 |

---

## 開発フロー

### 新しい画面を追加する
1. `lib/features/{feature_name}/` ディレクトリを作成
2. `{feature}_screen.dart` — UI（ConsumerStatefulWidget）
3. `{feature}_notifier.dart` — 状態管理（StateNotifier + Provider定義）
4. `lib/core/utils/routes.dart` にルートを追加

### 新しいLUTシェーダーを追加する
1. `shaders/{lut_name}.frag` を作成（`film_iso800.frag` をベースに）
2. `pubspec.yaml` の `flutter.shaders:` に追加
3. `lib/features/camera/widgets/lut_selector.dart` のLUT一覧に追加
4. 無料2種 / Pro以降 のフラグをセット

### データベース変更
- スキーマ変更は `lib/core/database/database_helper.dart` の `_onCreate` / `_onUpgrade`
- シードデータは `lib/core/database/seed_data.dart`

---

## コンタクトシート書き出し（フィルム機能）

`lib/features/share/contact_sheet_service.dart`

セッション（フィルム1本）の全写真を `dart:ui` Canvas で描画し、フィルムストリップ風PNGを生成します。

```
[スプロケットゾーン]
[3列グリッド × 写真]  ← BoxFit.cover、下部グラデーション、動物名ラベル
[スプロケットゾーン]
[動物園名 · 日付          ZOOSMAP]
```

呼び出し方:
```dart
final path = await ContactSheetService.generate(
  session: session,
  photos: photos,
);
await Share.shareXFiles([XFile(path)], text: '...');
```

---

## エコシステム設計（将来ロードマップ）

ZOOSMAPはシリーズ第1弾。写真エンジンを共有する複数アプリを展開予定。

```
Core Engine（将来パッケージ化）
├── packages/core_camera  ← CameraService + ネイティブブリッジ
└── packages/core_lut     ← GLSLシェーダー群

アプリ
├── ZOOSMAP     — 動物 × 動物園          ← 現在ここ
├── FestivalCAM — アーティスト × フェス   ← 第2弾
├── TravelCAM   — スポット × 旅先
└── PhotoCAM    — 汎用フィルムカメラ（DAZZ競合）
```

**各アプリの透かしがお互いを宣伝し合うエコシステム。**
FestivalCAMはZOOSMAPと思想が完全一致（タイムカプセル体験・静かな記録）。
PhotoCAMはエンジンに10〜20種のLUTが揃ってから。

---

## マネタイズ

```
無料
├── カメラ・記録・図鑑・マップ: 全機能無料
└── LUT: 2種（Natural / Warm）

Pro（¥370 買い切り）
├── 全LUT解放
├── 透かしカスタマイズ
└── 高画質書き出し

無料ユーザーの透かし投稿 = ゼロコスト広告
損益分岐点: 52本（年間固定費 ¥16,230 ÷ 手取り ¥314.5/本）
```

---

## 主要ドキュメント

| ファイル | 内容 |
|---------|------|
| `docs/01_product_requirements.md` | PRD・コア機能定義 |
| `docs/02_market_analysis.md` | 市場分析・競合・GTM |
| `docs/03_architecture.md` | アーキテクチャ設計 |
| `docs/04_data_model.md` | DBスキーマ・Dartモデル |
| `docs/05_ux_flow.md` | UXフロー |
| `docs/06_business_plan.md` | ビジネスプラン・ロードマップ |
| `docs/07_technical_spec.md` | 技術仕様（カメラ・LUT・透かし・課金） |
| `docs/08_festival_cam.md` | FestivalCAM プロダクト定義 |
