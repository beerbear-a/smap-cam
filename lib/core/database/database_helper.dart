import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/encounter.dart';
import '../models/film_session.dart';
import '../models/photo.dart';
import '../models/species.dart';
import '../models/zoo.dart';
import 'seed_data.dart';

class DatabaseHelper {
  static const _databaseName = 'zootocam.db';
  static const _databaseVersion = 2;

  static const tableFilmSessions = 'film_sessions';
  static const tablePhotos = 'photos';
  static const tableZoos = 'zoos';
  static const tableSpecies = 'species';
  static const tableEncounters = 'encounters';

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
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createAnimalTables(db);
    await _seedData(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAnimalTables(db);
      await _seedData(db);
    }
  }

  static Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE $tableFilmSessions (
        session_id    TEXT PRIMARY KEY,
        title         TEXT NOT NULL,
        location_name TEXT,
        lat           REAL,
        lng           REAL,
        zoo_id        TEXT,
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

  static Future<void> _createAnimalTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableZoos (
        zoo_id      TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        prefecture  TEXT NOT NULL,
        lat         REAL NOT NULL,
        lng         REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSpecies (
        species_id  TEXT PRIMARY KEY,
        name_ja     TEXT NOT NULL,
        name_en     TEXT NOT NULL,
        rarity      INTEGER NOT NULL DEFAULT 1,
        asset_key   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableEncounters (
        encounter_id  TEXT PRIMARY KEY,
        photo_id      TEXT NOT NULL,
        species_id    TEXT NOT NULL,
        zoo_id        TEXT,
        memo          TEXT,
        created_at    INTEGER NOT NULL,
        FOREIGN KEY (photo_id)    REFERENCES $tablePhotos(photo_id),
        FOREIGN KEY (species_id)  REFERENCES $tableSpecies(species_id),
        FOREIGN KEY (zoo_id)      REFERENCES $tableZoos(zoo_id)
      )
    ''');
  }

  static Future<void> _seedData(Database db) async {
    final batch = db.batch();
    for (final zoo in seedZoos) {
      batch.insert(tableZoos, zoo, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final sp in seedSpecies) {
      batch.insert(tableSpecies, sp, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
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

  // ── Zoo ──────────────────────────────────────────────────

  static Future<List<Zoo>> getAllZoos() async {
    final db = await database;
    final maps = await db.query(tableZoos, orderBy: 'name ASC');
    return maps.map(Zoo.fromMap).toList();
  }

  static Future<Zoo?> getZoo(String zooId) async {
    final db = await database;
    final maps = await db.query(
      tableZoos,
      where: 'zoo_id = ?',
      whereArgs: [zooId],
    );
    if (maps.isEmpty) return null;
    return Zoo.fromMap(maps.first);
  }

  static Future<List<Zoo>> getZoosNear(
    double lat,
    double lng, {
    double radiusKm = 5.0,
  }) async {
    final allZoos = await getAllZoos();
    return allZoos
        .where((z) => z.distanceTo(lat, lng) <= radiusKm)
        .toList()
      ..sort((a, b) =>
          a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
  }

  // ── Species ──────────────────────────────────────────────

  static Future<List<Species>> getAllSpecies() async {
    final db = await database;
    final maps = await db.query(
      tableSpecies,
      orderBy: 'rarity ASC, name_ja ASC',
    );
    return maps.map(Species.fromMap).toList();
  }

  static Future<List<Species>> searchSpecies(String query) async {
    final db = await database;
    final maps = await db.query(
      tableSpecies,
      where: 'name_ja LIKE ? OR name_en LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'rarity ASC',
      limit: 20,
    );
    return maps.map(Species.fromMap).toList();
  }

  // ── Encounter ────────────────────────────────────────────

  static Future<void> insertEncounter(Encounter encounter) async {
    final db = await database;
    await db.insert(
      tableEncounters,
      encounter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Encounter>> getEncountersBySession(
    String sessionId,
  ) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT e.* FROM $tableEncounters e
      INNER JOIN $tablePhotos p ON e.photo_id = p.photo_id
      WHERE p.session_id = ?
      ORDER BY e.created_at ASC
    ''', [sessionId]);
    return maps.map(Encounter.fromMap).toList();
  }

  /// 種ごとに出会った回数と最初の出会いを返す（図鑑用）
  static Future<List<Map<String, dynamic>>> getEncounterSummary() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        e.species_id,
        COUNT(*) AS encounter_count,
        MIN(e.created_at) AS first_at,
        MIN(e.zoo_id) AS first_zoo_id
      FROM $tableEncounters e
      GROUP BY e.species_id
    ''');
  }

  /// 訪問済みの動物園 ID 一覧（マップ用）
  static Future<List<String>> getVisitedZooIds() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT zoo_id FROM $tableEncounters WHERE zoo_id IS NOT NULL',
    );
    return rows.map((r) => r['zoo_id'] as String).toList();
  }
}
