# Restart Resume Checklist — 2026-03-15

この文書は、Mac 再起動後に作業抜けなく ZootoCam の開発を再開するための短期メモです。
長期方針は `CLAUDE.md`、AI 分担は `docs/PAIR_SYNC_PROTOCOL.md` を参照。

## 今回の前提

- GPT 担当: UI / UX / album / navigation / non-shader 実装
- Claude 担当: `shaders/` と shader build unblock
- いま simulator に入っているアプリは `直近成功ビルド`
- 最新 non-shader 修正はコードに入っているが、`flutter build ios --simulator --no-codesign` は shader compile 詰まりで未反映

## GPT 側で完了済み

### カメラ

- `CheckIn` でフィルム作成後、`cameraProvider.notifier.loadActiveSession()` を呼ぶように変更
  - 目的: 「フィルムを作成する」後にフィルムモードへ切り替わらない問題の修正
  - ファイル: `lib/features/checkin/checkin_screen.dart`

- インスタント時だけ LUT を出すように変更
  - フィルム時は LUT ボタン自体を出さない
  - LUT パネルはレイアウトを押し出さないフローティング形式
  - ファイル: `lib/features/camera/camera_screen.dart`

- インスタント時の上部表示をバッテリー pict + % 表示に統一
  - dev/debug でも `INSTANT 02` ではなく電池表示
  - ファイル: `lib/features/camera/camera_screen.dart`

### 図鑑

- 図鑑タブは一旦 OFF
  - 設定の初期値も `showZukan: false`
  - `main_screen.dart` 側でも `const showZukan = false` にして下タブから隠す
  - ファイル:
    - `lib/features/settings/settings_screen.dart`
    - `lib/main_screen.dart`

### アルバム

- アルバム上部に要約ストリップ追加
  - `撮影中 / 現像待ち / アーカイブ / 最近`
  - ファイル: `lib/features/album/album_screen.dart`

- ロール詳細に以下を追加
  - `1枚ずつ見る`
  - `写真アプリへ保存`
  - ロール保存時は必要なら index sheet を生成して一緒に保存
  - ファイル: `lib/features/album/album_screen.dart`

- 写真1枚表示でも `iPhone の写真へ保存` を追加
  - ファイル: `lib/features/album/photo_viewer_screen.dart`

### iPhone 写真アプリ保存

- Flutter 側 service 追加
  - `lib/core/services/photo_library_service.dart`

- iOS ネイティブ plugin 追加
  - `ios/Runner/PhotoLibraryPlugin.swift`
  - `ios/Runner/AppDelegate.swift` で登録済み

- `NSPhotoLibraryAddUsageDescription` は `Info.plist` に存在
  - ファイル: `ios/Runner/Info.plist`

## 解析状況

以下は `flutter analyze` 済み:

- `lib/features/checkin/checkin_screen.dart`
- `lib/main_screen.dart`
- `lib/features/settings/settings_screen.dart`
- `lib/features/album/album_screen.dart`
- `lib/features/album/photo_viewer_screen.dart`
- `lib/core/services/photo_library_service.dart`

non-shader 側は `No issues found`

## いまの blocker

- `flutter build ios --simulator --no-codesign` が `impellerc` で止まる
- Claude 側は `uint` 系 hash を float-only に置換したが、こちらで再実行した時点ではまだ build 完走を確認できていない
- 新しい build でも `impellerc` 4本が `UE` 状態のまま残るケースを確認済み

## 再起動後の最優先手順

### 1. 作業ブランチ確認

```bash
git status --short
git branch --show-current
```

### 2. stale build process を止める

```bash
pkill -f impellerc
pkill -f xcodebuild
sleep 2
```

### 3. simulator build を1本だけ実行

```bash
env LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
PATH="/usr/local/lib/ruby/gems/4.0.0/bin:/usr/local/opt/ruby/bin:/usr/local/bin:/usr/bin:/bin:$PATH" \
flutter build ios --simulator --no-codesign
```

### 4. build 成功なら simulator へ投入

```bash
xcrun simctl boot 7F6E6448-521F-4A47-BBEC-DFCBCFA315AE
xcrun simctl install 7F6E6448-521F-4A47-BBEC-DFCBCFA315AE build/ios/iphonesimulator/Runner.app
xcrun simctl launch 7F6E6448-521F-4A47-BBEC-DFCBCFA315AE com.udglab.zootocam
open -a Simulator
```

## 再起動後の確認チェックリスト

### カメラ

- `CheckIn -> フィルムを作成 -> カメラへ戻る` でフィルムモードになる
- インスタント時に上部がバッテリー pict になる
- フィルム時に LUT が出ない
- インスタント時だけ LUT を開ける

### ナビ

- 図鑑タブが表示されない
- `Camera / Album / Map / Settings` の流れで破綻しない

### アルバム

- 要約ストリップが出る
- ロール詳細に `1枚ずつ見る` がある
- ロール詳細に `写真アプリへ保存` がある
- 写真1枚表示からも `iPhone の写真へ保存` が押せる

### 実機準備

- shader build blocker が解消したら、次は simulator ではなく実機 build 確認へ進む
- 実機では `写真アプリ保存` の permission ダイアログ確認を行う

## Claude へ返すべき内容

もし再起動後も build が止まるなら、Claude へ返す情報はこれだけでよい:

- `flutter build ios --simulator --no-codesign` の結果
- `impellerc` が何秒で抜けるか / または止まるか
- `ps -o pid=,ppid=,state=,etime=,%cpu=,command= -p <impellerc pids>` の結果
- `simulator 投入: OK / NG`

## 触らない前提

- shader ソースは GPT 側で触らない
- `camera_screen.dart` の LUT 周りは「インスタントのみ表示」の方向を維持
- 図鑑は再開時点では戻さない
