class Photo {
  final String photoId;
  final String sessionId;
  final String imagePath;
  final DateTime timestamp;
  final String? subject;
  final String? memo;

  const Photo({
    required this.photoId,
    required this.sessionId,
    required this.imagePath,
    required this.timestamp,
    this.subject,
    this.memo,
  });

  Photo copyWith({
    String? photoId,
    String? sessionId,
    String? imagePath,
    DateTime? timestamp,
    String? subject,
    String? memo,
  }) {
    return Photo(
      photoId: photoId ?? this.photoId,
      sessionId: sessionId ?? this.sessionId,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
      subject: subject ?? this.subject,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photo_id': photoId,
      'session_id': sessionId,
      'image_path': imagePath,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'subject': subject,
      'memo': memo,
    };
  }

  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      photoId: map['photo_id'] as String,
      sessionId: map['session_id'] as String,
      imagePath: map['image_path'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      subject: map['subject'] as String?,
      memo: map['memo'] as String?,
    );
  }
}
