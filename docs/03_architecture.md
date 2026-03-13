# ZOOSMAP - アーキテクチャ設計

> バージョン: 1.0
> 最終更新: 2026-03-13

---

## 1. 設計原則

```
1. Offline First
   ネット接続なしで全コア機能が動作する
   動物園の中は電波が弱い場合がある

2. Camera First
   カメラ起動を最優先・2秒以内
   シャッターチャンスを逃さない設計

3. Local Data
   ユーザーデータは端末内完結（MVP）
   プライバシー保護 + サーバーコスト削減
```

---

## 2. 全体アーキテクチャ

```
┌──────────────────────────────────────────────────────┐
│                   Flutter UI Layer                    │
│                                                       │
│  CameraScreen  CheckinScreen  ZukanScreen  MapScreen │
│  EncounterScreen  ExportScreen  SettingsScreen        │
└──────────────────────┬───────────────────────────────┘
                       │ Riverpod (StateNotifier)
┌──────────────────────▼───────────────────────────────┐
│                 Application Layer                     │
│                                                       │
│  CameraNotifier    CheckinNotifier   ZukanNotifier   │
│  EncounterNotifier MapNotifier       ExportNotifier  │
└──────────┬───────────────────────────────────────────┘
           │
┌──────────▼───────────────────────────────────────────┐
│                   Domain Layer                        │
│                                                       │
│  models/      Animal  Zoo  Encounter  UserSettings   │
│  services/    CameraService  LocationService         │
│               WatermarkService  LutService           │
│  database/    DatabaseHelper  AnimalRepository       │
│               ZooRepository   EncounterRepository    │
└──────────┬────────────────────┬──────────────────────┘
           │                    │
┌──────────▼──────────┐ ┌──────▼───────────────────────┐
│  Platform Channel   │ │       Local Storage           │
│  smap.cam/camera    │ │                               │
│                     │ │  SQLite (sqflite)             │
│  iOS: AVFoundation  │ │  ├── animals.db (JAZA)        │
│  Android: CameraX   │ │  ├── zoos.db                  │
└─────────────────────┘ │  ├── encounters.db            │
                        │  └── settings.db              │
                        │                               │
                        │  FileSystem (path_provider)   │
                        │  └── photos/                  │
                        │      ├── originals/           │
                        │      └── processed/           │
                        └──────────────────────────────┘
```

---

## 3. ディレクトリ構造

```
lib/
├── core/
│   ├── models/
│   │   ├── animal.dart          # 種マスター
│   │   ├── zoo.dart             # 動物園マスター
│   │   ├── encounter.dart       # 出会い記録
│   │   └── user_settings.dart   # ユーザー設定
│   │
│   ├── database/
│   │   ├── database_helper.dart
│   │   ├── animal_repository.dart
│   │   ├── zoo_repository.dart
│   │   └── encounter_repository.dart
│   │
│   ├── services/
│   │   ├── camera_service.dart      # Platform Channel
│   │   ├── location_service.dart    # GPS
│   │   ├── lut_service.dart         # LUT管理・適用
│   │   ├── watermark_service.dart   # 透かし生成
│   │   └── purchase_service.dart    # 買い切り管理
│   │
│   └── utils/
│       ├── rarity_calculator.dart   # レアリティ算出
│       └── image_processor.dart     # 画像処理ユーティリティ
│
├── features/
│   ├── camera/
│   │   ├── camera_screen.dart
│   │   ├── camera_notifier.dart
│   │   └── widgets/
│   │       ├── lut_selector.dart
│   │       ├── shutter_button.dart
│   │       └── camera_preview.dart
│   │
│   ├── checkin/
│   │   ├── checkin_screen.dart
│   │   └── checkin_notifier.dart
│   │
│   ├── encounter/
│   │   ├── quick_tag_screen.dart    # 撮影直後の動物タグ付け
│   │   ├── encounter_detail.dart   # 過去の出会い詳細
│   │   └── encounter_notifier.dart
│   │
│   ├── zukan/
│   │   ├── zukan_screen.dart       # 図鑑メイン
│   │   ├── zukan_notifier.dart
│   │   └── widgets/
│   │       ├── animal_card.dart    # 発見済み
│   │       └── silhouette_card.dart # 未発見
│   │
│   ├── map/
│   │   ├── map_screen.dart
│   │   └── map_notifier.dart
│   │
│   ├── export/
│   │   ├── export_screen.dart      # 透かし + シェア
│   │   └── export_notifier.dart
│   │
│   └── settings/
│       ├── settings_screen.dart
│       └── purchase_screen.dart    # 買い切り画面
│
├── shaders/
│   ├── lut_apply.frag              # LUT適用シェーダー
│   └── watermark.frag             # 透かしシェーダー
│
├── assets/
│   ├── luts/                      # LUTファイル (.cube)
│   │   ├── free_natural.cube
│   │   ├── free_warm.cube
│   │   ├── pro_kodak.cube
│   │   ├── pro_fuji.cube
│   │   ├── pro_bw.cube
│   │   └── ...
│   └── db/
│       └── jaza_animals.db        # 初期動物DB（バンドル）
│
└── main.dart

ios/Runner/
├── CameraPlugin.swift
└── AppDelegate.swift

android/app/src/main/kotlin/com/example/zoosmap/
├── CameraPlugin.kt
└── MainActivity.kt
```

---

## 4. Platform Channel 設計

### Channel名: `zoosmap/camera`

| メソッド | 方向 | 引数 | 戻り値 |
|---------|------|------|--------|
| `initializeCamera` | Flutter→Native | - | `{textureId: int}` |
| `takePicture` | Flutter→Native | `{savePath: String}` | `String` (保存パス) |
| `applyLut` | Flutter→Native | `{imagePath, lutPath}` | `String` (加工後パス) |
| `setFlash` | Flutter→Native | `{enabled: bool}` | `void` |
| `stopCamera` | Flutter→Native | - | `void` |

### LUT適用フロー
```
撮影（元画像保存）
        ↓
Flutter側でLUT選択状態を保持
        ↓
Export時に applyLut() を呼び出し
        ↓
Native側でMetalShader(iOS) / RenderScript(Android) 適用
        ↓
加工版を別パスに保存
```

---

## 5. 状態管理設計（Riverpod）

```dart
// アクティブなチェックイン
final activeCheckinProvider = StateNotifierProvider<CheckinNotifier, Zoo?>

// カメラ状態
final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>
// CameraState: { isReady, textureId, selectedLut, isCapturing, flashEnabled }

// 図鑑状態
final zukanProvider = StateNotifierProvider<ZukanNotifier, ZukanState>
// ZukanState: { animals, filter(zoo/all), discovered/total }

// 出会い記録
final encounterProvider = StateNotifierProvider<EncounterNotifier, List<Encounter>>

// 購入状態
final purchaseProvider = StateNotifierProvider<PurchaseNotifier, PurchaseState>
// PurchaseState: { isPro, availableLuts }

// マップ
final mapProvider = FutureProvider<List<ZooWithEncounters>>
```

---

## 6. オフライン設計

```
起動時の初期化フロー

App起動
  ↓
assets/db/jaza_animals.db を SQLite にコピー（初回のみ）
  ↓
ユーザーデータDB初期化
  ↓
MapScreen 表示

ネットワーク接続は不要
```

### DBバンドル戦略
```
jaza_animals.db（5,756種）をアプリに同梱
└── アプリサイズへの影響: 約2〜5MB（許容範囲）

DBアップデート方法（将来）
└── アプリアップデート時に差分パッチを適用
    または Firebase Remote Config で管理
```

---

## 7. 画像管理設計

```
撮影 → {Documents}/zoosmap/photos/{date}/
              ├── original/
              │   └── {uuid}.jpg     ← 元画像（常に保存）
              └── processed/
                  └── {uuid}_lut.jpg ← LUT適用済み（Export時生成）

透かし適用
└── Export時にメモリ上で合成
    → 端末のカメラロールに保存 or シェア
    → processed/ には残さない（都度生成）
```

---

## 8. 将来拡張（エコシステム）

```
Core Package（共通エンジン）
├── CameraService（Platform Channel）
├── LutService（LUT適用）
├── WatermarkService（透かし）
├── LocationService（GPS）
└── PurchaseService（買い切り管理）

        ↓ パッケージとして切り出す

ZOOSMAP   → 動物特化DB + UI
FestivalCAM → フェス特化DB + UI
TravelCAM → 旅行特化DB + UI
```
