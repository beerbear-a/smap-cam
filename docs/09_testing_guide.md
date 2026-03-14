# ZootoCam — 試験動作ガイド

> はじめてアプリを実機で動かすための手順書。
> beerbear-a・チームメンバー向け。コマンドをコピペすれば動く想定で書いています。

---

## 0. 全体像を理解する

```
このアプリで「動作確認」に必要なもの

実機（必須）
├── iPhone（iOS 14以上）  ← カメラが使えるのは実機のみ
└── Android（API 24以上） ← Pixel推奨。Jun Kangが持っているPixel 8 Pro

開発PC（1台でOK）
├── Mac          ← iOSビルドに必須（Windowsでは不可）
├── Xcode 15+   ← App Store提出・実機インストールに必要
└── Android Studio または Flutter CLI

必要なアカウント
├── Apple Developer Program（年間 ¥13,800）  ← 実機インストールに必要
├── Mapbox アカウント（無料枠あり）           ← マップ表示に必要
└── Googleアカウント                          ← Android向け（任意）
```

> **シミュレーター・エミュレーターでの制約:**
> カメラ（Platform Channel）はシミュレーターでは動きません。
> マップ・図鑑・設定画面はシミュレーターで確認できます。

---

## 1. 開発環境の準備

### 1-1. Flutter SDK のインストール

```bash
# Homebrew でインストール（Mac）
brew install --cask flutter

# バージョン確認
flutter --version
# Flutter 3.22 以上であること

# 環境チェック（問題が出たら都度解決）
flutter doctor
```

**`flutter doctor` の出力例（全項目 ✓ になれば OK）:**
```
[✓] Flutter (Channel stable, 3.22.x)
[✓] Android toolchain
[✓] Xcode - develop for iOS and macOS
[✓] Android Studio
[✓] Connected device
```

### 1-2. 依存パッケージのインストール

```bash
cd /path/to/smap-cam

flutter pub get
```

これだけ。`pubspec.yaml` に書いてある全パッケージが自動でダウンロードされます。

---

## 2. Mapbox トークンの設定（必須）

マップ画面を表示するために必要です。なくてもアプリは起動しますが、マップ画面がクラッシュします。

### 2-1. トークンを取得する

1. [mapbox.com](https://www.mapbox.com) にアクセス
2. アカウント登録（無料）
3. 「Tokens」→「Create a token」→ デフォルト設定のままで作成
4. `pk.eyJ1Ijoi...` で始まるトークンをコピー

### 2-2. iOS に設定する

`ios/Runner/Info.plist` を開いて、`</dict>` の直前に追加：

```xml
<key>MBXAccessToken</key>
<string>pk.eyJ1Ijoiあなたのトークンをここに貼る...</string>
```

### 2-3. Android に設定する

プロジェクトルートに `.mapbox_token` ファイルを作成（このファイルは `.gitignore` に追加済み）：

```bash
echo "pk.eyJ1Ijoiあなたのトークンをここに貼る..." > ~/.mapbox
```

または `android/local.properties` に追記：

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.eyJ1Ijoi...  # ダウンロード用（ビルド時）
```

> **注意:** トークンは絶対に git に push しないこと。
> `.gitignore` に `*.mapbox_token`, `local.properties` が含まれていることを確認してください。

---

## 3. iOS 実機で動かす

### 3-1. iPhone を Mac に接続

1. USB-C または Lightning ケーブルで接続
2. iPhone で「このコンピューターを信頼する」をタップ
3. パスコードを入力

### 3-2. Xcode で署名を設定する

```bash
# Xcodeを開く
open ios/Runner.xcworkspace
```

> `Runner.xcodeproj` ではなく **`Runner.xcworkspace`** を開くこと（CocoaPodsを使っているため）

Xcode が開いたら：

1. 左ペインで「Runner」を選択
2. 「Signing & Capabilities」タブ
3. 「Team」のプルダウンで自分のApple IDを選択
4. 「Bundle Identifier」を変更（例: `com.あなたの名前.zootocam`）
   - そのままだと既存のIDと被ってインストールできないことがある

### 3-3. CocoaPods のインストール

```bash
cd ios
pod install
cd ..
```

初回は数分かかります。

### 3-4. 実機にビルド・インストール

```bash
# 接続デバイス一覧を確認
flutter devices

# 出力例:
# iPhone 15 Pro (mobile) • XXXXXXXX-XXXX... • ios • iOS 17.x

# 実機にビルドして起動
flutter run -d "iPhone 15 Pro"
# または device ID で指定
flutter run -d XXXXXXXX-XXXX
```

初回ビルドは5〜10分かかります。2回目以降は1〜2分。

### 3-5. よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `Untrusted Developer` | 署名が未承認 | iPhone の「設定 → 一般 → VPNとデバイス管理」で自分の開発者証明書を「信頼」 |
| `No provisioning profile` | Xcode署名未設定 | 3-2 の手順を再確認 |
| `pod install failed` | CocoaPods古い | `sudo gem install cocoapods` でアップデート |
| カメラが真っ黒 | 権限未許可 | 「設定 → ZootoCam → カメラ」をONにする |
| マップが白い | Mapboxトークン未設定 | 手順2を確認 |

---

## 4. Android 実機で動かす（Pixel 8 Pro 推奨）

### 4-1. Android の開発者モードを有効にする

1. 「設定 → 端末情報 → ビルド番号」を **7回連続タップ**
2. 「設定 → 開発者向けオプション → USBデバッグ」をON

### 4-2. PC に接続

1. USB ケーブルで接続
2. Android 側で「USBデバッグを許可しますか？」→「許可」

```bash
# 接続確認
flutter devices

# 出力例:
# Pixel 8 Pro (mobile) • XXXXXXXX • android-arm64 • Android 14
```

### 4-3. ビルド・インストール

```bash
flutter run -d XXXXXXXX
```

### 4-4. よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `INSTALL_FAILED_USER_RESTRICTED` | USBデバッグOFF | 4-1を再確認 |
| カメラが縦横逆 | **Exif回転バグ（既知）** | Sprint 5 Jun Kang 対応中。一旦無視でOK |
| `minSdk version` エラー | Android 7以下の端末 | API 24（Android 7）以上の端末が必要 |
| マップが表示されない | Mapboxトークン未設定 | 手順2-3を確認 |

---

## 5. 動作確認チェックリスト

実機に入れたら、以下の順番で確認してください。

### 基本起動

```
□ アプリが起動する（クラッシュしない）
□ マップ画面が表示される（MapScreenがホーム）
□ 下部タブ 3つ（マップ / 図鑑 / 設定）が動く
```

### チェックイン

```
□ マップの FAB「動物園へ」をタップ → チェックイン画面が開く
□ GPS が動く（位置情報の許可ダイアログが出る）
□ 近くの動物園が自動検出される、またはリストから選べる
□ 「野生モード」で動物園なしでもチェックインできる
□ チェックイン後にカメラ画面へ遷移する
```

### カメラ

```
□ カメラが起動する（黒くならない）
□ カメラの許可ダイアログが出る
□ LUT が切り替わる（KODAK / WARM / FUJI / MONO）
□ FREE バッジが KODAK・WARM にだけある
□ LUT強度スライダーで色味が変わる
□ グリッドボタンで格子線が出る・消える
□ ライトリークボタンで端が光漏れする（弱/中/強）
□ シャッターが切れる（音が鳴る）
□ フォーカスタップで枠が表示される
□ フラッシュON/OFFで切り替わる
□ セルフタイマー（3秒/10秒）でカウントダウンが出る
□ フィルムカウンターが減る（カチッとアニメーション）
□ フィルムカウンター残り5枚以下でオレンジになる
```

### フィルム現像フロー

```
□ （テスト用）27枚撮ったら自動で現像画面へ遷移する
  ↑ 枚数が多いので、DBを直接編集してphoto_countを26にしてもOK（後述）
□ 現像画面でLUT適用された写真が見える
□ ジャーナル画面で動物名・メモが入力できる
□ 「完了」で保存 → マップ画面に戻る
```

### 図鑑

```
□ 「出会い済み」タブに記録した動物が表示される
□ 「未発見」タブに残りの種リストが出る
□ ヘッダーに「○ / 32種 (○%)」が表示される
□ 動物カードをタップ → 詳細画面が開く
□ encounters = 0 のとき空状態UIが出てチェックインCTAが表示される
```

### シェア

```
□ ジャーナルの「この写真をシェア」が動く
□ 透かし（@username · ZOOSMAP）が写真に合成される
□ マップ画面のセッションタップ → 「コンタクトシート」書き出しができる
```

### 設定

```
□ ユーザー名を入力すると透かしプレビューに反映される
□ 透かし位置（右下/左下/中央下）を変えると即反映される
□ アプリを再起動しても設定が保存されている
```

---

## 6. テストデータの注入（27枚撮らなくても現像フローを確認する方法）

毎回27枚撮るのは大変なので、SQLite のデータを直接書き換えます。

### 方法A: Flutter DevTools を使う（簡単）

```bash
# アプリ起動中に
flutter pub global activate devtools
flutter pub global run devtools
```

ブラウザが開くので「App Size」→ SQLite DB ファイルを探す。

### 方法B: ADB で Android のDBを取り出す（確実）

```bash
# DBファイルをPCに取り出す
adb exec-out run-as com.example.zootocam cat databases/zootocam.db > /tmp/zootocam.db

# SQLiteで編集
sqlite3 /tmp/zootocam.db
> UPDATE film_sessions SET photo_count = 26 WHERE status = 'shooting';
> .quit

# DBを端末に戻す
adb push /tmp/zootocam.db /data/data/com.example.zootocam/databases/zootocam.db
```

### 方法C: iOS の場合（Xcode の Devices から）

1. Xcode → Window → Devices and Simulators
2. アプリを選択 → 「Download Container」
3. `.xcappdata` を右クリック → 「Show Package Contents」
4. `AppData/Documents/` に SQLite ファイルがある
5. 編集して戻す

---

## 7. シミュレーター・エミュレーターでできること

カメラは動きませんが、以下は確認できます。

```bash
# iOSシミュレーターで起動
flutter run -d "iPhone 16 Pro"  # Xcodeでシミュレーターを起動しておく

# Androidエミュレーターで起動（Android Studioでエミュレーター起動後）
flutter run -d emulator-5554
```

| 機能 | シミュレーター | 実機 |
|------|-------------|------|
| マップ表示 | ○ | ○ |
| 図鑑・設定 | ○ | ○ |
| DBシード・図鑑データ | ○ | ○ |
| カメラプレビュー | ✗ | ○ |
| シャッター・LUT | ✗ | ○ |
| 位置情報（模擬） | △（固定値） | ○ |
| シェア | △（UI確認のみ） | ○ |

---

## 8. ログの確認方法

```bash
# ターミナルにログが流れる（flutter run 実行中）
flutter logs

# フィルタリング（ZootoCam関連のみ）
flutter logs | grep -i "zootocam\|error\|exception"
```

クラッシュした場合はスタックトレースがそのまま出ます。エラーメッセージをそのまま田中 PM か担当エンジニアに共有してください。

---

## 9. ビルドが通らない場合のリセット手順

「なにかおかしい」と思ったらこれを試してください。

```bash
# Flutter キャッシュをクリア
flutter clean

# パッケージ再取得
flutter pub get

# iOS: Pods を再インストール
cd ios && pod install && cd ..

# 再ビルド
flutter run
```

それでもダメな場合は `flutter doctor -v` の出力をそのまま共有してください。

---

## 10. フィードバックの記録方法

動作確認中に気づいたことは以下に書いてください：

```
devlog/TEAM_CHAT.md  ← 気軽な指摘・質問
docs/09_testing_guide.md（本ファイル）← 手順の追記・修正
```

フォーマット：

```
## フィードバック — 2026-XX-XX

**端末:** iPhone 15 Pro / iOS 17.4
**再現手順:**
1. チェックイン → 上野動物園
2. カメラでシャッターを3回切る
3. ...

**期待:** ...
**実際:** ...
```

---

## 付録: よく使うコマンド早見表

```bash
# 環境確認
flutter doctor

# 接続端末一覧
flutter devices

# 実機で起動（デバッグモード）
flutter run

# リリースビルド（最終確認用・重い処理が速い）
flutter run --release

# キャッシュクリア
flutter clean && flutter pub get

# ログ確認
flutter logs

# iOS署名付きビルド（Xcode使わず）
flutter build ios --release

# Android APK 生成（直接インストール用）
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## 11. TestFlight で配布する（iOS）

TestFlight は Apple の公式ベータ配布サービスです。
ビルドをApp Store Connect にアップロードすれば、テスターが **App Storeなし** でインストールできます。

> **担当:** 青山 美樹（QA）が本来の担当ですが、手順を理解しておくと自力で確認できます。

### 11-1. 前提条件の確認

```
□ Apple Developer Program 加入済み（年間 ¥13,800）
□ App Store Connect でアプリが登録済み
  → 未登録の場合は 11-2 から
□ Xcode 15以上
□ Bundle Identifier が確定している（例: com.beerbear.zootocam）
```

### 11-2. App Store Connect にアプリを登録する（初回のみ）

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) にログイン
2. 「マイApp」→「＋」→「新規App」
3. 以下を入力して「作成」：

   | 項目 | 値 |
   |------|-----|
   | プラットフォーム | iOS |
   | 名前 | ZootoCam |
   | プライマリ言語 | 日本語 |
   | Bundle ID | Xcodeで設定したものと一致させる |
   | SKU | zootocam-mvp（任意の一意な文字列） |

### 11-3. Xcode で証明書・プロビジョニングを整える

```bash
open ios/Runner.xcworkspace
```

1. 「Runner」→ 「Signing & Capabilities」
2. 「Automatically manage signing」にチェック
3. Team: **あなたの Apple Developer チーム**を選択
4. Bundle Identifier を App Store Connect と **完全一致** させる

### 11-4. バージョン番号を設定する

`pubspec.yaml` のバージョンを確認・更新：

```yaml
version: 1.0.0+1
#        ↑   ↑
#        |   ビルド番号（毎回インクリメント必須）
#        バージョン番号（表示用）
```

TestFlight は **ビルド番号（`+` 以降）** が前回より大きくないと受け付けません。

```yaml
# 例: 2回目のアップロード
version: 1.0.0+2
```

### 11-5. アーカイブ（ビルドパッケージ作成）

```bash
# release ビルドを生成（完了まで 5〜15 分）
flutter build ipa --release
```

成功すると：
```
build/ios/ipa/zootocam.ipa
```
が生成されます。

> **エラーが出た場合:** `flutter build ios --release` を先に試してXcodeのエラーを確認してください。

### 11-6. App Store Connect にアップロード

**方法A: Xcode から（簡単）**

```bash
open ios/Runner.xcworkspace
```

1. Xcode 上部メニュー「Product」→「Archive」
2. 完了したら自動で「Organizer」ウィンドウが開く
3. 「Distribute App」→「App Store Connect」→「Upload」
4. そのまま進めると自動でアップロードされる

**方法B: xcrun altool コマンドで（CLIで完結）**

```bash
xcrun altool --upload-app \
  -f build/ios/ipa/zootocam.ipa \
  -t ios \
  -u "Apple IDのメールアドレス" \
  -p "アプリ専用パスワード"
  # ↑ appleid.apple.com → 「サインインとセキュリティ」→「App用パスワード」で発行
```

**方法C: Transporter アプリ（Macのみ・GUIで一番簡単）**

1. Mac App Store で「Transporter」をインストール
2. 起動して Apple ID でログイン
3. `.ipa` ファイルをドラッグ&ドロップ
4. 「配信」ボタンを押す

### 11-7. TestFlight でテスターを追加する

アップロード完了後、App Store Connect で：

1. 「TestFlight」タブ → ビルドが処理中（15〜30分かかる）
2. 処理完了後「内部テスト」→「テスター」→「＋」
3. beerbear-a のメールアドレスを追加
4. 招待メールが届く → **TestFlight アプリ** からインストール

```
内部テスト: Apple Developer チームのメンバーまで（最大 100名）
外部テスト: 誰でも招待可（審査が必要。MVP段階では内部でOK）
```

### 11-8. テスターのインストール手順

受け取る側（beerbear-a など）の操作：

1. iPhoneで招待メールを開く
2. 「TestFlightで表示」をタップ
3. TestFlightアプリを持っていなければApp Storeからインストール
4. TestFlight → 「ZootoCam」→「インストール」

以降はアップデートのたびに TestFlight から通知が来て、ワンタップで更新できます。

### 11-9. TestFlight で起きやすい問題

| 問題 | 原因 | 対処 |
|------|------|------|
| 処理完了まで30分以上かかる | Apple側の審査キュー | 待つ。通常15〜30分、稀に1時間 |
| 「このビルドはもう利用できません」 | ビルド番号が重複 | `pubspec.yaml` の `+N` を上げて再ビルド |
| メール届かない | 迷惑フォルダ | 「no_reply@email.apple.com」を確認 |
| カメラ権限がない | Info.plist の記述漏れ | `NSCameraUsageDescription` を確認（設定済み） |
| マップが真っ白 | Mapboxトークン未設定 | 手順2-2 を確認 |
| 「ITMS-90683: Missing Purpose String」 | 権限の説明文漏れ | 青山 美樹に確認（審査ブロッカー） |

### 11-10. ビルド番号管理のTips

アップロードのたびにビルド番号を手動で上げるのは面倒なので、CIで自動化することもできますが、MVP段階は手動で十分です。

```bash
# 現在のビルド番号を確認
grep "^version:" pubspec.yaml

# 例: version: 1.0.0+3 → 次は +4 にして再ビルド
```

---

**作成: 田中 優希 (PM) + beerbear-a**
**最終更新: 2026-03-14**
