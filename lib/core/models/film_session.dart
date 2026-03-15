import '../config/experience_rules.dart';

enum FilmStatus { shooting, shelved, developing, developed }

enum CaptureMode { instant, film }

class FilmSession {
  final String sessionId;
  final String title;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String? zooId;
  final DateTime date;
  final String? theme;
  final String? indexSheetPath;
  final DateTime? developReadyAt;
  final DateTime? lastRestoredAt;
  final String? memo;
  final FilmStatus status;
  final CaptureMode captureMode;
  final int photoCount;

  const FilmSession({
    required this.sessionId,
    required this.title,
    this.locationName,
    this.lat,
    this.lng,
    this.zooId,
    required this.date,
    this.theme,
    this.indexSheetPath,
    this.developReadyAt,
    this.lastRestoredAt,
    this.memo,
    this.status = FilmStatus.shooting,
    this.captureMode = CaptureMode.film,
    this.photoCount = 0,
  });

  static const int maxPhotos = 27;

  int get remainingShots => maxPhotos - photoCount;
  int get instantBatteryRemaining =>
      (instantBatteryCapacity - photoCount).clamp(0, instantBatteryCapacity);
  double get instantBatteryLevel =>
      instantBatteryRemaining / instantBatteryCapacity;
  bool get isFilmMode => captureMode == CaptureMode.film;
  bool get isInstantMode => captureMode == CaptureMode.instant;
  bool get isFull => isFilmMode && photoCount >= maxPhotos;
  bool get isDeveloped => status == FilmStatus.developed;
  bool get isShelved => status == FilmStatus.shelved;
  bool get canTakeMore => isInstantMode ? instantBatteryRemaining > 0 : !isFull;
  bool get canDevelop => isInstantMode || isFull;
  bool get isFilmModeLocked => isFilmMode && !isFull;
  bool get isFilmLookLocked => isFilmMode && photoCount > 0 && !isFull;
  bool get isAwaitingDevelopment => status == FilmStatus.developing;
  bool get isDevelopReady {
    if (!isAwaitingDevelopment) return true;
    final readyAt = developReadyAt;
    if (readyAt == null) return true;
    return !DateTime.now().isBefore(readyAt);
  }

  Duration? get remainingDevelopWait {
    final readyAt = developReadyAt;
    if (readyAt == null) return null;
    final remaining = readyAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  DateTime? get nextRestoreAvailableAt => lastRestoredAt?.add(
        const Duration(days: 7),
      );

  bool canRestoreNow({DateTime? now}) {
    final next = nextRestoreAvailableAt;
    if (next == null) return true;
    final current = now ?? DateTime.now();
    return !current.isBefore(next);
  }

  bool shouldAutoDevelop({DateTime? now}) {
    if (!isAwaitingDevelopment) return false;
    final current = now ?? DateTime.now();
    return !current.isBefore(date.add(const Duration(days: 365)));
  }

  FilmSession copyWith({
    String? sessionId,
    String? title,
    String? locationName,
    double? lat,
    double? lng,
    String? zooId,
    DateTime? date,
    String? theme,
    String? indexSheetPath,
    DateTime? developReadyAt,
    DateTime? lastRestoredAt,
    String? memo,
    FilmStatus? status,
    CaptureMode? captureMode,
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
      theme: theme ?? this.theme,
      indexSheetPath: indexSheetPath ?? this.indexSheetPath,
      developReadyAt: developReadyAt ?? this.developReadyAt,
      lastRestoredAt: lastRestoredAt ?? this.lastRestoredAt,
      memo: memo ?? this.memo,
      status: status ?? this.status,
      captureMode: captureMode ?? this.captureMode,
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
      'theme': theme,
      'index_sheet_path': indexSheetPath,
      'develop_ready_at': developReadyAt?.millisecondsSinceEpoch,
      'last_restored_at': lastRestoredAt?.millisecondsSinceEpoch,
      'memo': memo,
      'status': status.name,
      'capture_mode': captureMode.name,
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
      theme: map['theme'] as String?,
      indexSheetPath: map['index_sheet_path'] as String?,
      developReadyAt: map['develop_ready_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['develop_ready_at'] as int),
      lastRestoredAt: map['last_restored_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_restored_at'] as int),
      memo: map['memo'] as String?,
      status: FilmStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FilmStatus.shooting,
      ),
      captureMode: CaptureMode.values.firstWhere(
        (e) => e.name == map['capture_mode'],
        orElse: () => CaptureMode.film,
      ),
      photoCount: map['photo_count'] as int? ?? 0,
    );
  }
}
