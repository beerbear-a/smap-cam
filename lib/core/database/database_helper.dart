import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../mock/mock_photo_library.dart';
import '../models/ai_lifelog_draft.dart';
import '../models/encounter.dart';
import '../models/film_session.dart';
import '../models/photo.dart';
import '../models/species.dart';
import '../models/zoo.dart';
import 'seed_data.dart';

class DatabaseHelper {
  static const _databaseName = 'zootocam.db';
  static const _databaseVersion = 8;

  static const tableFilmSessions = 'film_sessions';
  static const tablePhotos = 'photos';
  static const tableAiLifelogDrafts = 'ai_lifelog_drafts';
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
    await _createAiTables(db);
    await _createAnimalTables(db);
    await _seedData(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createAnimalTables(db);
      await _seedData(db);
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE $tableFilmSessions ADD COLUMN capture_mode TEXT DEFAULT 'film'",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE $tableFilmSessions ADD COLUMN theme TEXT",
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE $tableFilmSessions ADD COLUMN index_sheet_path TEXT",
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE $tableFilmSessions ADD COLUMN last_restored_at INTEGER",
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE $tableFilmSessions ADD COLUMN develop_ready_at INTEGER",
      );
    }
    if (oldVersion < 8) {
      await _createAiTables(db);
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
        theme         TEXT,
        index_sheet_path TEXT,
        develop_ready_at INTEGER,
        last_restored_at INTEGER,
        memo          TEXT,
        status        TEXT DEFAULT 'shooting',
        capture_mode  TEXT DEFAULT 'film',
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

  static Future<void> _createAiTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAiLifelogDrafts (
        draft_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        tone TEXT NOT NULL,
        title TEXT,
        subtitle TEXT,
        intro TEXT,
        body_markdown TEXT,
        body_plain_text TEXT,
        hashtags_json TEXT,
        social_summary TEXT,
        source_snapshot_json TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
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
      batch.insert(tableSpecies, sp,
          conflictAlgorithm: ConflictAlgorithm.ignore);
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

  static Future<void> deleteFilmSession(String sessionId) async {
    final db = await database;
    await db.delete(
      tableEncounters,
      where:
          'photo_id IN (SELECT photo_id FROM $tablePhotos WHERE session_id = ?)',
      whereArgs: [sessionId],
    );
    await db.delete(
      tablePhotos,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      tableFilmSessions,
      where: 'session_id = ?',
      whereArgs: [sessionId],
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

  static Future<List<FilmSession>> getFilmSessionsForZoo(String zooId) async {
    final db = await database;
    final maps = await db.query(
      tableFilmSessions,
      where: 'zoo_id = ?',
      whereArgs: [zooId],
      orderBy: 'date DESC',
    );
    return maps.map(FilmSession.fromMap).toList();
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

  static Future<List<FilmSession>> getShelvedFilmSessions() async {
    final db = await database;
    final maps = await db.query(
      tableFilmSessions,
      where: "status = 'shelved'",
      orderBy: 'date DESC',
    );
    return maps.map(FilmSession.fromMap).toList();
  }

  static Future<bool> hasFilmSessionOnDay(DateTime date) async {
    final db = await database;
    final dayStart = DateTime(date.year, date.month, date.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    final maps = await db.query(
      tableFilmSessions,
      columns: ['session_id'],
      where: 'capture_mode = ? AND date >= ? AND date < ?',
      whereArgs: [
        CaptureMode.film.name,
        dayStart.millisecondsSinceEpoch,
        nextDay.millisecondsSinceEpoch,
      ],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ── AiLifelogDraft ───────────────────────────────────────

  static Future<void> insertAiLifelogDraft(AiLifelogDraft draft) async {
    final db = await database;
    await db.insert(
      tableAiLifelogDrafts,
      draft.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateAiLifelogDraft(AiLifelogDraft draft) async {
    final db = await database;
    await db.update(
      tableAiLifelogDrafts,
      draft.toMap(),
      where: 'draft_id = ?',
      whereArgs: [draft.draftId],
    );
  }

  static Future<AiLifelogDraft?> getLatestAiLifelogDraftForSession(
    String sessionId,
  ) async {
    final db = await database;
    final maps = await db.query(
      tableAiLifelogDrafts,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AiLifelogDraft.fromMap(maps.first);
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

  static Future<void> ensureMockAlbumSeeded() async {
    final db = await database;
    final photoCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tablePhotos'),
        ) ??
        0;
    if (photoCount > 0) return;

    final mockPaths = availableMockPhotoPaths();
    if (mockPaths.isEmpty) return;

    final now = DateTime.now();
    final demoSessions = [
      (
        session: FilmSession(
          sessionId: 'demo_roll_ueno',
          title: '上野動物園',
          locationName: '上野動物園',
          lat: 35.7161,
          lng: 139.7716,
          zooId: 'zoo_ueno',
          date: now.subtract(const Duration(days: 6)),
          theme: '春の光とレッサーパンダ',
          memo: '春の午後、ゆっくり見返したい一本。',
          status: FilmStatus.developed,
          captureMode: CaptureMode.film,
        ),
        speciesIds: ['sp_red_panda', 'sp_giant_panda', 'sp_otter'],
        subjects: ['レッサーパンダ', 'ジャイアントパンダ', 'コツメカワウソ'],
        memos: ['木陰でひと休み', 'ガラス越しでも目が合った', '水辺でじゃれ合っていた'],
        photos: mockPaths.take(3).toList(),
      ),
      (
        session: FilmSession(
          sessionId: 'demo_roll_zoorasia',
          title: 'ズーラシア',
          locationName: 'よこはま動物園 ズーラシア',
          lat: 35.5003,
          lng: 139.5222,
          zooId: 'zoo_yokohama',
          date: now.subtract(const Duration(days: 12)),
          theme: '夕方の大きな動き',
          memo: '歩いた距離ごと残っている夕方のロール。',
          status: FilmStatus.developed,
          captureMode: CaptureMode.film,
        ),
        speciesIds: ['sp_polar_bear', 'sp_tiger'],
        subjects: ['ホッキョクグマ', 'トラ'],
        memos: ['白い光がきれいに回っていた', '遠くにいても存在感が強かった'],
        photos: mockPaths.skip(3).take(2).toList(),
      ),
    ];

    for (final demo in demoSessions) {
      await insertFilmSession(demo.session);
      for (var i = 0; i < demo.photos.length; i++) {
        final photoId = '${demo.session.sessionId}_photo_$i';
        final timestamp = demo.session.date.add(Duration(minutes: i * 18));
        final photo = Photo(
          photoId: photoId,
          sessionId: demo.session.sessionId,
          imagePath: demo.photos[i],
          timestamp: timestamp,
          subject: demo.subjects[i],
          memo: demo.memos[i],
        );
        await insertPhoto(photo);
        await insertEncounter(
          Encounter(
            encounterId: '${demo.session.sessionId}_encounter_$i',
            photoId: photoId,
            speciesId: demo.speciesIds[i],
            zooId: demo.session.zooId,
            memo: demo.memos[i],
            createdAt: timestamp,
          ),
        );
      }
    }
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
    return allZoos.where((z) => z.distanceTo(lat, lng) <= radiusKm).toList()
      ..sort(
          (a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
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

  static Future<Species?> getSpecies(String speciesId) async {
    final db = await database;
    final maps = await db.query(
      tableSpecies,
      where: 'species_id = ?',
      whereArgs: [speciesId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Species.fromMap(maps.first);
  }

  static Future<List<Map<String, dynamic>>> getZooEncounterHighlights(
    String zooId,
  ) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        e.species_id,
        s.name_ja,
        s.name_en,
        s.rarity,
        s.asset_key,
        COUNT(*) AS encounter_count,
        MIN(e.created_at) AS first_at,
        MAX(e.created_at) AS last_at
      FROM $tableEncounters e
      INNER JOIN $tableSpecies s ON e.species_id = s.species_id
      WHERE e.zoo_id = ?
      GROUP BY e.species_id, s.name_ja, s.name_en, s.rarity, s.asset_key
      ORDER BY encounter_count DESC, last_at DESC
    ''', [zooId]);
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
