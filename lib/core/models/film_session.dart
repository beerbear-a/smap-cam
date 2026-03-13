enum FilmStatus { shooting, developing, developed }

class FilmSession {
  final String sessionId;
  final String title;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String? zooId;
  final DateTime date;
  final String? memo;
  final FilmStatus status;
  final int photoCount;

  const FilmSession({
    required this.sessionId,
    required this.title,
    this.locationName,
    this.lat,
    this.lng,
    this.zooId,
    required this.date,
    this.memo,
    this.status = FilmStatus.shooting,
    this.photoCount = 0,
  });

  static const int maxPhotos = 27;

  int get remainingShots => maxPhotos - photoCount;
  bool get isFull => photoCount >= maxPhotos;
  bool get isDeveloped => status == FilmStatus.developed;

  FilmSession copyWith({
    String? sessionId,
    String? title,
    String? locationName,
    double? lat,
    double? lng,
    String? zooId,
    DateTime? date,
    String? memo,
    FilmStatus? status,
    int? photoCount,
  }) {
    return FilmSession(
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      locationName: locationName ?? this.locationName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      zooId: zooId ?? this.zooId,
      date: date ?? this.date,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      photoCount: photoCount ?? this.photoCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'title': title,
      'location_name': locationName,
      'lat': lat,
      'lng': lng,
      'zoo_id': zooId,
      'date': date.millisecondsSinceEpoch,
      'memo': memo,
      'status': status.name,
      'photo_count': photoCount,
    };
  }

  factory FilmSession.fromMap(Map<String, dynamic> map) {
    return FilmSession(
      sessionId: map['session_id'] as String,
      title: map['title'] as String,
      locationName: map['location_name'] as String?,
      lat: map['lat'] as double?,
      lng: map['lng'] as double?,
      zooId: map['zoo_id'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      memo: map['memo'] as String?,
      status: FilmStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FilmStatus.shooting,
      ),
      photoCount: map['photo_count'] as int? ?? 0,
    );
  }
}
