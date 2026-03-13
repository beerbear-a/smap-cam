# [002] iOS UI/設計レビュー & ブラシアップ

**エンジニア:** Kenji "Texture" Nakamura（伝説のiOS UIエンジニア）
**担当領域:** Flutter UI / iOS HIG / アニメーション / 触覚設計
**日付:** 2026-03-13
**ステータス:** ✅ 完了

---

## 自己紹介

元 Apple UIKit チームを経て独立。数百万 DL アプリを複数手がける。
「*every tap should feel like it matters*」が信条。
触覚フィードバック・アニメーションの物理的リズム・タイポグラフィの重力——それが言語。

---

## 診断サマリー

| # | 問題 | 深刻度 | ファイル |
|---|------|-------|---------|
| 1 | `ShutterButton` にデッドコード (`_handleTap` 未使用) + Haptic なし | 🔴 | `shutter_button.dart` |
| 2 | `withOpacity()` 全面使用（Flutter 3.x deprecated） | 🟠 | 4ファイル |
| 3 | ボトムナビにアクティブインジケーターなし + Haptic なし | 🟠 | `main_screen.dart` |
| 4 | `FilmCounterWidget` が視覚的に弱い（テキストのみ） | 🟡 | `film_counter_widget.dart` |
| 5 | `_UsernameField` で `onSubmitted` + `onEditingComplete` 二重呼び出し | 🟡 | `settings_screen.dart` |
| 6 | ZukanScreen 詳細写真が `firstPhoto` 1枚のみ (`childCount: 1`) | 🟡 | `zukan_screen.dart` |
| 7 | 画面遷移が Material デフォルトスライド（カメラアプリと不一致） | 🟡 | 複数 |

---

## 対応詳細

### 1. ShutterButton 修正
- **デッドコード削除**: `_handleTap()` メソッドを削除（`onTapDown`/`onTapUp`で直接ハンドリング）
- **Haptic 追加**:
  - `onTapDown`: `HapticFeedback.lightImpact()` （指が触れた感覚）
  - `onTapUp`: `HapticFeedback.mediumImpact()` （シャッターを切った感覚）
- **`_isPressed` フラグ**: `onTapCancel` 時の誤発火を防止
- `withOpacity` → `withValues(alpha:)` 修正

### 2. FilmCounterWidget 再設計
- テキストのみ → **プログレスバー + 数値** の組み合わせ
- 残り 5 枚以下: オレンジ警告色
- 残り 0 枚: 赤色 + 赤枠ボーダー
- 数値は 2桁ゼロ埋め (`01`, `05`, `27`)
- `withOpacity` → `withValues(alpha:)` 修正

### 3. ボトムナビゲーション改善
- **アクティブインジケータードット**: `AnimatedContainer` で滑らかに表示/非表示
- **テキストアニメーション**: `AnimatedDefaultTextStyle` でウェイト変化
- タブ切替時に `HapticFeedback.selectionClick()`
- 同タブ再タップ時は Haptic / setState スキップ
- `withOpacity` → `withValues(alpha:)` 修正
- アイコン変更: `auto_awesome_mosaic` → `grid_view`（より適切）、`tune` 維持

### 4. `withOpacity` deprecation 全修正
対象ファイル:
- `journal_screen.dart`: `withValues(alpha: 0.05)`
- `zukan_screen.dart`: `withValues(alpha: 0.06)`
- `settings_screen.dart`: `withValues(alpha: 0.04)`
- `map_screen.dart`: `withValues(alpha: 0.05)`

### 5. UsernameField 二重呼び出し修正
- `onEditingComplete` を削除（`onSubmitted` で unfocus も実行に統合）

### 6. ZukanScreen 詳細写真修正
- `AnimalEntry` に `photos: List<Photo>` フィールド追加
- `encounterCount`, `firstPhoto` を computed property に変更
- 詳細画面の写真グリッド: `childCount: 1` → `entry.photos.length`
- グリッドセルも `entry.firstPhoto` → `entry.photos[index]` に修正

### 7. フェードページ遷移
- `lib/core/utils/routes.dart` 新規作成: `DarkFadeRoute<T>`
  - duration 400ms in / 300ms out
  - `Curves.easeIn` で自然な暗転感
- 適用箇所:
  - MapScreen → CameraScreen
  - CameraScreen → DevelopScreen
  - DevelopScreen → JournalScreen
  - JournalScreen → MapScreen（pushAndRemoveUntil）

---

## 変更ファイル

| ファイル | 変更種別 |
|---------|---------|
| `lib/features/camera/widgets/shutter_button.dart` | 修正 |
| `lib/features/camera/widgets/film_counter_widget.dart` | 再設計 |
| `lib/main_screen.dart` | 改善 |
| `lib/features/journal/journal_screen.dart` | 修正 |
| `lib/features/zukan/zukan_screen.dart` | 修正 |
| `lib/features/settings/settings_screen.dart` | 修正 |
| `lib/features/map/map_screen.dart` | 修正 |
| `lib/features/camera/camera_screen.dart` | 修正 |
| `lib/features/develop/develop_screen.dart` | 修正 |
| `lib/core/utils/routes.dart` | 新規 |

---

## 所感

コードの骨格は良い。「フィルムカメラ体験」というコンセプトが一貫している。
次フェーズで改善すべき点があるとすれば:
1. **LUT プレビューシェーダー**: カメラプレビューにフィルムルックを乗せる
2. **撮影音**: AVAudioSession を使ったシャッター音（消音モード無視の制御）
3. **VoiceOver 対応**: アクセシビリティラベルの整備
