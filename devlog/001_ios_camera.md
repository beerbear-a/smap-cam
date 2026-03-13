# [001] iOS カメラ最適化

**エンジニア:** iOS Camera Engineer
**担当領域:** iOS AVFoundation / Flutter Platform Channel
**日付:** 2026-03-13
**ステータス:** ✅ 完了

---

## 診断結果

既存の `CameraPlugin.swift` に以下の問題を確認:

| # | 問題 | 影響度 |
|---|------|-------|
| 1 | `pixelBuffer` がスレッドセーフでない | 🔴 クラッシュリスク |
| 2 | デバイス方向（orientation）未処理 | 🔴 プレビュー回転バグ |
| 3 | `isHighResolutionCaptureEnabled` 未設定 | 🟡 写真品質低下 |
| 4 | タップフォーカス / タップ露出なし | 🟡 UX低下 |
| 5 | 動画スタビライゼーション未設定 | 🟡 映像ブレ |
| 6 | チャンネル名が旧名 `smap.cam/camera` | 🟠 一貫性不足 |
| 7 | `copyPixelBuffer` の CVPixelBuffer メモリ管理 | 🟡 メモリリーク潜在 |
| 8 | セッション設定の最適化不足 | 🟡 起動速度・品質 |

---

## 対応内容

### 1. スレッドセーフ化 (`pixelBuffer`)
- `NSLock` を導入し `copyPixelBuffer()` と `captureOutput()` を排他制御
- 旧: `pixelBuffer = ...` 直代入
- 新: `lock.lock(); defer { lock.unlock() }` で保護

### 2. デバイス方向対応
- `UIDevice.current.orientation` → `AVCaptureVideoOrientation` に変換
- `videoOutput.connection(with: .video)?.videoOrientation` を設定
- `AVCaptureDevice.DiscoverySession` 使用で前面/背面カメラ切替に対応

### 3. 高解像度キャプチャ有効化
- `photoOutput.isHighResolutionCaptureEnabled = true`
- `AVCapturePhotoSettings` に `isHighResolutionPhotoEnabled = true` 設定

### 4. タップフォーカス / タップ露出
- `setFocusPoint(x:y:)` メソッドをチャンネルに追加
- `AVCaptureDevice.focusPointOfInterest` + `focusMode = .autoFocus`
- `exposurePointOfInterest` + `exposureMode = .autoExpose`

### 5. 動画スタビライゼーション
- `videoConnection.preferredVideoStabilizationMode = .auto`

### 6. チャンネル名統一
- `smap.cam/camera` → `zootocam/camera`

### 7. メモリ管理改善
- `copyPixelBuffer()` で lock 保護 + retain/release サイクル明確化

### 8. セッション設定最適化
- `beginConfiguration()` / `commitConfiguration()` でまとめて変更
- AF/AE/AWB の continuous モードを明示設定
- `sessionPreset = .photo` → `hd1920x1080` (プレビュー品質向上、キャプチャ時は overridden)

---

## 変更ファイル

- `ios/Runner/CameraPlugin.swift` — 全面刷新
- `lib/core/services/camera_service.dart` — チャンネル名更新・`setFocusPoint` 追加
- `android/app/src/main/kotlin/com/example/zootocam/CameraPlugin.kt` — チャンネル名更新
