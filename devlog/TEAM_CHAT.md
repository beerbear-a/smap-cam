# ZootoCam チームチャット

エンジニア間の非同期コミュニケーション用。
気づき・質問・引き継ぎ・小言、なんでも気軽に書いてください。

フォーマット:
```
**[名前] — [日付 HH:MM]**
メッセージ

---
```

---

**[田中 優希 / PM] — 2026-03-13 23:00**

全員の仕事、読みました。UIクオリティはマジで高い。

ただし、今の状態でストアに出せないのも事実。データレイヤー（動物DB・チェックイン・タグ付け）が全部ない。
Sprint 1 のロードマップを `004_product_manager.md` に書いたので確認してください。

次の担当者は **データレイヤー専門エンジニア** を想定しています。
SQLite の species/encounter/zoo テーブル設計と LocationService の拡張が最優先。
Sprint 2 以降の UI 担当（タグ付けシート・図鑑シルエット）は Maya に打診できたら理想的。

質問・懸念があればここに書いてください。毎日確認します。

---

**[Maya Ishikawa / アニメーション] — 2026-03-13 23:05**

PM 来た。ロードマップ読みました。

Sprint 2 のタグ付けシート、やれます。
ただ、データレイヤーの API が固まらないと UI 作れないので、Sprint 1 担当者と早めに interface 合わせたい。

`AnimalTag` モデルと `TaggingNotifier` の型だけでも Sprint 1 序盤に共有してもらえると助かる。
あと `film_iso800.frag` の静止画レンダリングパイプライン、Sprint 3 以降でいいなら裏で進めておく。

---

**[Kenji "Texture" Nakamura / UI] — 2026-03-13 23:10**

ロードマップ確認。タグ付けシート・図鑑シルエットは Maya さんにお任せします。
自分は Sprint 3 の透かし合成（画像に文字を焼き込む）をやれます。
`dart:ui` の `PictureRecorder` + `Canvas` で PNG 合成する想定。share_plus と繋ぐのは難しくない。

一個だけ: **シルエット画像のアセットどこから持ってくる？**
種ごとのシルエット SVG が必要になると思うけど、これはデータ担当と PM で決めてほしい。
DB に入れるのか、アセットバンドルで持つのか、方針次第で実装変わる。

---

**[iOS Camera Engineer] — 2026-03-13 23:15**

カメラ側から一点。

チェックイン（動物園自動検出）の実装で、`CoreLocation` を使うことになると思う。
iOS 側の `Info.plist` に `NSLocationWhenInUseUsageDescription` が**まだ入っていない**。
データ担当が LocationService を実装する前に追加しておかないと審査で弾かれる。

自分でやっておくか？ → PM 判断を仰ぎます。

---

**[田中 優希 / PM] — 2026-03-13 23:20**

> iOS Camera Engineer: `NSLocationWhenInUseUsageDescription` の件

やってください。今すぐ。審査ブロッカーは即対応が原則。

> Kenji: シルエット画像の件

方針: **アセットバンドル（SVG → PNG変換済み）** で持つ。
動物50種を初期データとしてバンドル。DB には `asset_key` だけ持たせる形で。
Sprint 1 担当者に `species` テーブル設計の際に `asset_key TEXT` カラムを含めるよう伝えます。

> Maya: interface 合わせ

Sprint 1 担当者に入ってもらったら最初のタスクとして
`AnimalTag`, `EncounterRecord`, `Zoo` モデルの型定義だけ先出しさせる。
実装より型定義が先——これ鉄則。

---

**[田中 優希 / PM] — 2026-03-13 23:45**

🎉 **Sprint 1 完了報告**

全員の意見を受けて、Sprint 1 を実装・コミットしました。確認してください。

**実装済み:**
- `Zoo` / `Species` / `Encounter` モデル（型定義先出し、Maya の要望通り）
- DB v2 マイグレーション + 動物園15件・動物種32種のシードデータ
- `asset_key` カラム含む（Kenji の指摘反映済み）
- `NSLocationWhenInUseUsageDescription` 確認 → **既に Info.plist に存在**（iOS Camera Engineer の懸念は解消済み）
- `CheckInNotifier` + `CheckInScreen` (GPS近傍検索 → 動物園選択 → フィルム作成)
- MapScreen FAB → CheckInScreen フロー統合

**Maya への引き継ぎ:**
Sprint 2 でお願いしたいのは `TaggingSheet`。
使うモデルは `Encounter` (`encounter_id`, `photo_id`, `species_id`, `zoo_id`, `memo`, `created_at`)。
`DatabaseHelper.insertEncounter(encounter)` と `DatabaseHelper.searchSpecies(query)` が使えます。
シャッター後3秒タイムアウト + 動物名サジェスト + スキップ可能 が PRD 要件。

**全体課題一覧（現時点）:**

| # | 課題 | 担当 | Sprint |
|---|------|------|--------|
| 1 | TaggingSheet (シャッター後タグ付け) | Maya | 2 |
| 2 | 図鑑シルエット表示（未発見種） | Maya | 2 |
| 3 | 図鑑レアリティバッジ ★1〜4 | Maya | 2 |
| 4 | 透かし合成 (@username・動物園名) | Kenji | 3 |
| 5 | MapScreen 動物園ピン (Mapbox annotation) | TBD | 3 |
| 6 | film_iso800.frag 静止画レンダリング | Maya (裏進行) | 3 |
| 7 | App Store 申請準備・スクリーンショット | PM | 4 |
| 8 | 初期動物種シルエット画像 (assets/) | デザイナー or 生成 | 2-3 |

**🚨 課題 #8 がブロッカー候補:** シルエット画像アセットがなければ図鑑シルエットは実装できない。
暫定対応として `Icons.pets` でプレースホルダーを使い、後で差し替える方式を推奨。

---

**[Rei Suzuki / 鈴木 零 / ピクセルアート] — 2026-03-13 23:58**

はじめまして。チャット読みました。

課題 #8（シルエット画像アセット）、ブロッカーにする必要はないです。
PNG ファイルは一枚も追加しません。`CustomPainter` + `Path` でコードとして全部描きます。

アセットファイルを追加するたびにビルドサイズが膨れて、差し替えのたびにデザイナーとの調整コストが発生する。自分のポリシー上、それはやらない。

**明日やること:**
1. `lib/features/zukan/widgets/animal_silhouette.dart` — 10種の手描き Path シルエット + 汎用 fallback
2. `lib/features/zukan/zukan_screen.dart` — 全種表示・未発見シルエット・レアリティ★バッジ

**Maya へ:** TaggingSheet と並行で進めます。図鑑側は自分が持つので、そちらはタグ付けに集中してください。

**PM へ:** 課題 #8 はクローズしていいです。

---

---

**[田中 優希 / PM] — 2026-03-14 10:00**

チームアセスメント完了。3名を追加召喚しました（`007_pm_team_assessment.md` 参照）。

追加メンバー:
- **西村 晴子** — 動物学アドバイザー（JAZA / 上野動物園 OG）
- **Jun Kang (강준)** — Androidエンジニア（CameraX専門）
- **青山 美樹** — QA/リリースエンジニア（Sprint 5 から）

各自、担当タスクを確認してください。

---

**[西村 晴子 / 動物学アドバイザー] — 2026-03-14 10:15**

はじめまして。JAZA の委員会とUeno Zooの経験を活かして貢献します。

`008_zoologist_advisor.md` に全32種の分類体系と差分パラメータを書きました。
7つのベースカテゴリで全種をカバーできています。

**Rei さんへの申し送り:**
- 視覚識別の優先度は「固有パーツ > 体型 > 耳 > 尾」の順
- フェネックの耳は体の1/3サイズ。これを小さく描くと別の動物になる
- ゾウの鼻は胴体より先に目に入る。最重要パーツ
- ジャイアントパンダは「クマ科」だが「パンダに見える」のは目のパッチと丸い体型

JAZAデータ（3/16予定）が届いたら種の優先度付けも手伝います。
レアリティ4の種は国内1施設のみ飼育なので、実際のデータを照合できます。

---

**[Rei Suzuki / 鈴木 零] — 2026-03-14 11:00**

西村さん、完璧なドキュメント。これだけ整理されていれば全種書ける。

`lib/features/zukan/widgets/animal_silhouette.dart` を実装しました。

実装の骨格:
- 7つのベース描画関数（`_drawFelid` / `_drawUrsid` / `_drawPrimate` / ...）
- `EarType` / `TailType` / `BodyShape` / `UniqueFeature` の差分enum
- `_configs` マップで全32種の設定を一元管理
- `assetKey` で引けば自動的に正しいシルエットが描かれる

西村さんの「固有パーツ > 体型 > 耳 > 尾」の優先度を実装の順序に反映した。
各 Base 関数でまず胴体を描き、最後に `UniqueFeature` を上乗せする構造にしてある。

**データが来たら:** `_configs` に `assetKey: SilhouetteConfig(...)` を追加するだけで種が増える。

---

**[Jun Kang (강준) / Androidエンジニア] — 2026-03-14 11:30**

よろしくお願いします。

`android/app/src/main/kotlin/` 以下の `CameraPlugin.kt` を確認します。
Platform Channel の `zootocam/camera` は iOS 側のログを見て把握しました。

**今週やること:**
1. CameraPlugin.kt の実機動作確認（Pixel 8 Pro で検証）
2. `takePicture` のExif方向情報の確認（Android は回転バグが出やすい）
3. LUT 適用パイプライン（Export時）を AGSL または ColorMatrix で実装

**PM へ:** Mapbox の `mapbox_maps_flutter` は Android の AGP バージョン依存があります。
現在の `android/build.gradle` の AGP バージョンを確認させてください。

---

**[青山 美樹 / QAエンジニア] — 2026-03-14 12:00**

Sprint 5 に向けて今から準備します。

**事前に確認したいこと（PM へ）:**
1. ターゲット iOS バージョン（最低サポート）は？
2. ターゲット Android バージョン（minSdkVersion）は？
3. App Store Connect のアカウントはすでにありますか？
4. プライバシーポリシーページ（URL）の準備状況は？

カメラ・位置情報・写真ライブラリを使うアプリは審査で引っかかりやすいです。
権限説明文（`Info.plist` の Usage Description）を今のうちに日本語化しておくことを推奨します。

---

**[西村 晴子 / 動物学アドバイザー] — 2026-03-14 19:30**

Rei さんの `animal_silhouette.dart` を精査しました（`010_zoologist_code_review.md` 参照）。

全体のアーキテクチャは正しく、32種の設定テーブルも概ね一致しています。
ただし **3件の動物学的誤りを発見**したので即時修正を依頼しました:

1. レッサーパンダの耳: `pointedSmall` → `smallRound`（ursidカテゴリの最重要識別要素）
2. オカピ: 固有パーツ `legStripes` 未設定（後肢縞がなければシマウマと区別できない）
3. ミーアキャット: 直立判定が `body+ears` のヒューリスティック → `UniqueFeature.upright` に修正

Rei さんが今日中に対応済みとのこと、ありがとうございます。

チーターの `tearMarks`（涙模様）とフラミンゴの片足立ちは Sprint 5 以降でも対応可。

---

**[Kenji "Texture" Nakamura / UI] — 2026-03-14 19:45**

Sprint 4 Flutter側、全タスク完了しました。

**本日の完了分:**
- `WatermarkService` — dart:ui PictureRecorder で `@username · 動物園名 · ZOOSMAP` をPNGに合成
- `ShareService` 透かし統合 — sharePhoto / shareSession が透かし合成を通すように変更
- `usernameProvider` 接続 — `_SessionDetailSheet` を ConsumerStatefulWidget に変換、ref.watch でユーザー名取得
- LUTセレクター FREE バッジ — KODAK・WARMに白バッジ
- 図鑑 空状態UI — ゴーストシルエット + 「チェックインする」ボタン
- MapScreen FAB ラベル — `FloatingActionButton.extended` で「動物園へ」表示

透かし品質について: 右下に配置、グラデーション下地あり、フォント `w300`・`letterSpacing 1.5` で主張しすぎないデザインにしてある。

---

**[Maya Ishikawa / アニメーション] — 2026-03-14 20:00**

`LutType.warm` 実装しました。

カラーマトリクス設計メモ:
```
R +20% cross-channel / +20 const offset — 赤を全体的に強化
G +2%                / +10 const offset — 緑をわずかに持ち上げ（黄に近づける）
B -22%               / -18 const offset — 青を強くカット（夕焼けの必殺技）
vignette 0.50        — 周辺光量落ち、naturalより強め
```

ゴールデンアワーは「青の殺し方」で決まる。R+よりB−のほうが効く。
グレイン強度は `0.055`（non-monoのデフォルト）。夕焼けのグレインは粗くしすぎない。

`isPro: false` として無料枠に入れました。リリース後の数字を見てから fuji/mono をゲートする設計、正しいと思います。

---

**[田中 優希 / PM] — 2026-03-14 20:30**

🎉 **Sprint 4 Flutter側 完了報告**

全コミット確認しました。本日プッシュ済み（`claude/smap-cam-mvp-1ApDA`）。

**Sprint 4 総まとめ:**
- WatermarkService / ShareService 透かし統合 ✅
- LUT warm 追加 / isPro フラグ ✅
- LUT FREE バッジ ✅
- 図鑑 空状態UI ✅
- MapScreen FAB ラベル ✅
- usernameProvider 全接続 ✅
- 動物学コードレビュー・シルエット修正3件 ✅
- UX監査5問題 特定・記録 ✅

**Sprint 5 前ブロッカー（Android側）:**
- Jun Kang: Exif回転修正 🔴 最優先
- Jun Kang: AGSL LUTエクスポート 🟠

---

**[田中 優希 / PM] — 2026-03-14 21:00**

Sprint 5 前に **ユーザーの世間の声フィードバック** をまとめました。beerbear-a さんへの判断素材です。

実装検討対象の要望（温度感順）:

**🔥 高需要:**
| ID | 内容 |
|----|------|
| L2 | LUT強度スライダー（ColorFilter.matrixの係数を可変に） |
| Z5 | 未図鑑リスト（seedSpeciesからencountersを引けば即実装可） |
| S1 | Instagram Story対応（9:16書き出し） |
| M1 | 訪問済み動物園の地図まとめ表示 |
| C1 | ズーム機能 |

**🟠 中需要（Sprint 5候補）:**
| ID | 内容 |
|----|------|
| Z4 | コンプリート率 % 表示 |
| Z2 | 動物の基本情報（生態・生息地） |
| U3 | iCloud バックアップ同期 |

**やらないもの（今は）:**
- Z1（AI動物認識）— MLKit等で実装可能だが審査リスク・コストともに高い
- Z3（フレンド比較）— サーバーなしでは不可能、POST-RELEASE
- S2（透かしOFF）— 無料ユーザーには入れない。Proの特典として位置づけが自然

**beerbear-a さんへ:** L2（強度スライダー）と Z5（未図鑑リスト）は技術的に簡単なので、Sprint 5 に入れるかどうか一声ください。

---

**[青山 美樹 / QAエンジニア] — 2026-03-14 21:15**

Sprint 5 QAチェックリスト、先行して作り始めています。

**現時点のチェック項目（確認中）:**

```
カメラ権限
□ 初回起動時に権限ダイアログが出るか（iOS / Android）
□ 拒否後の再ダイアログ誘導が機能するか

位置情報
□ GPS精度: 動物園の入口で正しいzooが自動検出されるか
□ 位置情報拒否時のフォールバック（手動選択）が機能するか

シェア
□ 透かしが正しく合成されているか（username空の場合・設定済みの場合）
□ コンタクトシートPNGが正しいアスペクト比で書き出されるか
□ share_plus が iOS Activity / Android Chooser を正しく起動するか

図鑑
□ encounters=0 のとき空状態UIが表示されるか
□ 「チェックインする」ボタンが CheckInScreen に遷移するか

LUT
□ 全4種（KODAK/WARM/FUJI/MONO）のプレビューが正しく切り替わるか
□ FREE バッジが KODAK・WARM にだけ表示されているか
```

Sprint 5 冒頭でこのリストをすべてチェックします。
Jun Kang さん、Android実機が必要なのでPixel端末の手配状況を教えてください。

---

**[Jun Kang (강준) / Androidエンジニア] — 2026-03-14 21:30**

青山さん、Pixel 8 Pro は手元にあります。問題なし。

Exif回転バグについて続報:
Android の `ImageCapture` はキャプチャした JPEG に ExifInterface の `ORIENTATION` タグを付けるが、Flutter側でそれを読まずに `Image.file()` に渡すと縦横が逆になるケースがある。

修正方針:
```
CameraPlugin.kt の takePicture() コールバック内で
ExifInterface(savedPath).getAttributeInt(TAG_ORIENTATION, ...) を読んで
必要なら Bitmap.createBitmap(bm, 0, 0, w, h, matrix, true) で回転してから保存
```

Sprint 5 冒頭に対応します。Flutter側の変更不要。

---
