# [008] 動物分類体系 & シルエット設計ガイド

**アドバイザー:** 西村 晴子 (Nishimura Haruko)
**所属:** JAZA 生物多様性委員会 / 元上野動物園飼育展示課
**担当領域:** 動物分類学 / 視覚識別特徴 / シルエット設計監修
**日付:** 2026-03-14
**ステータス:** ✅ 完了

---

## はじめに

Rei さんの「分類から差分を作る」というアプローチは正しい直感です。
動物のフィールド識別では、まず「何科か」を判断し、次に「どの種か」へ絞り込む。
シルエットシステムも同じ階層で設計すべきです。

ただし、**視覚的なグルーピングは分類学的な階層と必ずしも一致しない**点に注意が必要です。
たとえばジャイアントパンダはクマ科ですが、シルエットとしては「丸い体型・白黒模様」が先に目に入る。
今回は「動物園の来訪者が直感的に識別できる視覚特徴」を優先します。

---

## 視覚ベース分類（7カテゴリ）

### Base 1: `felid` — 大型猫科型

```
対象種（seed_data より）:
ライオン / トラ / ユキヒョウ / チーター / ウンピョウ / アムールヒョウ

視覚的特徴:
├── 4足歩行・低い重心
├── 流線型の胴体
├── 長く曲がった尾
├── 小さく尖った耳（種により形状差あり）
└── 前足が後足より太い（肩の筋肉）

差分パラメータ:
├── 耳: pointed_small（ライオン・トラ）/ tufted（ユキヒョウ）
├── 尾: long_curved（全般）/ very_long_fluffy（ユキヒョウ）
├── 体型: muscular（ライオン・トラ）/ slender（チーター）
└── たてがみ: mane_male（ライオン♂）
```

### Base 2: `ursid` — クマ・パンダ型

```
対象種:
ホッキョクグマ / マレーグマ / ジャイアントパンダ / レッサーパンダ*

*レッサーパンダは分類上イタチ上科だが視覚的にはクマ型に近い

視覚的特徴:
├── 4足歩行・ずんぐりした体型
├── 短い尾
├── 丸い耳
└── 大きな頭と太い首

差分パラメータ:
├── 体色パターン: white（ホッキョクグマ）/ black_white（パンダ）/ stripe_chest（マレーグマ）
├── 体型: very_large（ホッキョクグマ）/ medium（マレーグマ）/ round（ジャイアントパンダ）
└── 尾: very_short（ほぼ全般）/ medium_fluffy（レッサーパンダ）
```

### Base 3: `primate` — 霊長類型

```
対象種:
ゴリラ / チンパンジー / オランウータン / マンドリル / ニホンザル

視覚的特徴:
├── 半直立〜直立（ゴリラ：ナックルウォーキング）
├── 長い腕（前肢）
├── 顔が前向きで目が大きい
├── 尾なし or 短尾（類人猿）
└── 表情が豊か（顔の差分が識別に重要）

差分パラメータ:
├── 体格: massive（ゴリラ）/ medium（チンパンジー）/ long_armed（オランウータン）
├── 顔: colorful_face（マンドリル）/ bare_face（類人猿）
└── 姿勢: knuckle_walk（ゴリラ）/ bipedal（直立）
```

### Base 4: `megaherbivore` — 大型草食獣型

```
対象種:
アジアゾウ / キリン / カバ / コビトカバ / シロサイ / シマウマ / オカピ / マレーバク

視覚的特徴:
├── 4足歩行・大きな体
├── 種ごとの際立った特徴が強い（鼻・首・角・縞）
└── 重厚感・安定感のあるシルエット

差分パラメータ（種ごとの固有パーツ）:
├── 鼻: trunk_long（ゾウ）/ short_disc（バク）/ horn（サイ）
├── 首: very_long（キリン）/ short_thick（カバ）
├── 体型: massive_round（カバ）/ barrel（ゾウ）/ horse_like（シマウマ・オカピ）
└── 縞/模様: stripes（シマウマ）/ giraffe_spots（キリン・オカピ類似）
```

### Base 5: `small_mammal` — 小型哺乳類型

```
対象種:
カピバラ / ミーアキャット / フェネック / コツメカワウソ / ビンツロング /
センザンコウ / ツチブタ

視覚的特徴:
├── 小〜中型
├── 種の多様性が最も高い（体型・体表が全然違う）
└── 固有の際立った特徴で識別

差分パラメータ:
├── 耳: very_large（フェネック）/ small_round（カピバラ）/ upright（ミーアキャット）
├── 体表: scales（センザンコウ）/ smooth（カワウソ）/ fluffy（ビンツロング）
├── 姿勢: upright（ミーアキャット）/ horizontal（カピバラ・カワウソ）
└── 鼻: long_tube（ツチブタ）/ normal
```

### Base 6: `avian` — 鳥類型

```
対象種:
フラミンゴ（初期）+ 将来追加予定の鳥類

視覚的特徴:
├── 2足歩行
├── 羽・くちばし・尾羽
└── 首の形が種ごとに特徴的

差分パラメータ:
├── 首: curved_long（フラミンゴ）/ straight（ペンギン想定）
├── 脚: long_thin（フラミンゴ）/ short_thick（ペンギン）
└── くちばし: curved_down（フラミンゴ）/ straight
```

### Base 7: `reptile` — 爬虫類型

```
対象種:
コモドオオトカゲ

視覚的特徴:
├── 4足・低い重心（腹が地面に近い）
├── 長い尾
├── 頭が平らで横に長い
└── 鱗の質感を示す輪郭

差分パラメータ:
├── 体長: very_long（コモド）
└── 尾: very_long_tapered
```

---

## 差分パーツ対応表（seed_data 32種 全種）

| 種 | base | ears | tail | body | 固有パーツ |
|----|------|------|------|------|-----------|
| ライオン | felid | pointed_small | long_curved | muscular | mane（♂） |
| トラ | felid | pointed_small | long_curved | muscular | — |
| アジアゾウ | megaherbivore | fan_large | short | barrel | trunk |
| キリン | megaherbivore | pointed | short | horse_tall | very_long_neck |
| カバ | megaherbivore | small | stub | massive_round | wide_mouth |
| ゴリラ | primate | small | none | massive | knuckle |
| チンパンジー | primate | medium | none | medium | — |
| ホッキョクグマ | ursid | round_small | very_short | very_large | — |
| シマウマ | megaherbivore | pointed | tufted | horse | stripes |
| フラミンゴ | avian | none | tail_fan | slim | curved_neck, curved_beak |
| レッサーパンダ | ursid | round | medium_fluffy | small | — |
| ユキヒョウ | felid | pointed_small | very_long_fluffy | medium | — |
| オランウータン | primate | small | none | long_armed | — |
| マレーバク | megaherbivore | oval | short | barrel | short_trunk |
| マンドリル | primate | small | stub | medium | colorful_face |
| カピバラ | small_mammal | small_round | none | barrel | — |
| オカピ | megaherbivore | large_pointed | tufted | horse | short_neck_stripes |
| コツメカワウソ | small_mammal | round_small | medium | streamlined | — |
| ミーアキャット | small_mammal | small | thin | slim | upright |
| チーター | felid | round_small | long_curved | slender | tear_marks |
| ジャイアントパンダ | ursid | round | very_short | round | eye_patches |
| ウンピョウ | felid | pointed | long | medium | — |
| コビトカバ | megaherbivore | small | stub | medium_round | — |
| フェネック | small_mammal | very_large | bushy | small | — |
| センザンコウ | small_mammal | small | long | scaled | scales |
| ビンツロング | small_mammal | tufted | long_prehensile | long | — |
| マレーグマ | ursid | round | very_short | medium | chest_patch |
| ツチブタ | small_mammal | very_large_rabbit | medium | barrel | long_snout |
| シロサイ | megaherbivore | pointed | stub | very_massive | double_horn |
| ニホンザル | primate | small | short | medium | red_face |
| アムールヒョウ | felid | pointed_small | long_curved | medium | — |
| コモドオオトカゲ | reptile | none | very_long | long_flat | forked_tongue |

---

## Rei へのメモ

Path の設計は Rei さんに任せます。私からは**識別に最低限必要な視覚要素**だけ整理します。

各 Base の「これがないと別の動物に見える」要素:
- `felid`: 低重心 + 長い尾 + 尖った耳（この3つが揃えば猫科に見える）
- `ursid`: 丸い耳 + ずんぐり体型（耳の形が最重要）
- `primate`: 長い腕 + 直立気味（腕の比率が命）
- `megaherbivore`: 固有パーツが識別の核（ゾウの鼻を省くと何か分からない）
- `small_mammal`: 耳のサイズが最大の差分（フェネックは耳が体の1/3）
- `avian`: 首のカーブと足の長さ
- `reptile`: 腹が低い + 長い尾

---

## 変更ファイル

| ファイル | 変更種別 |
|---------|---------|
| `devlog/008_zoologist_advisor.md` | 新規 |
