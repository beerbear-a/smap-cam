# ZOOSMAP - 技術仕様書

> バージョン: 1.0
> 最終更新: 2026-03-13

---

## 1. 技術スタック

```
Framework:   Flutter (latest stable)
言語:        Dart / Swift / Kotlin
状態管理:    flutter_riverpod ^2.5
DB:          sqflite ^2.3
地図:        mapbox_maps_flutter ^2.3
位置情報:    geolocator ^12.0
シェア:      share_plus ^9.0
課金:        in_app_purchase ^3.1（StoreKit2 / Play Billing 5）
画像処理:    Flutter FragmentProgram（GLSL）
```

---

## 2. カメラ実装

### iOS（AVFoundation + Metal）

```swift
// 撮影フロー
AVCaptureSession
  └── AVCaptureDeviceInput（背面カメラ）
  └── AVCapturePhotoOutput（静止画）
  └── AVCaptureVideoDataOutput（Texture preview）
        └── CVPixelBuffer → FlutterTexture

// LUT適用（Metal Shader）
func applyLut(imagePath: String, lutPath: String) -> String {
    // CIFilter(name: "CIColorCube") で .cube ファイル適用
    // CIContext で JPEG 出力
}
```

### Android（CameraX + RenderScript）

```kotlin
// 撮影フロー
ProcessCameraProvider
  └── Preview（SurfaceTexture → FlutterTexture）
  └── ImageCapture（JPEG保存）

// LUT適用
fun applyLut(imagePath: String, lutPath: String): String {
    // BitmapShader or ColorMatrix で LUT 適用
    // 出力を JPEG 保存
}
```

---

## 3. LUTシステム

### .cube ファイル形式
```
LUT_3D_SIZE 64  ← 64×64×64 = 262,144エントリー
# ZOOSMAP Natural LUT

0.000000 0.000000 0.000000
0.012000 0.010000 0.008000
...
```

### LUT一覧

| ID | 名前 | 雰囲気 | 価格 |
|----|------|--------|------|
| `natural` | Natural | 自然でクリア | 無料 |
| `warm` | Warm | 暖色・夕方 | 無料 |
| `kodak` | Kodak Gold | フィルム・暖色 | Pro |
| `fuji` | Fuji Superia | フィルム・冷色 | Pro |
| `bw` | Black & White | 白黒・コントラスト高 | Pro |
| `cinematic` | Cinematic | 映画的・ティール&オレンジ | Pro |
| `vintage` | Vintage | 褪せた感じ | Pro |

### 適用パイプライン
```
カメラプレビュー時（リアルタイム）
└── GLSL シェーダーで GPU 処理（60fps維持）

Export時（高品質）
└── iOS: Core Image CIColorCube
    Android: ColorMatrix / LUT3D
└── 元画像は非破壊（originals/ に保持）
```

---

## 4. 透かし仕様

### デザイン定義（デフォルト）
```
位置:     右下 (padding 16px)
フォント: SF Pro / Roboto 11pt
色:       白 70% 不透明
内容:     @{username} · {zoo_name}
          ZOOSMAP ロゴ (24px)
```

### Proカスタマイズ項目
```
├── 位置: 左下 / 右下 / 左上 / 右上
├── フォントサイズ: 9 / 11 / 13pt
├── 不透明度: 30% 〜 100%（スライダー）
├── 動物名を含める: ON/OFF
└── ロゴ表示: ON/OFF
```

### 生成処理
```dart
// Flutter Canvas API で合成（サーバー不要）
Future<Uint8List> applyWatermark({
  required Uint8List imageData,
  required WatermarkConfig config,
}) async {
  final image = await decodeImageFromList(imageData);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // 元画像を描画
  canvas.drawImage(image, Offset.zero, Paint());

  // 透かしテキストを描画
  final textPainter = TextPainter(...)
  textPainter.paint(canvas, position);

  // PNGとして出力
  final picture = recorder.endRecording();
  final result = await picture.toImage(image.width, image.height);
  return (await result.toByteData(format: ImageByteFormat.png))!
      .buffer.asUint8List();
}
```

---

## 5. 買い切り実装

### パッケージ
```yaml
in_app_purchase: ^3.1.0
```

### Product ID
```
iOS:     com.zoosmap.app.pro
Android: zoosmap_pro
```

### 実装フロー
```dart
class PurchaseNotifier extends StateNotifier<PurchaseState> {

  Future<void> buyPro() async {
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails({'zoosmap_pro'});

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        // SQLite user_settings に is_pro = '1' を保存
        _savePro();
      }
    }
  }
}
```

---

## 6. 地図実装（Mapbox）

### 表示要件
```
ホーム（マップ）
├── 訪問済み動物園: カスタムピン（ZOOSMAP色）
├── 未訪問動物園: グレーピン（チェックイン中の動物園周辺のみ）
├── 野生動物の出会い: 別アイコン
└── クラスタリング: ピンが近い場合は数字でまとめる
```

### Mapboxトークン管理
```dart
// lib/core/config/app_config.dart
class AppConfig {
  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );
}

// ビルド時に注入
// flutter build ios --dart-define=MAPBOX_TOKEN=pk.xxx
```

---

## 7. DBインポート処理（初回起動）

```dart
// lib/core/database/db_initializer.dart
class DbInitializer {
  static Future<void> initialize() async {
    final db = await DatabaseHelper.database;

    // animals テーブルが空なら assets から初期データをコピー
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM animals'),
    );

    if (count == 0) {
      await _importFromAssets(db);
    }
  }

  static Future<void> _importFromAssets(Database db) async {
    // assets/db/jaza_animals.db を読み込んでコピー
    final ByteData data = await rootBundle.load('assets/db/jaza_animals.db');
    // ... バルクインポート
  }
}
```

---

## 8. パーミッション

### iOS（Info.plist）
```xml
<key>NSCameraUsageDescription</key>
<string>動物の写真を撮影するために必要です</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>近くの動物園を自動検出するために必要です</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>カメラロールから写真を読み込むために必要です</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>撮影した写真を保存するために必要です</string>
```

### Android（AndroidManifest.xml）
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

---

## 9. パフォーマンス目標

| 指標 | 目標値 |
|------|--------|
| カメラ起動 | 2秒以内 |
| LUT切替（プレビュー） | 16ms以内（60fps） |
| 写真保存 | 3秒以内 |
| 図鑑表示 | 1秒以内（SQLiteクエリ） |
| アプリ起動 | 3秒以内 |
| アプリサイズ | iOS 50MB以下 / Android 40MB以下 |
