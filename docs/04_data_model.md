# ZOOSMAP - データモデル設計

> バージョン: 1.0
> 最終更新: 2026-03-13

---

## 1. DB全体像

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│   animals   │────<│   zoo_animals   │>────│    zoos     │
│  (種マスター) │     │  (飼育マッピング) │     │ (動物園MB)  │
└─────────────┘     └─────────────────┘     └─────────────┘
       │                                            │
       │                                            │
       └──────────────>┌──────────────┐<───────────┘
                       │  encounters  │
                       │  (出会い記録) │
                       └──────────────┘
                               │
                               │
                       ┌───────▼──────┐
                       │    photos    │
                       │  (写真ファイル) │
                       └──────────────┘
```

---

## 2. テーブル定義

### animals（種マスター）
JAZAのCSV（5,756行）をインポート

```sql
CREATE TABLE animals (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name_ja         TEXT NOT NULL,          -- 和名（例: レッサーパンダ）
  name_subspecies TEXT,                   -- 品種名・亜種名
  name_scientific TEXT,                   -- 学名
  name_en         TEXT,                   -- 英名
  class_name      TEXT,                   -- 綱（哺乳綱・鳥綱）
  order_name      TEXT,                   -- 目
  family_name     TEXT,                   -- 科
  rarity          INTEGER DEFAULT 1,      -- ★1〜4（zoo_animals から算出）
  is_active       INTEGER DEFAULT 1       -- 表示フラグ
);

CREATE INDEX idx_animals_name_ja ON animals(name_ja);
CREATE INDEX idx_animals_class ON animals(class_name);
CREATE INDEX idx_animals_rarity ON animals(rarity);
```

**レアリティ算出ロジック:**
```
zoo_animals テーブルで各 animal_id が登録されている zoo 数をカウント

飼育施設数  レアリティ
20施設以上  ★1（よく会える）
5〜19施設   ★2（そこそこ）
2〜4施設    ★3（希少）
1施設       ★4（伝説レア）
0施設       非表示（日本未飼育）
```

---

### zoos（動物園マスター）
```sql
CREATE TABLE zoos (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,          -- 施設名（例: 上野動物園）
  name_short      TEXT,                   -- 略称（例: 上野）
  prefecture      TEXT,                   -- 都道府県
  address         TEXT,                   -- 住所
  lat             REAL NOT NULL,          -- 緯度
  lng             REAL NOT NULL,          -- 経度
  website         TEXT,                   -- 公式サイト
  jaza_member     INTEGER DEFAULT 1,      -- JAZA加盟フラグ
  zoo_type        TEXT DEFAULT 'zoo',     -- zoo / aquarium / safari
  is_active       INTEGER DEFAULT 1
);

CREATE INDEX idx_zoos_location ON zoos(lat, lng);
CREATE INDEX idx_zoos_prefecture ON zoos(prefecture);
```

---

### zoo_animals（動物園×種マッピング）
```sql
CREATE TABLE zoo_animals (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  zoo_id    INTEGER NOT NULL REFERENCES zoos(id),
  animal_id INTEGER NOT NULL REFERENCES animals(id),
  UNIQUE(zoo_id, animal_id)
);

CREATE INDEX idx_zoo_animals_zoo ON zoo_animals(zoo_id);
CREATE INDEX idx_zoo_animals_animal ON zoo_animals(animal_id);
```

---

### encounters（出会い記録 = ユーザーデータ）
```sql
CREATE TABLE encounters (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  animal_id       INTEGER NOT NULL REFERENCES animals(id),
  zoo_id          INTEGER REFERENCES zoos(id),  -- NULL = 野生
  photo_path      TEXT,                          -- 写真ファイルパス（任意）
  memo            TEXT,                          -- 一言メモ（任意）
  lat             REAL,                          -- 撮影位置
  lng             REAL,
  encountered_at  INTEGER NOT NULL,              -- Unix timestamp
  created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

CREATE INDEX idx_encounters_animal ON encounters(animal_id);
CREATE INDEX idx_encounters_zoo ON encounters(zoo_id);
CREATE INDEX idx_encounters_date ON encounters(encountered_at DESC);
```

---

### user_settings（ユーザー設定）
```sql
CREATE TABLE user_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- 初期データ
INSERT INTO user_settings VALUES ('username', '');
INSERT INTO user_settings VALUES ('is_pro', '0');           -- 買い切り済み
INSERT INTO user_settings VALUES ('selected_lut', 'free_natural');
INSERT INTO user_settings VALUES ('watermark_style', 'default');
INSERT INTO user_settings VALUES ('purchase_token', '');    -- StoreKit token
```

---

## 3. Dart モデル定義

```dart
// lib/core/models/animal.dart
class Animal {
  final int id;
  final String nameJa;
  final String? nameSubspecies;
  final String? nameScientific;
  final String? nameEn;
  final String className;   // 哺乳綱 / 鳥綱
  final String? orderName;
  final String? familyName;
  final int rarity;         // 1〜4

  bool get isRare => rarity >= 3;
  String get rarityStars => '★' * rarity + '☆' * (4 - rarity);
}

// lib/core/models/zoo.dart
class Zoo {
  final int id;
  final String name;
  final String? nameShort;
  final String? prefecture;
  final double lat;
  final double lng;
  final String zooType;     // zoo / aquarium / safari
}

// lib/core/models/encounter.dart
class Encounter {
  final int id;
  final int animalId;
  final int? zooId;
  final String? photoPath;
  final String? memo;
  final double? lat;
  final double? lng;
  final DateTime encounteredAt;

  // JOINしたデータ
  final Animal? animal;
  final Zoo? zoo;
}
```

---

## 4. 図鑑クエリ

### 自分の図鑑（発見済み種一覧）
```sql
SELECT DISTINCT
  a.*,
  COUNT(e.id) as encounter_count,
  MIN(e.encountered_at) as first_encounter,
  z.name as first_zoo_name
FROM animals a
INNER JOIN encounters e ON e.animal_id = a.id
LEFT JOIN zoos z ON z.id = e.zoo_id
GROUP BY a.id
ORDER BY encounter_count DESC, first_encounter ASC;
```

### 特定動物園の図鑑（発見済み + 未発見）
```sql
-- 発見済み
SELECT a.*, 1 as discovered,
  COUNT(e.id) as count
FROM animals a
INNER JOIN zoo_animals za ON za.animal_id = a.id AND za.zoo_id = ?
LEFT JOIN encounters e ON e.animal_id = a.id AND e.zoo_id = ?
GROUP BY a.id

UNION ALL

-- 未発見（シルエット）
SELECT a.*, 0 as discovered, 0 as count
FROM animals a
INNER JOIN zoo_animals za ON za.animal_id = a.id AND za.zoo_id = ?
WHERE a.id NOT IN (
  SELECT animal_id FROM encounters WHERE zoo_id = ?
)
ORDER BY rarity DESC, name_ja ASC;
```

### 発見統計
```sql
SELECT
  (SELECT COUNT(DISTINCT animal_id) FROM encounters) as discovered,
  (SELECT COUNT(*) FROM animals WHERE is_active = 1) as total,
  (SELECT COUNT(*) FROM encounters) as total_encounters,
  (SELECT COUNT(DISTINCT zoo_id) FROM encounters) as zoos_visited;
```

---

## 5. データ移行計画

### Phase 1: CSVインポート
```
jaza_animals.csv
└── Pythonスクリプトでパース
    └── SQLiteにバルクインサート
        └── アプリに assets/db/jaza_animals.db としてバンドル
```

### Phase 2: 動物園マスター構築
```
主要20動物園を手動登録（週末作業）
├── 上野動物園
├── 多摩動物公園
├── 旭山動物公園
├── 東山動植物園
├── 神戸市立王子動物園
├── 天王寺動物園
├── 円山動物園
├── 埼玉こども動物自然公園
├── 那須どうぶつ王国
├── よこはま動物園ズーラシア
└── ...
```

### Phase 3: zoo_animals マッピング
```
各動物園の公式サイト / JAZAデータから飼育種リストを取得
└── CSVで管理 → SQLiteにインポート
    規模感: 20園 × 平均150種 = 約3,000レコード
```

---

## 6. CSVインポートスクリプト（Python）

```python
# scripts/import_animals.py
import csv
import sqlite3
import re

def parse_class_order_family(text):
    """哺乳綱・カンガルー目・カンガルー科 をパース"""
    parts = text.split('・')
    class_name = parts[0] if len(parts) > 0 else ''
    order_name = parts[1] if len(parts) > 1 else None
    family_name = parts[2] if len(parts) > 2 else None
    return class_name, order_name, family_name

def import_csv(csv_path, db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            class_name, order_name, family_name = parse_class_order_family(
                row.get('綱・目・科', '')
            )
            cursor.execute('''
                INSERT OR IGNORE INTO animals
                (name_ja, name_subspecies, name_scientific,
                 name_en, class_name, order_name, family_name)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                row.get('和名', '').strip(),
                row.get('品種名特徴', '').strip() or None,
                row.get('学名', '').strip() or None,
                row.get('英名', '').strip() or None,
                class_name,
                order_name,
                family_name,
            ))

    conn.commit()
    conn.close()
    print(f"インポート完了: {db_path}")

if __name__ == '__main__':
    import_csv('jaza_animals.csv', 'assets/db/jaza_animals.db')
```
