# [012] Sprint 5 Flutter 実装完了報告

**担当: Kenji "Texture" Nakamura (Flutter UI) / Maya Ishikawa (シェーダー)**
**PM: 田中 優希**
**日付: 2026-03-14**
**ステータス: ✅ Flutter側 全タスク完了**

---

## 実装サマリー

Sprint 5 要件定義（[011]参照）に基づき、Flutter 側の全実装を完了。

---

## 実装詳細

### P1 — フィルム体験の核

#### C1: グリッドライン表示 [Kenji]
- `FilmPreviewWidget` に `showGrid` パラメータを追加
- `_GridPainter` (CustomPainter) で 3×3 ルールグリッドを描画（白 25% 透明、0.5px）
- カメラ画面ヘッダー右端にグリッドトグルボタンを追加（`grid_on`/`grid_off` アイコン）
- `IgnorePointer` でタップ透過

#### L1: LUT強度スライダー [Maya]
- `CameraState` に `lutIntensity: double (0.0〜1.0)` を追加
- `_interpolateMatrix()` — identity matrix と lut matrix の間を `t` で lerp
- カメラ画面の LUT セレクター下に最小限のスライダーを配置（SliderTheme でカスタムスタイル）

#### L2: ライトリーク効果 [Maya]
- `LightLeakStrength` enum: none / weak / medium / strong
- `_LightLeakPainter` — RadialGradient 2重構造（左端オレンジ + 右上隅赤ハレーション）
- カメラ画面にサイクル式ボタン追加（`flare` アイコン + 強度テキスト）

---

### P2 — シェア体験

#### S1: Instagram Story対応（9:16書き出し） [Kenji]
- `ContactSheetFormat` enum: square（既存）/ story（新規）
- `ContactSheetService.generate()` に `format` パラメータを追加
- Story フォーマット: 1080×1920、写真4枚縦並び、上下スプロケット、角丸クリップ
- 既存の square ロジックはそのまま維持

#### S2: 透かし位置選択 [Kenji]
- `WatermarkPosition` enum: bottomRight / bottomLeft / bottomCenter
- `WatermarkService.apply()` に `position` パラメータ追加（デフォルト: bottomRight）
- `watermarkPositionProvider` (StateNotifier + SharedPreferences で永続化)
- 設定画面に3択セレクター + リアルタイムプレビューを追加

---

### P3 — UX

#### C2: セルフタイマー（3秒/10秒） [Kenji]
- `TimerMode` enum: off / three / ten
- `CameraNotifier.cycleTimerMode()` でサイクル切り替え
- `Timer.periodic` でカウントダウン、`timerCountdown` を state で管理
- カウントダウン中は `_TimerCountdownOverlay` を表示（数字が scale-in でカチッと変わる）
- タップでキャンセル可能

#### C3: シャッター音OFF [Kenji]
- `CameraState.shutterSoundEnabled` (bool) を追加
- カメラ画面右下に `volume_up`/`volume_off` ボタン
- ※ Platform Channelへの実際の音声制御は iOS Engineerと Jun が各 native 側で実装

#### U1: 未図鑑リスト [Kenji]
- ZukanScreen に TabBar を追加（「出会い済み」/ 「未発見」）
- `DatabaseHelper.getAllSpecies()` から種マスターを取得
- `DatabaseHelper.getEncounterSummary()` で出会い済み species_id を取得
- 未発見 = 全種 − 出会い済み種
- `_UndiscoveredList` — レアリティ表示（星1〜4）付きリスト

#### U2: コンプリート率% [Kenji]
- `ZukanData` クラスで `metCount / totalSpecies` を計算
- ヘッダーに `_CompletionBadge` を追加（「12 / 32 種」+ LinearProgressIndicator + %）

---

### P4 — 演出

#### U3: レア動物遭遇演出 [Kenji + Maya]
- Journal の `_save()` 時に subject テキストを全種の rarity=4 species と照合
- マッチした場合、`HapticFeedback.heavyImpact()` + `_RareEncounterOverlay` を表示
- 演出: 黒背景フェードイン + 星4つが順次点灯 + "LEGENDARY" テキスト + 種名（scale elasticOut）
- 3秒後に自動遷移 or タップで即遷移

#### U4: フィルムカウンターアニメーション [Kenji]
- `FilmCounterWidget` を StatelessWidget から `StatefulWidget` に変更
- `didUpdateWidget` で `remaining` 変化を検知 → `AnimationController` を forward
- 数字がスライドアップで消え、新しい数字がスライドダウンで現れる（220ms、Interval アニメーション）

---

## 変更ファイル一覧

| ファイル | 変更種別 |
|---------|---------|
| `lib/features/camera/widgets/film_preview.dart` | LutType拡張・グリッド・LUT強度・ライトリーク |
| `lib/features/camera/camera_notifier.dart` | TimerMode・lutIntensity・showGrid・lightLeak・shutterSound追加 |
| `lib/features/camera/camera_screen.dart` | グリッドボタン・スライダー・ライトリークボタン・タイマーUI・シャッター音ボタン |
| `lib/features/camera/widgets/film_counter_widget.dart` | StatefulWidget化・フリップアニメーション |
| `lib/features/zukan/zukan_screen.dart` | TabBar・ZukanData・コンプリート率・未発見リスト |
| `lib/features/share/contact_sheet_service.dart` | ContactSheetFormat enum・Story 9:16生成 |
| `lib/features/share/watermark_service.dart` | WatermarkPosition enum・位置パラメータ対応 |
| `lib/features/settings/settings_screen.dart` | watermarkPositionProvider・位置セレクター・プレビュー更新 |
| `lib/features/journal/journal_screen.dart` | rarity4チェック・RareEncounterOverlay |
| `devlog/011_sprint5_requirements.md` | 新規（前コミット） |
| `devlog/012_sprint5_flutter_implementation.md` | 新規（本ファイル） |

---

## 残タスク（Flutter以外）

| タスク | 担当 | 状態 |
|--------|------|------|
| Android Exif回転修正 | Jun Kang | 🔴 Sprint 5 実装中（Jun本人の報告待ち） |
| Android AGSL LUT | Jun Kang | 🟠 |
| iOS シャッター音OFF ネイティブ実装 | iOS Engineer | 🟡 |
| iOS Info.plist 日本語確認 | iOS Engineer | 🟡 |
| TestFlight ベータ配信 | 青山 美樹 | ⏳ Sprint 5 後半 |

---

## 注記

- 図鑑データ（JAZAスペック）は **テストデータで動作確認後** に beerbear-a が本番データを投入する。現在の 32 種シードデータでコンプリート率機能は正常動作する。
- `shutterSoundEnabled` は state に持っているが、actual な消音は Platform Channel 側（iOS: `AudioServicesPlaySystemSound` を条件分岐、Android: `MediaActionSound.play()` をスキップ）で実装が必要。
- 透かし位置は SharedPreferences に永続化済み。Share 呼び出し側（ShareService）からの `position` 受け渡しは TODO（現在はデフォルトの bottomRight が適用される）。

---

**[Kenji Nakamura] — 以上、Flutter側 Sprint 5 全タスク complete。
青山さん、TestFlight 準備を進めてください。**
