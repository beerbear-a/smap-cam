import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/film_session.dart';
import '../models/photo.dart';

class DatabaseHelper {
  static const _databaseName = 'zootocam.db';
  static const _databaseVersion = 1;

  static const tableFilmSessions = 'film_sessions';
  static const tablePhotos = 'photos';

  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableFilmSessions (
        session_id    TEXT PRIMARY KEY,
        title         TEXT NOT NULL,
        location_name TEXT,
        lat           REAL,
        lng           REAL,
        date          INTEGER NOT NULL,
        memo          TEXT,
        status        TEXT DEFAULT 'shooting',
        photo_count   INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tablePhotos (
        photo_id    TEXT PRIMARY KEY,
        session_id  TEXT NOT NULL,
        image_path  TEXT NOT NULL,
        timestamp   INTEGER NOT NULL,
        subject     TEXT,
        memo        TEXT,
        FOREIGN KEY (session_id) REFERENCES $tableFilmSessions(session_id)
      )
    ''');
  }

  // ── FilmSession ──────────────────────────────────────────

  static Future<void> insertFilmSession(FilmSession session) async {
    final db = await database;
    await db.insert(
      tableFilmSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateFilmSession(FilmSession session) async {
    final db = await database;
    await db.update(
      tableFilmSessions,
      session.toMap(),
      where: 'session_id = ?',
      whereArgs: [session.sessionId],
    );
  }

  static Future<List<FilmSession>> getAllFilmSessions() async {
    final db = await database;
    final maps = await db.query(
      tableFilmSessions,
      orderBy: 'date DESC',
    );
    return maps.map(FilmSession.fromMap).toList();
  }

  static Future<FilmSession?> getFilmSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      tableFilmSessions,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (maps.isEmpty) return null;
    return FilmSession.fromMap(maps.first);
  }

  static Future<FilmSession?> getActiveSession() async {
    final db = await database;
    final maps = await db.query(
      tableFilmSessions,
      where: "status = 'shooting'",
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FilmSession.fromMap(maps.first);
  }

  // ── Photo ────────────────────────────────────────────────

  static Future<void> insertPhoto(Photo photo) async {
    final db = await database;
    await db.insert(
      tablePhotos,
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // increment photo_count
    await db.rawUpdate(
      'UPDATE $tableFilmSessions SET photo_count = photo_count + 1 WHERE session_id = ?',
      [photo.sessionId],
    );
  }

  static Future<List<Photo>> getPhotosForSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      tablePhotos,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map(Photo.fromMap).toList();
  }

  static Future<void> updatePhotoJournal(
    String photoId,
    String? subject,
    String? memo,
  ) async {
    final db = await database;
    await db.update(
      tablePhotos,
      {'subject': subject, 'memo': memo},
      where: 'photo_id = ?',
      whereArgs: [photoId],
    );
  }
}
