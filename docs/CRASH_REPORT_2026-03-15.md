# クラッシュ報告 — iOS 26.3.1 実機テスト

作成日: 2026-03-15

---

## 症状

- アプリが起動直後にクラッシュ（スプラッシュ後に落ちる）
- デバッグモード / リリースモード 両方で再現
- Impeller無効化（`FLTEnableImpeller = false`）後も再現

---

## 環境

| 項目 | バージョン |
|------|-----------|
| 実機 iPhone | iOS **26.3.1** (23D8133) |
| macOS | 26.3.1 (25D2128) |
| Xcode | **26.4 beta** (17E5179g) |
| Flutter | 最新 stable |

---

## 試したこと

| 対処 | 結果 |
|------|------|
| `flutter run --debug` | タイムアウト（Dart VM Service未接続）→ クラッシュ |
| `flutter run --release` | インストール成功・起動直後クラッシュ |
| `FLTEnableImpeller = false` を Info.plist に追加 | 変わらずクラッシュ |
| Podfile に `CODE_SIGNING_ALLOWED = NO` 追加 | コード署名エラーは解消、クラッシュは継続 |

---

## ビルドログ上の手がかり

### 1. impellerc クラッシュ（Mac側、ビルド時）

```
~/Library/Logs/DiagnosticReports/impellerc-2026-03-15-104420.ips
```

macOS 14.6.1 の `impellerc`（Impellerシェーダーコンパイラ）が Rosetta 経由で動いておりクラッシュ。
ただしビルド自体は最終的に成功している（Xcode build done と表示）。

### 2. デバッグ接続タイムアウト

```
The Dart VM Service was not discovered after 60 seconds.
Xcode is taking longer than expected to start debugging the app.
Error starting debug session in Xcode: Timed out waiting for CONFIGURATION_BUILD_DIR to update.
```

→ Flutter + Xcode 26 beta の相性問題と思われる。

### 3. コード署名エラー（初回）

```
Failed to verify code signature of MapboxCoreMaps.framework: 0xe800801c (No code signature found.)
```

→ Podfile修正で解消済み。

---

## 調査してほしい点（Codex向け）

1. **iOS 26.3.1 + Flutter でのクラッシュ既知事例**
   Flutter GitHub / Discord に同様の報告がないか確認。

2. **GLSLシェーダー（FragmentProgram）の互換性**
   このアプリは `flutter_gpu` ではなく `FragmentProgram` API でGLSLシェーダーを使用。
   iOS 26 beta で `FragmentProgram.fromAsset()` が落ちる事例がないか確認。
   該当ファイル: `lib/features/camera/widgets/film_preview.dart`

3. **Mapbox Maps Flutter の iOS 26 対応状況**
   `mapbox_maps_flutter ^2.3` が iOS 26 beta でクラッシュするケースがないか確認。
   Mapbox GitHub Issues を確認。

4. **`impellerc` Rosetta クラッシュの影響**
   シェーダーが正しくコンパイルされていない可能性。
   `--no-enable-impeller` フラグで回避できるか試す:
   ```bash
   flutter run -d <device_id> --release --no-enable-impeller
   ```

---

## 試してほしい対処（優先順）

```bash
# 1. Impeller完全無効でビルド（CLIフラグ版）
flutter run -d <device_id> --release --no-enable-impeller

# 2. Skiaレンダラー強制指定
flutter run -d <device_id> --release --dart-define=FLT_ENABLE_IMPELLER=false

# 3. シェーダーウォームアップ無効
flutter build ipa --release --no-enable-impeller
# → .ipa を Xcode の Devices & Simulators から手動インストール

# 4. Mapboxを一時コメントアウトして最小ビルド確認
# lib/main_screen.dart の MapScreen をダミー画面に差し替え
```

---

## 関連ファイル

- `ios/Runner/Info.plist` — `FLTEnableImpeller = false` 追加済み
- `ios/Podfile` — `CODE_SIGNING_ALLOWED = NO` 追加済み
- `shaders/` — GLSL 4本（FragmentProgram API使用）
- `lib/features/camera/widgets/film_preview.dart` — シェーダーロード処理

---

## 補足

iOS 26 beta + Xcode 26 beta の組み合わせ自体がまだ不安定な可能性が高い。
安定版リリース後に再テストする選択肢も検討してください。
