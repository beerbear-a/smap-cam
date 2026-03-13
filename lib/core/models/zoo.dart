import 'dart:math' as math;

class Zoo {
  final String zooId;
  final String name;
  final String prefecture;
  final double lat;
  final double lng;

  const Zoo({
    required this.zooId,
    required this.name,
    required this.prefecture,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() => {
        'zoo_id': zooId,
        'name': name,
        'prefecture': prefecture,
        'lat': lat,
        'lng': lng,
      };

  factory Zoo.fromMap(Map<String, dynamic> map) => Zoo(
        zooId: map['zoo_id'] as String,
        name: map['name'] as String,
        prefecture: map['prefecture'] as String,
        lat: map['lat'] as double,
        lng: map['lng'] as double,
      );

  /// 現在地からの距離 (km) を Haversine 公式で計算
  double distanceTo(double userLat, double userLng) {
    const r = 6371.0;
    final dLat = _rad(lat - userLat);
    final dLng = _rad(lng - userLng);
    final sinDlat = math.sin(dLat / 2);
    final sinDlng = math.sin(dLng / 2);
    final a = sinDlat * sinDlat +
        math.cos(_rad(userLat)) * math.cos(_rad(lat)) * sinDlng * sinDlng;
    return r * 2 * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
