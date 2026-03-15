# AI Handoff — 2026-03-15

この文書は Claude → Codex/GPT への Sprint 5 完了時点の引き継ぎメモです。
思想・チーム構成・全体方針は `CLAUDE.md` を参照してください。

---

## 1. Sprint 5 で完了したこと（Claude 担当分）

### シェーダーエンジン（Maya 担当）
4本すべて完成。詳細は `CLAUDE.md` の「写真エンジン」節を参照。

| シェーダー | バージョン | 状態 |
|-----------|---------|------|
| `film_iso800.frag` | v5 | ✅ 完成 |
| `film_fuji400.frag` | v1 | ✅ 完成 |
| `film_mono_hp5.frag` | v1 | ✅ 完成 |
| `film_warm.frag` | v1 | ✅ 完成 |

### カメラ体験バグ修正（Kenji 担当）

| 修正内容 | ファイル |
|---------|---------|
| インスタントモードをPro有料化（paywall sheet実装） | `camera_screen.dart` |
| 撮り切り後 `_RollCompletedOverlay` で画面固定 | `camera_screen.dart` |
| `_RollCompletedOverlay` と bottom sheet の同時表示バグを解消 | `camera_screen.dart` |
| 撮り切り後「残り01」が残るステートマシンバグ修正 | `camera_notifier.dart` |
| ロールなし時の `∞` 表示を非表示 | `camera_screen.dart` |
| セッションインジケーターをタップでセッション詳細ダイアログ | `camera_screen.dart` |
| フィルム作成時にLUT（銘柄）を選択可能に | `checkin_screen.dart` |
| 焼き込み時のLUTがnatural固定だったのを選択中LUTに修正 | `camera_notifier.dart` |
| アルバムがセッション変更後に自動更新されない問題修正 | `album_screen.dart` |
| フォトビューアーのアスペクト比崩れ修正 | `photo_viewer_screen.dart` |
| フォトビューアーにピンチズーム追加 | `photo_viewer_screen.dart` |
| フォトビューアーでフィルムグレイン・ビネットが消えていたのを修正 | `photo_viewer_screen.dart` |
| Mapboxトークンをgitignore管理に変更（セキュリティ） | `Info.plist` / `secrets.xcconfig` |

---

## 2. 重要な実装の変更点（次に触る人向け）

### 2-1. `_RollCompletedOverlay` の状態管理

`camera_screen.dart` の `_RollCompletedOverlay` と bottom sheet は **同時に出さない** 設計。

```
completedRollSession != null  →  _RollCompletedOverlay を表示（画面固定）
                                  ↓ ユーザーが「次のステップへ」ボタンを押す
                                  → _showRollCompletedActions() を呼ぶ
```

**やってはいけないこと:**
- `addPostFrameCallback` で自動的に `_showRollCompletedActions` を呼ぶ（旧バグの再発）
- `clearCompletedRollPrompt()` を「新しいフィルムをつくる」ボタン押下時に呼ぶ（旧バグの再発）

`completedRollSession` のクリアは `camera_notifier.dart` の `loadActiveSession()` が担う。
新セッションが作成されて `loadActiveSession()` が呼ばれると自動でクリアされる。

```dart
// camera_notifier.dart
Future<void> loadActiveSession() async {
  final session = await DatabaseHelper.getActiveSession();
  if (session != null) {
    state = state.copyWith(activeSession: session, clearCompletedRollSession: true);
  } else {
    state = state.copyWith(activeSession: null);
  }
}
```

### 2-2. フォトビューアーの写真表示

`photo_viewer_screen.dart` の `_buildItemSurface` は3パターン。

```dart
// 1. ファイルなし → モック
// 2. インデックスシート → Image.file(fit: contain) そのまま
// 3. 焼き込み済み (_film.png) → Image.file(fit: contain) そのまま
// 4. 未焼き込み → FilmProcessedSurface(animated: false, child: Image.file(contain))
```

**やってはいけないこと:**
- `FilmShaderImage` を使うとGLSL内で `coverUV()` が動いてアスペクト比が強制的に cover になる → クロップされる
- `ColorFiltered` 単体を使うとグレイン・ビネットが乗らない

`FilmProcessedSurface(animated: false)` を使うこと。

### 2-3. Mapboxトークンの管理

`ios/Runner/Info.plist` の `MBXAccessToken` は `$(MAPBOX_ACCESS_TOKEN)` というxcconfig変数参照になっている。

実際のトークンは **gitignoreされた** `ios/secrets.xcconfig` に書かれている:
```
MAPBOX_ACCESS_TOKEN = pk.eyJ1...（実トークン）
```

新しいマシンでcloneした場合は `ios/secrets.xcconfig` を手動で作成する必要がある。
`ios/Flutter/Debug.xcconfig` と `Release.xcconfig` が `#include? "../secrets.xcconfig"` でこれを読み込む。

---

## 3. 現在の `flutter analyze` 状態

```
2 issues found（いずれも warning/info レベル）
```

- `lib/features/map/map_screen.dart` — Mapbox annotation tap listener が deprecated（後回しでよい）

エラーはゼロ。

---

## 4. Sprint 5 残タスク（Codex/GPT 担当）

| # | タスク | 担当 | 優先度 |
|---|--------|------|--------|
| 1 | Camera / Album UI の細かいブラッシュアップ | Kenji/GPT | 🔄 |
| 2 | Android Exif 回転修正（CameraXで撮影後ピクセル正規化） | Jun Kang | ✅ 済み（commit 62182b0） |
| 3 | Android AGSL LUT 実装 | Jun Kang | 🟠 |
| 4 | iOS Info.plist Usage Description 確認 | 青山 美樹 | 🟡 |

---

## 5. 触らないほうがよい箇所

- **`shaders/` と `film_preview.dart` のGLSLパイプライン部分** → Maya（Claude）の管轄。LUTパラメータのチューニングも含む。勝手に変更しない。
- **フィルムの制約（27枚・1日1本・1時間待ち）** → 意図的なUX設計。数値を変えない。
- **インスタントモードのPro判定** → `proAccessProvider` で管理。ゲートを外さない。
- **`LutType` enum の uniform layout (0–18)** → 変えると全シェーダーが壊れる。

---

## 6. 動作確認コマンド

```bash
flutter analyze          # エラーゼロを確認
flutter test             # widget_test.dart が通ること
flutter run -d <device>  # 実機確認
```

実機ビルドには `ios/secrets.xcconfig` が必要（gitignoreされているのでclone後に作成すること）。

---

## 7. 次に着手するなら（Codex 向け提案）

優先度順:

1. **`CheckInScreen` の camera-first 化** — 現在まだ zoo-first の名残が強い。「新しいロールを始める」体験として整理する。
2. **カメラ画面の micro UX** — 誤タップ防止、片手操作性の改善
3. **アルバム体験の磨き込み** — ロール詳細のビジュアル、メモ編集の快適さ
4. **Android AGSL LUT** — Jun Kang 担当。実機でLUTが効いていない場合の対応

動物園機能（Map / Zukan / Zoo data）の拡張は **このリストが終わってから**。

---

最終更新: 2026-03-15（Claude Sonnet 4.6 による Sprint 5 完了時）
