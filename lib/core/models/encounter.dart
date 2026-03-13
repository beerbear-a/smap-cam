/// 動物との出会い記録（1撮影 = 1 Encounter）
class Encounter {
  final String encounterId;
  final String photoId;
  final String speciesId;
  final String? zooId;
  final String? memo;
  final DateTime createdAt;

  const Encounter({
    required this.encounterId,
    required this.photoId,
    required this.speciesId,
    this.zooId,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'encounter_id': encounterId,
        'photo_id': photoId,
        'species_id': speciesId,
        'zoo_id': zooId,
        'memo': memo,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Encounter.fromMap(Map<String, dynamic> map) => Encounter(
        encounterId: map['encounter_id'] as String,
        photoId: map['photo_id'] as String,
        speciesId: map['species_id'] as String,
        zooId: map['zoo_id'] as String?,
        memo: map['memo'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
