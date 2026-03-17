# デバッグ/動作確認ガイド

このドキュメントは「後で自分で試す」ための最短手順です。

---

## 事前準備

- Flutter SDK: `./flutter/bin/flutter`
- CocoaPods: `pod --version` が通ること

---

## iOS ビルド & 起動（シミュレーター）

```bash
./flutter/bin/flutter pub get
./flutter/bin/flutter build ios --no-codesign
./flutter/bin/flutter run -d "iPhone 16 Pro"
```

---

## デバッグ設定の場所

設定 → **デバッグ**

- デバッグモード（ON/OFF）
- 動物園機能（ON/OFF）
- フィルムシェーダー（切替）

---

## 期待動作

### 1) フィルム表示（旧LUT表記の修正）
- カメラ UI の操作パネルに **FILM** と表示される
- 「LUT」という文言は表示されない

### 2) シェーダー切替（デバッグ）
設定 → デバッグ → フィルムシェーダー
- `AUTO`: フィルム種別ごとのデフォルト
- `LEGACY ISO800 / WARM / FUJI400 / MONO HP5`: legacy シェーダーを上書き

反映箇所:
- 撮影後のフィルム焼き込み
- シミュレーターのプレビュー（静止画）

### 3) 動物園機能 ON/OFF
設定 → デバッグ → 動物園機能

OFF 時:
- カメラの「ロールをつくる」導線が無効化される（スナックバー表示）
- アルバム/図鑑の「ロールをつくる」導線も無効化される
- マップタブは表示されない

ON 時:
- チェックイン/ロール作成が有効
- マップタブは **Mapbox を有効化した場合のみ** 表示

---

## 既知の注意点

- Mapbox は現在デフォルトで無効化
  - `ios/Runner/Info.plist` の `SMAPDisableMapboxPlugin = true`
- Mapbox を試したい場合は上記を `false` に戻す

