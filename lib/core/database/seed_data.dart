/// 初期シードデータ: 動物園 & 動物種
library;

// ── 動物園 ────────────────────────────────────────────────────

const List<Map<String, dynamic>> seedZoos = [
  {
    'zoo_id': 'zoo_ueno',
    'name': '上野動物園',
    'prefecture': '東京都',
    'lat': 35.7161,
    'lng': 139.7716,
  },
  {
    'zoo_id': 'zoo_tama',
    'name': '多摩動物公園',
    'prefecture': '東京都',
    'lat': 35.6363,
    'lng': 139.3780,
  },
  {
    'zoo_id': 'zoo_chiba',
    'name': '千葉市動物公園',
    'prefecture': '千葉県',
    'lat': 35.5980,
    'lng': 140.1264,
  },
  {
    'zoo_id': 'zoo_yokohama',
    'name': 'よこはま動物園 ズーラシア',
    'prefecture': '神奈川県',
    'lat': 35.5003,
    'lng': 139.5222,
  },
  {
    'zoo_id': 'zoo_sapporo',
    'name': '円山動物園',
    'prefecture': '北海道',
    'lat': 43.0543,
    'lng': 141.3073,
  },
  {
    'zoo_id': 'zoo_asahikawa',
    'name': '旭山動物園',
    'prefecture': '北海道',
    'lat': 43.7705,
    'lng': 142.3979,
  },
  {
    'zoo_id': 'zoo_sendai',
    'name': '仙台市八木山動物公園',
    'prefecture': '宮城県',
    'lat': 38.2464,
    'lng': 140.8471,
  },
  {
    'zoo_id': 'zoo_higashiyama',
    'name': '東山動植物園',
    'prefecture': '愛知県',
    'lat': 35.1574,
    'lng': 136.9758,
  },
  {
    'zoo_id': 'zoo_tennoji',
    'name': '天王寺動物園',
    'prefecture': '大阪府',
    'lat': 34.6512,
    'lng': 135.5064,
  },
  {
    'zoo_id': 'zoo_kobe_oji',
    'name': '神戸市立王子動物園',
    'prefecture': '兵庫県',
    'lat': 34.7238,
    'lng': 135.1892,
  },
  {
    'zoo_id': 'zoo_kyoto',
    'name': '京都市動物園',
    'prefecture': '京都府',
    'lat': 35.0155,
    'lng': 135.7834,
  },
  {
    'zoo_id': 'zoo_hiroshima',
    'name': '安佐動物公園',
    'prefecture': '広島県',
    'lat': 34.5114,
    'lng': 132.4638,
  },
  {
    'zoo_id': 'zoo_fukuoka',
    'name': '福岡市動物園',
    'prefecture': '福岡県',
    'lat': 33.5754,
    'lng': 130.3849,
  },
  {
    'zoo_id': 'zoo_naha',
    'name': '沖縄こどもの国',
    'prefecture': '沖縄県',
    'lat': 26.3634,
    'lng': 127.8278,
  },
  {
    'zoo_id': 'zoo_ibaraki',
    'name': '茨城県自然博物館・ミュージアムパーク',
    'prefecture': '茨城県',
    'lat': 36.0583,
    'lng': 139.9968,
  },
];

// ── 動物種 ──────────────────────────────────────────────────
// rarity: 1=普通 2=やや珍しい 3=珍しい 4=超レア

const List<Map<String, dynamic>> seedSpecies = [
  // ── レアリティ 1: 全国どこでも会える ──
  {'species_id': 'sp_lion', 'name_ja': 'ライオン', 'name_en': 'African Lion', 'rarity': 1, 'asset_key': 'lion'},
  {'species_id': 'sp_tiger', 'name_ja': 'トラ', 'name_en': 'Tiger', 'rarity': 1, 'asset_key': 'tiger'},
  {'species_id': 'sp_elephant', 'name_ja': 'アジアゾウ', 'name_en': 'Asian Elephant', 'rarity': 1, 'asset_key': 'elephant'},
  {'species_id': 'sp_giraffe', 'name_ja': 'キリン', 'name_en': 'Giraffe', 'rarity': 1, 'asset_key': 'giraffe'},
  {'species_id': 'sp_hippo', 'name_ja': 'カバ', 'name_en': 'Hippopotamus', 'rarity': 1, 'asset_key': 'hippo'},
  {'species_id': 'sp_gorilla', 'name_ja': 'ゴリラ', 'name_en': 'Gorilla', 'rarity': 1, 'asset_key': 'gorilla'},
  {'species_id': 'sp_chimp', 'name_ja': 'チンパンジー', 'name_en': 'Chimpanzee', 'rarity': 1, 'asset_key': 'chimp'},
  {'species_id': 'sp_polar_bear', 'name_ja': 'ホッキョクグマ', 'name_en': 'Polar Bear', 'rarity': 1, 'asset_key': 'polar_bear'},
  {'species_id': 'sp_zebra', 'name_ja': 'シマウマ', 'name_en': 'Zebra', 'rarity': 1, 'asset_key': 'zebra'},
  {'species_id': 'sp_flamingo', 'name_ja': 'フラミンゴ', 'name_en': 'Flamingo', 'rarity': 1, 'asset_key': 'flamingo'},

  // ── レアリティ 2: やや珍しい ──
  {'species_id': 'sp_red_panda', 'name_ja': 'レッサーパンダ', 'name_en': 'Red Panda', 'rarity': 2, 'asset_key': 'red_panda'},
  {'species_id': 'sp_snow_leopard', 'name_ja': 'ユキヒョウ', 'name_en': 'Snow Leopard', 'rarity': 2, 'asset_key': 'snow_leopard'},
  {'species_id': 'sp_orangutan', 'name_ja': 'オランウータン', 'name_en': 'Orangutan', 'rarity': 2, 'asset_key': 'orangutan'},
  {'species_id': 'sp_tapir', 'name_ja': 'マレーバク', 'name_en': 'Malayan Tapir', 'rarity': 2, 'asset_key': 'tapir'},
  {'species_id': 'sp_mandrill', 'name_ja': 'マンドリル', 'name_en': 'Mandrill', 'rarity': 2, 'asset_key': 'mandrill'},
  {'species_id': 'sp_capybara', 'name_ja': 'カピバラ', 'name_en': 'Capybara', 'rarity': 2, 'asset_key': 'capybara'},
  {'species_id': 'sp_okapi', 'name_ja': 'オカピ', 'name_en': 'Okapi', 'rarity': 2, 'asset_key': 'okapi'},
  {'species_id': 'sp_otter', 'name_ja': 'コツメカワウソ', 'name_en': 'Asian Small-clawed Otter', 'rarity': 2, 'asset_key': 'otter'},
  {'species_id': 'sp_meerkat', 'name_ja': 'ミーアキャット', 'name_en': 'Meerkat', 'rarity': 2, 'asset_key': 'meerkat'},
  {'species_id': 'sp_cheetah', 'name_ja': 'チーター', 'name_en': 'Cheetah', 'rarity': 2, 'asset_key': 'cheetah'},

  // ── レアリティ 3: 珍しい ──
  {'species_id': 'sp_giant_panda', 'name_ja': 'ジャイアントパンダ', 'name_en': 'Giant Panda', 'rarity': 3, 'asset_key': 'giant_panda'},
  {'species_id': 'sp_clouded_leopard', 'name_ja': 'ウンピョウ', 'name_en': 'Clouded Leopard', 'rarity': 3, 'asset_key': 'clouded_leopard'},
  {'species_id': 'sp_pygmy_hippo', 'name_ja': 'コビトカバ', 'name_en': 'Pygmy Hippopotamus', 'rarity': 3, 'asset_key': 'pygmy_hippo'},
  {'species_id': 'sp_fennec', 'name_ja': 'フェネック', 'name_en': 'Fennec Fox', 'rarity': 3, 'asset_key': 'fennec'},
  {'species_id': 'sp_pangolin', 'name_ja': 'センザンコウ', 'name_en': 'Pangolin', 'rarity': 3, 'asset_key': 'pangolin'},
  {'species_id': 'sp_binturong', 'name_ja': 'ビンツロング', 'name_en': 'Binturong', 'rarity': 3, 'asset_key': 'binturong'},
  {'species_id': 'sp_sun_bear', 'name_ja': 'マレーグマ', 'name_en': 'Sun Bear', 'rarity': 3, 'asset_key': 'sun_bear'},
  {'species_id': 'sp_aardvark', 'name_ja': 'ツチブタ', 'name_en': 'Aardvark', 'rarity': 3, 'asset_key': 'aardvark'},

  // ── レアリティ 4: 超レア ──
  {'species_id': 'sp_white_rhino', 'name_ja': 'シロサイ', 'name_en': 'White Rhinoceros', 'rarity': 4, 'asset_key': 'white_rhino'},
  {'species_id': 'sp_snow_monkey', 'name_ja': 'ニホンザル（特別個体群）', 'name_en': 'Japanese Macaque', 'rarity': 4, 'asset_key': 'snow_monkey'},
  {'species_id': 'sp_amur_leopard', 'name_ja': 'アムールヒョウ', 'name_en': 'Amur Leopard', 'rarity': 4, 'asset_key': 'amur_leopard'},
  {'species_id': 'sp_komodo', 'name_ja': 'コモドオオトカゲ', 'name_en': 'Komodo Dragon', 'rarity': 4, 'asset_key': 'komodo'},
];
