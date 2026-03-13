# [010] シルエット実装コードレビュー — 動物学的正確性ヒアリング

**アドバイザー:** 西村 晴子 (Nishimura Haruko)
**対象ファイル:** `lib/features/zukan/widgets/animal_silhouette.dart`
**日付:** 2026-03-14
**ステータス:** 🔴 要修正（3件）/ 🟡 要検討（2件）/ ✅ 承認（大枠）

---

## 総評

Rei さんの実装を `animal_silhouette.dart` で確認しました。

**まず良い点から。**

私が [008] で定義した7分類カテゴリ（`felid / ursid / primate / megaherbivore / smallMammal / avian / reptile`）がそのまま `SilhouetteBase` enum に反映されており、設計の骨格は正確です。32種の config テーブルも、[008] の差分パラメータ対応表とほぼ一致しています。

CustomPainter で描ききるという方針も理に適っている。フィールド識別において「形の本質」を捉えることが重要で、色や模様より**輪郭・シルエット**が先に脳に届く。アセットなしで全種を描く哲学は正しい。

---

ただし、**動物学的に看過できない誤りが3件**あります。今すぐ直してください。

---

## 🔴 修正必須: 3件

### 修正1: レッサーパンダの耳が「尖り耳」になっている

**場所:** `_configs` テーブル、`red_panda` エントリ

```dart
// 現在（誤り）
'red_panda': SilhouetteConfig(
  base: SilhouetteBase.ursid,
  ears: EarType.pointedSmall,  // ← ❌
  ...
),
```

**問題:**
レッサーパンダ（Ailurus fulgens）の耳は**三角形に近いが先端が丸く、ふさふさした毛が生える**。
`pointedSmall` は猫科の耳です。混用すると「ネコ型のシルエット」に見えてしまう。

私が [008] で指定したのは `round`（正確には `small_round` 相当）です。

```dart
// 修正後
'red_panda': SilhouetteConfig(
  base: SilhouetteBase.ursid,
  ears: EarType.smallRound,  // ← ✅ 丸みのある小耳
  tail: TailType.mediumFluffy,
  body: BodyShape.slender,
),
```

**なぜ重要か:** `ursid` の識別に「丸い耳」は必須要素です([008] より「耳の形が最重要」)。レッサーパンダが尖り耳で描かれると、ユーザーは即座に「ネコ科では？」と感じます。

---

### 修正2: オカピの固有パーツが未設定

**場所:** `_configs` テーブル、`okapi` エントリ

```dart
// 現在（不完全）
'okapi': SilhouetteConfig(
  base: SilhouetteBase.megaherbivore,
  ears: EarType.pointedLarge,
  tail: TailType.mediumThin,
  body: BodyShape.horseLike,
  // unique: UniqueFeature.none  ← ❌ 縞模様が描かれない
),
```

**問題:**
オカピ（Okapia johnstoni）の最大の識別特徴は**後肢と臀部の白黒縞**です。
これがないとシマウマと区別がつかない（どちらも `horseLike` + `pointedLarge` ears）。

[008] の差分テーブルでも `short_neck_stripes` を固有パーツとして指定しています。

**対応:**
`UniqueFeature` enum に `legStripes` を追加し、`_drawMegaherbivore` で後肢のみに縞を描く。

```dart
// UniqueFeature enum に追加
legStripes,  // オカピ（後肢・臀部の縞）

// config 修正
'okapi': SilhouetteConfig(
  base: SilhouetteBase.megaherbivore,
  ears: EarType.pointedLarge,
  tail: TailType.mediumThin,
  body: BodyShape.horseLike,
  unique: UniqueFeature.legStripes,  // ← ✅
),
```

---

### 修正3: ミーアキャットの直立判定がロジックに依存している

**場所:** `_drawSmallMammal` メソッド内

```dart
// 現在（脆い）
final isUpright = cfg.body == BodyShape.slender &&
    cfg.ears == EarType.pointedSmall; // ← ❌ ミーアキャット判定
```

**問題:**
「`slender` かつ `pointedSmall`」という組み合わせで直立姿勢を判定しています。
将来、別の細身・尖り耳の動物（例：ジェネット、フォッサ）を追加したとき、
意図せず直立姿勢で描かれてしまいます。

**対応:**
`UniqueFeature` に `upright`（直立姿勢）を追加し、明示的に指定する。

```dart
// UniqueFeature enum に追加
upright,     // ミーアキャット（直立姿勢）

// config 修正
'meerkat': SilhouetteConfig(
  base: SilhouetteBase.smallMammal,
  ears: EarType.pointedSmall,
  tail: TailType.mediumThin,
  body: BodyShape.slender,
  unique: UniqueFeature.upright,  // ← ✅
),

// _drawSmallMammal 内の判定
final isUpright = cfg.unique == UniqueFeature.upright;  // ← ✅ 明示的
```

---

## 🟡 検討推奨: 2件

### 検討1: チーターの「涙模様（tear marks）」が未実装

[008] の差分テーブルで `tear_marks` を記載しました。
現在の config では `cheetah` に `unique: UniqueFeature.none` が設定されており、
他のヒョウ科（ウンピョウ、アムールヒョウ）との区別が耳と尾の形だけになっています。

チーターとアムールヒョウは現状ほぼ同じシルエットです。

**推奨:**
`UniqueFeature.tearMarks` を追加し、目頭から口角にかけて細い線を2本描く。
（Sprint 5 対応でも可。ただし図鑑で並んだとき混乱を招く可能性あり）

---

### 検討2: フラミンゴが「両足立ち」になっている

フラミンゴ（Phoenicopterus roseus）の最も象徴的な姿勢は**片足立ち**です。
現在は左右2本の細い足が対称に描かれています。

動物園の来場者が「フラミンゴだ」と判断する最大の手がかりは、
S字の首 → 次に片足立ちです。

**推奨:**
`_drawAvian` で `isFlamingoType` のとき、片方の脚を非表示（または折り畳んだ形）にする。
（MVPではなく、後続スプリントで対応可。現状でも首のカーブで識別可能）

---

## 変更サマリー（Rei への修正指示）

| 優先度 | 対象 | 変更内容 |
|--------|------|---------|
| 🔴 今すぐ | `red_panda` config | `ears: EarType.smallRound` に修正 |
| 🔴 今すぐ | `UniqueFeature` enum | `legStripes`, `upright` を追加 |
| 🔴 今すぐ | `okapi` config | `unique: UniqueFeature.legStripes` を追加 |
| 🔴 今すぐ | `meerkat` config | `unique: UniqueFeature.upright` を追加 |
| 🔴 今すぐ | `_drawSmallMammal` | 直立判定を `cfg.unique == UniqueFeature.upright` に変更 |
| 🔴 今すぐ | `_drawMegaherbivore` | `legStripes` 時に後肢縞を描く処理を追加 |
| 🟡 Sprint5 | `UniqueFeature.tearMarks` | チーター用、追加検討 |
| 🟡 Sprint5 | フラミンゴ片足立ち | `_drawAvian` の脚描画を修正 |

---

## 承認リスト（変更不要）

以下の実装は動物学的に正確です。変更不要：

- `felid` の低重心・長尾・尖り耳の3要素構成 ✅
- `ursid` の丸耳・ずんぐり体型 ✅（ただしレッサーパンダは上記修正が必要）
- `primate` の腕比率（`longArmed` でオランウータンの長腕を表現）✅
- `elephant` の鼻（quadraticBezierTo による曲線） ✅
- `giraffe` の首（縦長の長方形 + 上部の頭）✅
- `giant_panda` の `eyePatches` ✅
- `pangolin` の `scales`（格子状楕円による鱗）✅
- `komodo` の低重心・長尾 ✅
- `flamingo` のS字首（二重の quadraticBezierTo）✅

---

## 変更ファイル

| ファイル | 変更種別 |
|---------|---------|
| `devlog/010_zoologist_code_review.md` | 新規 |
