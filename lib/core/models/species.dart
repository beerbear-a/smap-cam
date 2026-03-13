/// 動物種
class Species {
  final String speciesId;
  final String nameJa;
  final String nameEn;

  /// レアリティ 1〜4（国内飼育施設数が少ないほど高い）
  /// 1: 一般的 / 2: やや珍しい / 3: 珍しい / 4: 超レア
  final int rarity;

  /// assets/silhouettes/{assetKey}.png
  final String assetKey;

  const Species({
    required this.speciesId,
    required this.nameJa,
    required this.nameEn,
    required this.rarity,
    required this.assetKey,
  });

  Map<String, dynamic> toMap() => {
        'species_id': speciesId,
        'name_ja': nameJa,
        'name_en': nameEn,
        'rarity': rarity,
        'asset_key': assetKey,
      };

  factory Species.fromMap(Map<String, dynamic> map) => Species(
        speciesId: map['species_id'] as String,
        nameJa: map['name_ja'] as String,
        nameEn: map['name_en'] as String,
        rarity: map['rarity'] as int,
        assetKey: map['asset_key'] as String,
      );
}
