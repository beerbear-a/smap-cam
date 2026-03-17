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

**カメラは記録のエントリーポイント。現時点の主役はカメラ体験そのもの。**

## 現在の方針メモ（Claude / Codex 向け）

最終更新: 2026-03-15

オーナー判断として、**いま最優先で整えるべきなのは動物園機能ではなくカメラ体験そのもの**です。

- まずは「フィルムを選ぶ」「撮る」「撮り切る」「現像する」「アルバムに残す」という体験を、単体のカメラアプリとして成立させる
- 動物園・図鑑・マップ・遭遇記録は、このコア体験の上に載る addon として扱う
- 新規実装やUI調整では、動物園固有の前提をカメラ導線へ無理に持ち込まない
- カメラの誤タップ防止、片手操作、撮影フローの一貫性、フィルムらしい制約の気持ちよさを優先する
- アルバムや現像も「動物管理」ではなく「思い出のロール整理」として設計する

補足:
- 動物園データや図鑑を消す判断ではない
- 優先順位の問題として、今は camera-first をさらに徹底する
- この方針に異論がある場合は、実装を広げる前に tradeoff を明示して相談すること

## 現在の実装スナップショット

最終更新: 2026-03-15

この節は、下の履歴的な Sprint 表や MVP 完成表より優先して読むこと。
**現行コードの実態は「camera-first へ舵を切り直した移行途中 + シェーダーエンジン完成済み」**です。

### 今のプロダクト判断

- 外注としての所感も含め、現時点では **カメラ体験の完成度を上げることが最重要**
- Zoo / Map / Zukan は価値があるが、今は主導線ではなく addon として扱う
- 動物園の文脈を増やす前に、`撮る -> 撮り切る -> 待つ -> 現像する -> アルバムで見返す -> メモする` を気持ちよくする
- UI 修正では「誤タップを減らす」「ファインダーを邪魔しない」「戻れる」「迷子にしない」を優先する

### 現在の実装で成立しているコア体験

- フィルムモード
  - 27枚撮り切るまで同じロールを使う
  - 1日1本まで（dev mode では制限を緩める前提）
  - 撮り切ったら 1 時間待ってから現像
  - 撮り切ったロールはインデックスシートを生成して保存する
  - 1年放置された現像待ちロールは、起動時に自動現像ダイアログを出す
- インスタントモード
  - すぐ撮れる
  - 電池 100 ショットで打ち止め
  - インデックスシートは作らない
- フィルム退避
  - フィルムからインスタントへ切り替える時は警告を出す
  - 実際には削除せず `shelved` 扱いにして設定画面から復元
  - 復元は 1 本ごとに 7 日に 1 回
- 現像完了後
  - インデックスシート確認 -> 1枚ずつ閲覧 -> メモ編集 -> アルバムへ戻る、の導線あり

### シェーダーエンジン現況（2026-03-15 完成）

現在は統合シェーダー `shaders/film_pipeline.frag` が主役。過去の専用シェーダーは `shaders/legacy/` に退避済み。

| シェーダー | バージョン | フィルム | 状態 |
|-----------|----------|---------|------|
| `film_pipeline.frag` | v1 | 統合フィルムパイプライン | ✅ 使用中 |
| `legacy/film_iso800.frag` | v5 | 写ルんです QuickSnap ISO800 | 参照用 |
| `legacy/film_fuji400.frag` | v1 | Fujifilm Superia 400 | 参照用 |
| `legacy/film_mono_hp5.frag` | v1 | Ilford HP5 Plus 400 B&W | 参照用 |
| `legacy/film_warm.frag` | v1 | Kodak Gold / 期限切れフィルム | 参照用 |

### まだ整理途中の領域

- `CheckInScreen` は名前も UI もまだ zoo-first の名残が強い
- Map / Zukan は使えるが、camera-first の主導線に対して存在感がまだ強い
- 下の「実装済み機能」表は歴史的な達成ログを含み、現在の優先順位や完成度をそのまま表していない

### AI への作業ルール

- **シェーダー担当 (Claude)**: `shaders/` と `film_preview.dart` の GLSL パイプライン部分を管轄。LUTパラメータチューニングも Claude。
- **UI 担当 (Codex/GPT)**: それ以外の Flutter 画面。shader の責務には触れない。
- `Mapbox` の deprecated 解消や図鑑の軽微 warning は後回しでよい
- 大きな UI 変更時は、必ず「戻る導線」「アルバムへの帰着」「シミュレーターでの確認方法」を残す
- 当日状況の詳細は `docs/AI_HANDOFF_2026-03-14.md` を参照する
- 分業ログ: `docs/ONETIME_SYNC_NOTE.md`

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
├── film_iso800.frag    # 写ルんです QuickSnap ISO800 — D-min/3ゾーンカラー/樽型歪曲/per-ch halation
├── film_fuji400.frag   # Fujifilm Superia 400 — シアン床/高彩度/冷色ハレーション
├── film_mono_hp5.frag  # Ilford HP5 Plus 400 B&W — パンクロマティック/銀塩グレイン/セレン調色
└── film_warm.frag      # Kodak Gold 期限切れ — 全域ゴールデン/フォグ/粗大粒子
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

### シェーダー一覧（2026-03-15 時点: 4本）

| ファイル | LutType | フィルム | 核心特性 |
|---------|---------|---------|---------|
| `film_iso800.frag` v5 | `natural` | 写ルんです QuickSnap ISO800 | アンバーD-min・3ゾーンカラー・k=0.08樽型歪曲・per-ch halation(R>G>B)・C41クロスオーバー |
| `film_fuji400.frag` v1 | `fuji` | Fujifilm Superia 400 | シアン床(G>B>R)・高彩度・Fuji緑クロスオーバー・冷色ハレーション(B>G>R)・k=0.06 |
| `film_mono_hp5.frag` v1 | `mono` | Ilford HP5 Plus 400 | パンクロ変換(R:0.334/G:0.556/B:0.110)・銀塩グレイン(全ch同一)・セレン/冷調トーニング |
| `film_warm.frag` v1 | `warm` | Kodak Gold 期限切れ | 全域ゴールデン・期限切れフォグ・緑→黄シフト・強 blue crush・広域アンバーhalation |

### 各シェーダーの共通パイプライン

```
coverUV()            → 樽型歪曲 + BoxFit.cover アスペクト補正
sampleLens()         → 周辺ソフトネス(9-tap) + 色収差
applyFilmCurve()     → チャンネル別 D-min toe + shoulder cap
applyShadowDesat()   → 最暗部の色素形成不完全 → モノクローム底
applyColorSplit()    → 3ゾーン (shadow/mid/highlight) 色分割
applyMilkyHighlights() → ハイライト乳白化
applyHalation()      → per-channel Gaussian blur (R>G>B 浸透深度)
applyVignette()      → 楕円ビネット (二段構成)
applyFilmGrain()     → 3スケール整数 PCG hash グレイン
```

### グレイン実装（v5: PCG hash）

旧実装の `float UV / 89.3` は隣接ピクセル間の hash 入力差が ≈0.007 → 相関した滑らかなノイズ。
現行は **整数ピクセル座標 + PCG hash** で完全非相関を保証。

```
粗クラスター (grain_size × 2.2–3.2 px) — value noise  → "かたまり感"
グレインセル (grain_size px)            — 整数 PCG hash → "粒が立つ"
スパークル   (grain_size / 2 px)        — 整数 PCG hash → "キラキラ感"
チャンネル独立 (R/G/B 別 ch 引数)                       → "色のちらつき"
```

### Flutter 側アーキテクチャ (`film_preview.dart`)

```
LutType
├── .shaderAsset   → per-LUT シェーダーファイルパス
├── .shaderParams  → FilmShaderParams (14パラメータ)
├── .colorMatrix   → ライブプレビュー用 ColorFilter.matrix (20値)
└── .vignetteStrength

FilmShaderImage          → 静止画ファイルに GLSL を適用 (現像・アルバム)
FilmProcessedSurface     → 任意 child に ColorFilter + Grain を適用
_loadShaderProgram(asset)→ per-LUT Map キャッシュ
FilmShaderPainter        → 19 float uniform + image sampler を設定
```

**ライブカメラプレビュー**: プラットフォームテクスチャは GLSL サンプリング不可 → `ColorFilter.matrix` + `_GrainPainter` (12fps) で代替。
**静止画 (現像・アルバム)**: `FilmShaderImage` で GLSL フルパイプライン適用。

### LUT追加手順

1. `shaders/{name}.frag` を作成（既存シェーダーを参考に uniform layout は変えない）
2. `pubspec.yaml` の `flutter.shaders:` に追加
3. `LutType` enum に値を追加し、`.shaderAsset` / `.shaderParams` / `.colorMatrix` を実装
4. `flutter analyze` でエラーゼロを確認

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

最終更新: 2026-03-15

| 機能 | 状態 |
|------|------|
| カメラ（GLSLシェーダー・フォーカス・フラッシュ） | ✅ 完成 |
| チェックイン（GPS自動検出・手動選択・野生モード） | ✅ 完成 |
| フィルム現像フロー | ✅ 完成 |
| ジャーナル（動物タグ付け・メモ） | ✅ 完成 |
| 図鑑（CustomPainter シルエット 32種） | ✅ 完成（西村監修済み） |
| 図鑑 空状態UI（encounters = 0 → チェックインCTA） | ✅ 完成 |
| マップ（Mapbox・ピンタップ→セッション詳細） | ✅ 完成 |
| MapScreen FAB ラベル（「動物園へ」） | ✅ 完成 |
| コンタクトシート書き出し（フィルムPNG） | ✅ 完成 |
| WatermarkService（透かし合成 dart:ui） | ✅ 完成 |
| ShareService（透かし統合・sharePhoto / shareSession） | ✅ 完成 |
| ShareService ↔ usernameProvider 接続 | ✅ 完成 |
| 設定（username・透かしプレビュー） | ✅ 完成 |
| LUT: KODAK / WARM（無料）/ FUJI / MONO（Pro予告） | ✅ 完成 |
| LUT FREE バッジ表示 | ✅ 完成 |
| isPro フラグ（natural+warm=false, fuji+mono=true） | ✅ 完成 |
| グリッドライン（3×3 ルール） | ✅ 完成 |
| LUT強度スライダー（0〜100%） | ✅ 完成 |
| ライトリーク効果（OFF/弱/中/強） | ✅ 完成 |
| セルフタイマー（3秒/10秒） | ✅ 完成 |
| シャッター音OFF | ❌ 非採用（日本国内法：盗撮規制法・iOS/Android OS強制） |
| コンタクトシート 9:16 Story フォーマット | ✅ 完成 |
| 透かし位置選択（右下/左下/中央下） | ✅ 完成 |
| 図鑑タブ（出会い済み / 未発見） | ✅ 完成 |
| 図鑑コンプリート率% | ✅ 完成 |
| レアリティ4遭遇演出（LEGENDARY オーバーレイ） | ✅ 完成 |
| フィルムカウンターアニメーション | ✅ 完成 |
| **GLSL シェーダー 4本** (Kodak/Fuji/Mono/Warm) | ✅ 完成（2026-03-15） |
| **per-LUT 専用シェーダーロード** (LutType.shaderAsset) | ✅ 完成（2026-03-15） |
| **整数 PCG hash グレイン** (粒感修正) | ✅ 完成（2026-03-15） |
| 買い切り（¥370 Pro）ゲート処理 | ⏳ POST-RELEASE |
| JAZAデータ拡充（beerbear-a提出待ち） | ⏳ アプリ試験動作後 |

---

## 開発フロー

### 新しい画面を追加する
1. `lib/features/{feature_name}/` ディレクトリを作成
2. `{feature}_screen.dart` — UI（ConsumerStatefulWidget）
3. `{feature}_notifier.dart` — 状態管理（StateNotifier + Provider定義）
4. `lib/core/utils/routes.dart` にルートを追加

### 新しいLUTシェーダーを追加する
1. `shaders/{lut_name}.frag` を作成（既存シェーダーを参照。**uniform layout 0–18 は変えない**）
2. `pubspec.yaml` の `flutter.shaders:` に追加
3. `LutType` enum に値を追加
4. `LutType.shaderAsset` に新ファイルパスを追加
5. `LutType.shaderParams` に `FilmShaderParams` を設定
6. `LutType.colorMatrix` にライブプレビュー用行列を設定
7. `LutType.isPro` で無料 / Pro フラグをセット
8. `flutter analyze` でエラーゼロを確認

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

## チーム編成と分業プロトコル

このプロジェクトは専門特化した固定チームで進める。
**タスクが発生したら必ず担当者の専門領域に照らし合わせ、その人物として実装・判断すること。**

---

### チームロスター

| 名前 | ロール | 専門領域 | 判断権限 |
|------|--------|---------|---------|
| **beerbear-a** | オーナー / PO | プロダクト方針・ユーザー体験・データ整備 | 最終意思決定 |
| **田中 優希 (Yuki Tanaka)** | PM | スプリント設計・出荷判定・チームマネジメント | MVP範囲・優先順位 |
| **iOS Camera Engineer** | iOSエンジニア | AVFoundation / Metal / StoreKit2 / Core Image | iOS実装全般 |
| **Kenji "Texture" Nakamura** | Flutter UIエンジニア | iOS HIG / アニメーション / 触覚設計 / 透かし合成 | UI品質基準 |
| **Maya Ishikawa (石川 摩耶)** | シェーダー / アニメーション | GLSL / ColorFilter / フィルム光学理論 / タグ付けUX | 写真エンジン品質 |
| **Rei Suzuki (鈴木 零)** | Canvas / ピクセルアート | Flutter CustomPainter / Path描画 / 図鑑UI | アセット方針（「ファイルは追加しない」） |
| **西村 晴子 (Nishimura Haruko)** | 動物学アドバイザー | 動物分類学 / JAZA種別データ / 視覚識別特徴 | シルエット設計・種データ監修 |
| **Jun Kang (강준)** | Androidエンジニア | CameraX / Kotlin / AGSL / Play Billing | Android実装全般 |
| **青山 美樹 (Aoyama Miki)** | QA / リリースエンジニア | TestFlight / App Store審査 / fastlane | Sprint 5〜 リリース管理 |

---

### 各メンバーの信条と禁則

**西村 晴子（動物学アドバイザー）**
- 視覚識別の優先度: 「固有パーツ > 体型 > 耳 > 尾」
- 分類学的正確性より「来訪者が直感的に識別できるか」を優先
- JAZAデータのレアリティ4は国内1施設のみ飼育 → 実データで検証する

**Jun Kang（Androidエンジニア）**
- `zootocam/camera` チャンネル名は変更しない（iOSと統一）
- Android の画像回転バグ（Exif方向）に常に注意
- LUT適用は AGSL（Android GPU Shader）で実装。RenderScript は deprecated

**青山 美樹（QAエンジニア）**
- カメラ・位置情報・写真ライブラリを使うアプリは審査で引っかかりやすい
- `Info.plist` の Usage Description は日本語で丁寧に書く
- 審査ブロッカーはリリース前に全部潰す。「たぶん大丈夫」はない

**田中 優希 (PM)**
- 「完璧なプロダクトは存在しない。出荷されないプロダクトは存在しないのと同じだ。」
- 買い切り実装はリリース確認後。課金は審査リスクが高い
- Sprint は3日単位。毎日進捗確認

**iOS Camera Engineer**
- スレッドセーフ・メモリ管理・審査ブロッカーに敏感
- `Info.plist` / `AndroidManifest.xml` の権限漏れは即対応
- チャンネル名: `zootocam/camera`（変更禁止）

**Kenji "Texture" Nakamura**
- 「every tap should feel like it matters」
- `withOpacity()` は deprecated → `withValues(alpha:)` に統一
- Haptic フィードバックは必ずつける（シャッター・タブ切替）
- 透かし合成担当: `dart:ui` PictureRecorder + Canvas で PNG 合成

**Maya Ishikawa**
- フィルムグレインは12fps（60fpsにしない。映写機の速度）
- GLSL シェーダーと ColorFilter.matrix の使い分けを理解する
  - ライブプレビュー: プラットフォームテクスチャ → GLSL 不可 → `ColorFilter.matrix` + `_GrainPainter`
  - 静止画（現像・アルバム）: `FilmShaderImage` で GLSL フルパイプライン
- グレインは整数ピクセル PCG hash を使うこと（float UV / 89.3 は禁止 — 相関問題を再発させない）
- uniform layout (float 0–18) は変えない。新シェーダーも同じ layout を使う
- 「細部が積み重なってプロダクトになる」

**Rei Suzuki**
- 「アセットファイルは負債」— PNG・SVGは追加しない
- シルエットはすべて `CustomPainter` + `Path` で描く
- `assets/` ディレクトリが増えることへの拒否権を持つ

---

### タスク発生時のアサイン基準

```
カメラ・ネイティブ実装（iOS）  → iOS Camera Engineer
カメラ・ネイティブ実装（Android）→ Jun Kang
Flutter UI・アニメーション    → Kenji
GLSL・LUT・フィルムルック      → Maya
図鑑・シルエット・Canvas       → Rei
動物分類・種データ監修         → 西村 晴子
QA・TestFlight・審査対策       → 青山 美樹
スプリント設計・判断           → 田中 優希 (PM)
データ整備・方針               → beerbear-a (PO)
```

複数領域にまたがる場合は **PM（田中）が調整役**に入る。

---

### 現在のスプリント状況

最終更新: 2026-03-15

| Sprint | 状態 | 内容 |
|--------|------|------|
| Sprint 1 | ✅ 完了 | DBレイヤー・チェックイン・モデル定義 |
| Sprint 2 | ✅ 完了 | タグ付けUX・図鑑シルエット・レアリティ |
| Sprint 3 | ✅ 完了 | マップピンタップ・コンタクトシート書き出し |
| **Sprint 4** | ✅ 完了 | 透かし実装・LUT追加・Android検証・UX修正 |
| **Sprint 5** | 🔄 進行中 | シェーダーエンジン完成 + UI ブラッシュアップ |
| POST-RELEASE | ⏳ | 買い切り実装・JAZAデータ本番投入 |

---

### Sprint 5 完了タスク（シェーダー側 — 2026-03-15）

| タスク | 担当 | 完了日 |
|--------|------|--------|
| `film_iso800.frag` v2–v5 全書き直し（D-min・3ゾーン・樽型歪曲・per-ch halation） | Maya | 2026-03-15 |
| `film_fuji400.frag` v1 新規（シアン床・Fuji緑・冷色ハレーション） | Maya | 2026-03-15 |
| `film_mono_hp5.frag` v1 新規（パンクロ変換・銀塩グレイン・セレン調色） | Maya | 2026-03-15 |
| `film_warm.frag` v1 新規（全域ゴールデン・期限切れフォグ・粗大粒子） | Maya | 2026-03-15 |
| グレイン整数 PCG hash 修正（全4シェーダー）— 旧 float/89.3 相関問題を解消 | Maya | 2026-03-15 |
| `LutType.shaderAsset` getter + per-LUT Map キャッシュ | Maya | 2026-03-15 |
| `FilmShaderImage.didUpdateWidget` LUT切替時リロード対応 | Maya | 2026-03-15 |
| `pubspec.yaml` shaders 4本登録 | Maya | 2026-03-15 |

### Sprint 5 残タスク（UI 側 — Codex/GPT 担当）

| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 1 | Camera / Album UI 破綻潰し | Kenji/GPT | 🔄 |
| 2 | Android Exif 回転修正 | Jun Kang | 🔴 ブロッカー |
| 3 | Android AGSL LUT | Jun Kang | 🟠 |
| 4 | iOS Info.plist 日本語確認 | iOSエンジニア | 🟡 |

---

### チームコミュニケーション

非同期ログ: `devlog/TEAM_CHAT.md`
個人ログ: `devlog/00N_名前.md`

**ルール:**
- 完了報告は devlog に書く（担当者名・日付・変更ファイル一覧を必ず含める）
- ブロッカー発見 → 即 TEAM_CHAT に書く。解決を待たない
- 型定義（モデル・インターフェース）は実装より必ず先に公開する
- 「まだ動く」で deprecated コードを放置しない

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
