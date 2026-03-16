# ZootoCam 統合ステータス（コード確認ベース）

ドキュメントが分散しているため、現時点のコードから実装状況を整理した単一の参照先です。
このファイルの内容は `lib/`, `android/`, `ios/` の実コードを確認して作成しています。

---

## 実装済み（コード確認）

- カメラプラグイン（iOS/Android）
  - `ios/Runner/CameraPlugin.swift`
  - `android/app/src/main/kotlin/com/example/zootocam/CameraPlugin.kt`
- フィルムプレビュー + LUT/グリッド/ライトリーク/タイマー
  - `lib/features/camera/widgets/film_preview.dart`
  - `lib/features/camera/camera_notifier.dart`
  - `lib/features/camera/camera_screen.dart`
- フィルム静止画レンダリング（シェーダー適用）
  - `lib/features/camera/film_still_service.dart`
  - `shaders/film_pipeline.frag`
- DB v2（Zoo/Species/Encounter）+ シード
  - `lib/core/database/database_helper.dart`
  - `lib/core/database/seed_data.dart`
  - `lib/core/models/zoo.dart`
  - `lib/core/models/species.dart`
  - `lib/core/models/encounter.dart`
- チェックイン（近傍検索・選択）
  - `lib/features/checkin/checkin_screen.dart`
  - `lib/features/checkin/checkin_notifier.dart`
  - `lib/core/location/location_service.dart`
- Map 画面（セッションの位置ピン + ストーリーシート）
  - `lib/features/map/map_screen.dart`
  - `lib/features/map/map_notifier.dart`
- 図鑑（出会い済み/未発見タブ + コンプリート率 + レアリティ表示）
  - `lib/features/zukan/zukan_screen.dart`
- 透かし合成 + 位置設定 + シェア連携
  - `lib/features/share/watermark_service.dart`
  - `lib/features/settings/settings_screen.dart`
  - `lib/features/share/share_service.dart`
- コンタクトシート（square/index/story）
  - `lib/features/share/contact_sheet_service.dart`
- レア遭遇演出（Journal で rarity=4 検知）
  - `lib/features/journal/journal_screen.dart`
- Android Exif 回転修正
  - `android/app/src/main/kotlin/com/example/zootocam/CameraPlugin.kt`

---

## 部分実装 / 未接続

- シルエット描画は実装済みだが、図鑑 UI に未接続
  - 実装: `lib/features/zukan/widgets/animal_silhouette.dart`
  - 図鑑側は `MockPhotoView` のプレースホルダーを使用中
    - `lib/features/zukan/zukan_screen.dart`
- Encounter は DB にはあるが、実運用の保存フローがない
  - 現状の Encounter 登録はモック投入のみ
  - `lib/core/database/database_helper.dart`
- Map はセッション lat/lng によるピンのみ
  - 「動物園ピン」要件は未達
  - `lib/features/map/map_screen.dart`

---

## 未実装（コード不在）

- TaggingSheet（撮影後3秒以内のタグ付け UI）
- 撮影直後の Encounter 保存フロー（species_id + memo など）
- シャッター音 OFF UI / 設定（Flutter 側に実装なし）

---

## ログとの不一致（要更新）

- Android Exif 回転修正は実装済み
  - 進行中扱いのログは更新が必要
- シャッター音 OFF は Flutter 側に実装がなく、仕様コメントで非対応扱い
  - `lib/features/camera/camera_notifier.dart`
- 図鑑シルエットは描画コードはあるが、UI 側に未接続

