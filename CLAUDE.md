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

最終更新: 2026-03-14 Sprint 4 EOD

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
- 静止画LUT適用は Export時（プレビューはColorFilter.matrixで代替）
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

最終更新: 2026-03-14

| Sprint | 状態 | 内容 |
|--------|------|------|
| Sprint 1 | ✅ 完了 | DBレイヤー・チェックイン・モデル定義 |
| Sprint 2 | ✅ 完了 | タグ付けUX・図鑑シルエット・レアリティ |
| Sprint 3 | ✅ 完了 | マップピンタップ・コンタクトシート書き出し |
| **Sprint 4** | ✅ 完了 | 透かし実装・LUT追加・Android検証・UX修正 |
| **Sprint 5** | 🔜（Flutter完了）| グリッド・LUT強度・ライトリーク・タイマー・9:16・図鑑完成度・レア演出 |
| POST-RELEASE | ⏳ | 買い切り実装・JAZAデータ本番投入 |

---

### Sprint 4 完了タスク

| タスク | 担当 | 完了日 |
|--------|------|--------|
| `LutType.warm` 追加（ゴールデンアワーLUT） | Maya | 2026-03-14 |
| `isPro` フラグ設計 | Maya | 2026-03-14 |
| `WatermarkService` 実装（dart:ui Canvas合成） | Kenji | 2026-03-14 |
| `ShareService` 透かし統合 | Kenji | 2026-03-14 |
| LUTセレクター FREE バッジ | Kenji | 2026-03-14 |
| UX監査（5問題特定 / 藤井空） | Sora | 2026-03-14 |
| 動物学コードレビュー（西村晴子） | 西村晴子 | 2026-03-14 |
| シルエット修正（red_panda耳 / okapi縞 / meerkat直立） | Rei | 2026-03-14 |

---

### Sprint 4 完了（Flutter側）— Sprint 5 前提条件

| # | タスク | 担当 | 状態 |
|---|--------|------|------|
| 1 | 図鑑の空状態UI | Kenji | ✅ |
| 2 | MapScreen FAB ラベル | Kenji | ✅ |
| 3 | usernameProvider 接続 | Kenji | ✅ |
| 4 | Android Exif回転修正 | Jun Kang | 🔴 Sprint 5 ブロッカー |
| 5 | Android AGSL LUT | Jun Kang | 🟠 |
| 6 | iOS Info.plist 日本語確認 | iOSエンジニア | 🟡 |

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
