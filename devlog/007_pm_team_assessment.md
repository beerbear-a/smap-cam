# [007] チームアセスメント & 追加メンバー選定

**PM:** 田中 優希 (Yuki Tanaka)
**日付:** 2026-03-13
**ステータス:** 🔥 完了（メンバー確定）

---

## 現チームのギャップ分析

Sprint 4 に入る前に、現在の体制を冷静に評価する。

```
現在の体制
├── iOS Camera Engineer  → iOS/AVFoundation は完璧
├── Kenji               → Flutter UI/HIG は完璧
├── Maya                → シェーダー/アニメーションは完璧
├── Rei                 → Canvas/図鑑は完璧
└── PM（自分）          → 方向管理

ギャップ
├── ❌ Android専任がいない
│   CameraXの実機検証・LUT適用パイプライン担当が空白
│   iOSエンジニアに兼任は酷。別途専任が必要。
│
├── ❌ 動物学的知見がない
│   Reiがシルエットを「分類から差分で作る」方針を出した。
│   正しい方針だが、正確な分類体系と視覚的特徴の整理は
│   専門家でないとできない。ドメイン知識の空白は致命的。
│
└── ❌ QA/リリース専任がいない
    Sprint 5のTestFlight・App Store申請・スクリーンショット生成
    を誰も担当していない。リリース直前で詰まる典型パターン。
```

---

## 新規召喚メンバー（3名）

### 1. 西村 晴子 (Nishimura Haruko) — 動物学アドバイザー

```
背景:
├── 東京大学農学部 獣医学科 → 動物行動学 PhD
├── 上野動物園 飼育展示課 12年
├── JAZA 生物多様性委員会 委員（現職）
└── 趣味: フィールドワーク、ライフリスト管理

専門:
├── 哺乳類・鳥類の分類体系（目・科・属レベル）
├── 国内飼育施設の生息種データ
├── 動物の視覚的識別特徴（フィールド識別手法）
└── JAZA種別データの構造熟知

役割:
└── Rei のシルエットシステム設計に分類学的正確性を与える
    seed_data.dart の species 情報を監修する
    レアリティ算出ロジックの妥当性検証
```

### 2. Jun Kang (강준) — Androidエンジニア

```
背景:
├── Samsung → Google Android チーム 5年
├── 現在フリーランス（東京拠点）
├── CameraX のコントリビューター経験あり
└── Kotlin/Coroutines を自然言語のように書く

専門:
├── CameraX (Preview / ImageCapture / VideoCapture)
├── Play Billing Library 5
├── RenderScript → AGSL（Android GPU Shader Language）移行
└── Flutter Platform Channel の Android 実装

役割:
└── CameraPlugin.kt の完成・実機検証
    Android LUT 適用パイプライン（Export 時）
    将来の Play Billing 実装（POST-RELEASE）
```

### 3. Miki Aoyama (青山 美樹) — QA / リリースエンジニア

```
背景:
├── サイバーエージェント QA 7年
├── App Store / Play Store 審査通過 100+ 本
├── TestFlight 運用・スクリーンショット自動生成の専門家
└── 審査リジェクト理由のパターン認識が特技

専門:
├── iOS / Android 実機テスト設計
├── fastlane を使った自動化（スクリーンショット・デプロイ）
├── App Store Connect / Google Play Console 操作
└── プライバシーポリシー・権限説明文の審査対策

役割:
└── Sprint 5 の QA リード
    App Store / Play Store 申請書類一式
    TestFlight ベータ配信の運用
```

---

## 更新後のチームロスター

| 名前 | ロール | 専門 | Sprint投入タイミング |
|------|--------|------|---------------------|
| beerbear-a | PO | 方針・データ | 常時 |
| 田中 優希 | PM | 全体管理 | 常時 |
| iOS Camera Engineer | iOSエンジニア | AVFoundation / Swift | Sprint 1〜 |
| Kenji "Texture" Nakamura | Flutter UIエンジニア | HIG / アニメーション | Sprint 1〜 |
| Maya Ishikawa | シェーダー | GLSL / フィルム光学 | Sprint 1〜 |
| Rei Suzuki | Canvas | CustomPainter / 図鑑 | Sprint 2〜 |
| **西村 晴子** | **動物学アドバイザー** | **動物分類 / JAZA** | **Sprint 4〜** |
| **Jun Kang** | **Androidエンジニア** | **CameraX / Kotlin** | **Sprint 4〜** |
| **青山 美樹** | **QAエンジニア** | **TestFlight / 審査** | **Sprint 5〜** |

---

## 変更ファイル

| ファイル | 変更種別 |
|---------|---------|
| `devlog/007_pm_team_assessment.md` | 新規 |
| `devlog/TEAM_CHAT.md` | 更新（別途） |
| `CLAUDE.md` | 更新（別途） |
