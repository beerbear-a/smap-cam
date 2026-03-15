import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/ai_memory_assist.dart';
import '../../core/config/experience_rules.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/ai_lifelog_draft.dart';
import '../../core/models/film_session.dart';
import '../../core/navigation/main_tab_provider.dart';
import '../../core/models/photo.dart';
import '../../core/services/photo_library_service.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/mock_photo.dart';
import '../camera/widgets/film_preview.dart';
import '../checkin/checkin_screen.dart';
import '../develop/develop_screen.dart';
import '../journal/journal_screen.dart';
import '../share/contact_sheet_service.dart';
import 'photo_viewer_screen.dart';

class AlbumPhotoEntry {
  final Photo? photo;
  final FilmSession session;
  final List<Photo> sessionPhotos;
  final String imagePath;
  final DateTime sortTimestamp;
  final bool isIndexSheet;

  const AlbumPhotoEntry._({
    required this.photo,
    required this.session,
    required this.sessionPhotos,
    required this.imagePath,
    required this.sortTimestamp,
    required this.isIndexSheet,
  });

  factory AlbumPhotoEntry.photo({
    required Photo photo,
    required FilmSession session,
    required List<Photo> sessionPhotos,
  }) {
    return AlbumPhotoEntry._(
      photo: photo,
      session: session,
      sessionPhotos: sessionPhotos,
      imagePath: photo.imagePath,
      sortTimestamp: photo.timestamp,
      isIndexSheet: false,
    );
  }

  factory AlbumPhotoEntry.indexSheet({
    required FilmSession session,
    required List<Photo> sessionPhotos,
    required String imagePath,
    required DateTime sortTimestamp,
  }) {
    return AlbumPhotoEntry._(
      photo: null,
      session: session,
      sessionPhotos: sessionPhotos,
      imagePath: imagePath,
      sortTimestamp: sortTimestamp,
      isIndexSheet: true,
    );
  }
}

class AlbumSessionEntry {
  final FilmSession session;
  final List<Photo> photos;
  final AiLifelogDraft? latestAiDraft;

  const AlbumSessionEntry({
    required this.session,
    required this.photos,
    this.latestAiDraft,
  });

  Photo? get coverPhoto => photos.isEmpty ? null : photos.last;
  bool get hasAiDraft => latestAiDraft != null;
}

Widget _albumPhotoWidget({
  required FilmSession session,
  required Photo photo,
  BoxFit fit = BoxFit.cover,
}) {
  final file = File(photo.imagePath);
  if (!file.existsSync()) return MockPhotoView(fit: fit);

  final isBakedFilm =
      session.isFilmMode && photo.imagePath.endsWith('_film.png');
  if (session.isFilmMode && !isBakedFilm) {
    return FilmShaderImage(
      imagePath: photo.imagePath,
      lutType: LutType.natural,
      fit: fit,
    );
  }

  return Image.file(file, fit: fit);
}

Widget _albumEntryWidget({
  required AlbumPhotoEntry entry,
  BoxFit fit = BoxFit.cover,
}) {
  if (entry.isIndexSheet) {
    final file = File(entry.imagePath);
    if (!file.existsSync()) return MockPhotoView(fit: fit);
    return Image.file(file, fit: fit);
  }

  return _albumPhotoWidget(
    session: entry.session,
    photo: entry.photo!,
    fit: fit,
  );
}

void _openAlbumEntryViewer(BuildContext context, AlbumPhotoEntry entry) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PhotoViewerScreen(
        session: entry.session,
        photos: entry.sessionPhotos,
        initialIndex: entry.isIndexSheet
            ? -1
            : entry.sessionPhotos.indexWhere(
                (photo) => photo.photoId == entry.photo!.photoId,
              ),
      ),
    ),
  );
}

class AlbumOverview {
  final List<AlbumSessionEntry> shootingFilmSessions;
  final List<AlbumSessionEntry> developingSessions;
  final List<AlbumSessionEntry> developedSessions;
  final List<AlbumPhotoEntry> recentFilmPhotos;
  final List<AlbumPhotoEntry> instantPhotos;
  final AlbumSessionEntry? activeInstantSession;

  const AlbumOverview({
    required this.shootingFilmSessions,
    required this.developingSessions,
    required this.developedSessions,
    required this.recentFilmPhotos,
    required this.instantPhotos,
    required this.activeInstantSession,
  });

  bool get isEmpty =>
      shootingFilmSessions.isEmpty &&
      developingSessions.isEmpty &&
      developedSessions.isEmpty &&
      recentFilmPhotos.isEmpty &&
      instantPhotos.isEmpty &&
      activeInstantSession == null;

  AlbumSessionEntry? get currentRoll =>
      shootingFilmSessions.isEmpty ? null : shootingFilmSessions.first;

  List<AlbumSessionEntry> get memorySessions {
    final sessions = developedSessions
        .where((entry) => entry.latestAiDraft != null)
        .toList();
    sessions.sort(
      (a, b) =>
          b.latestAiDraft!.updatedAt.compareTo(a.latestAiDraft!.updatedAt),
    );
    return sessions;
  }
}

final albumOverviewProvider = FutureProvider<AlbumOverview>((ref) async {
  await DatabaseHelper.ensureMockAlbumSeeded();
  final sessions = await DatabaseHelper.getAllFilmSessions();
  final shootingFilms = <AlbumSessionEntry>[];
  final developing = <AlbumSessionEntry>[];
  final developed = <AlbumSessionEntry>[];
  final recentFilmPhotos = <AlbumPhotoEntry>[];
  final instantPhotos = <AlbumPhotoEntry>[];
  AlbumSessionEntry? activeInstantSession;

  for (final session in sessions) {
    final photos = await DatabaseHelper.getPhotosForSession(session.sessionId);
    final latestAiDraft =
        await DatabaseHelper.getLatestAiLifelogDraftForSession(
      session.sessionId,
    );
    final entry = AlbumSessionEntry(
      session: session,
      photos: photos,
      latestAiDraft: latestAiDraft,
    );

    for (final photo in photos) {
      final albumEntry = AlbumPhotoEntry.photo(
        photo: photo,
        session: session,
        sessionPhotos: photos,
      );
      if (session.isInstantMode) {
        instantPhotos.add(albumEntry);
      } else {
        recentFilmPhotos.add(albumEntry);
      }
    }

    if (session.isFilmMode && session.indexSheetPath?.isNotEmpty == true) {
      recentFilmPhotos.add(
        AlbumPhotoEntry.indexSheet(
          session: session,
          sessionPhotos: photos,
          imagePath: session.indexSheetPath!,
          sortTimestamp: photos.isNotEmpty
              ? photos.last.timestamp.add(const Duration(seconds: 1))
              : session.date,
        ),
      );
    }

    if (session.isInstantMode) {
      if (session.status == FilmStatus.shooting) {
        activeInstantSession = entry;
      }
      continue;
    }

    switch (session.status) {
      case FilmStatus.shooting:
        shootingFilms.add(entry);
        break;
      case FilmStatus.shelved:
        break;
      case FilmStatus.developing:
        developing.add(entry);
        break;
      case FilmStatus.developed:
        developed.add(entry);
        break;
    }
  }

  recentFilmPhotos.sort(
    (a, b) => b.sortTimestamp.compareTo(a.sortTimestamp),
  );
  instantPhotos.sort(
    (a, b) => b.sortTimestamp.compareTo(a.sortTimestamp),
  );

  return AlbumOverview(
    shootingFilmSessions: shootingFilms,
    developingSessions: developing,
    developedSessions: developed,
    recentFilmPhotos: recentFilmPhotos,
    instantPhotos: instantPhotos,
    activeInstantSession: activeInstantSession,
  );
});

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 画面に戻るたびにアルバムを最新化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(albumOverviewProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(albumOverviewProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // アルバムタブ (index=1) に切り替わるたびにデータを再取得する
    ref.listen<int>(mainTabIndexProvider, (prev, next) {
      if (next == 1 && prev != 1) {
        ref.invalidate(albumOverviewProvider);
      }
    });
    final albumAsync = ref.watch(albumOverviewProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: albumAsync.when(
          data: (overview) => overview.isEmpty
              ? const _AlbumEmptyState()
              : _AlbumBody(
                  overview: overview,
                  onRefresh: () => ref.invalidate(albumOverviewProvider),
                ),
          loading: () => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white30,
                strokeWidth: 1.2,
              ),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'アルバムの読み込みに失敗しました\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumBody extends StatelessWidget {
  final AlbumOverview overview;
  final VoidCallback onRefresh;

  const _AlbumBody({
    required this.overview,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final featuredPhotos = [
      ...overview.recentFilmPhotos.take(8),
      ...overview.instantPhotos.take(8),
    ]..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
    final memorySessions = overview.memorySessions.take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ALBUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 5,
                  fontWeight: FontWeight.w200,
                ),
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white54,
              ),
              tooltip: 'アルバムを更新',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '最近の写真から、その日のロールやインスタントへ入れます。',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 13,
            height: 1.6,
          ),
        ),
        if (featuredPhotos.isNotEmpty) ...[
          const SizedBox(height: 18),
          _FeaturedAlbumMoments(entries: featuredPhotos.take(5).toList()),
        ],
        if (memorySessions.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: '思い出ノート',
            subtitle: 'ロールごとの空気やメモを、あとから読み返しやすく整理します。',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: memorySessions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _MemoryJournalCard(
                entry: memorySessions[index],
              ),
            ),
          ),
        ],
        // 1. 撮影中ロール（最優先）
        if (overview.currentRoll != null) ...[
          const SizedBox(height: 24),
          _CurrentRollCard(entry: overview.currentRoll!),
        ],
        // 2. 現像待ち（ロール完了直後に目立つ位置）
        if (overview.developingSessions.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: '現像待ち',
            subtitle: 'フィルムはすぐ開かず、時間を置いてから現像する。',
          ),
          const SizedBox(height: 12),
          ...overview.developingSessions.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DevelopingSessionCard(entry: entry),
            ),
          ),
        ],
        // 3. インスタント
        if (overview.activeInstantSession != null ||
            overview.instantPhotos.isNotEmpty) ...[
          const SizedBox(height: 28),
          _InstantSection(
            activeSession: overview.activeInstantSession,
            photos: overview.instantPhotos,
          ),
        ],
        // 4. フィルムの最新カット
        if (overview.recentFilmPhotos.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: 'フィルムの最新カット',
            subtitle: 'ロールの外から、直近のカットを素早く見返す。',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: overview.recentFilmPhotos.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = overview.recentFilmPhotos[index];
                return _RecentPhotoCard(entry: entry);
              },
            ),
          ),
        ],
        // 5. フィルムアーカイブ
        if (overview.developedSessions.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(
            title: 'フィルムアーカイブ',
            subtitle: '現像済みロールを、その場所とテーマごとに保管する。',
          ),
          const SizedBox(height: 12),
          ...overview.developedSessions.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ArchiveSessionCard(entry: entry),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedAlbumMoments extends StatelessWidget {
  final List<AlbumPhotoEntry> entries;

  const _FeaturedAlbumMoments({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final hero = entries.first;
    final sideEntries = entries.skip(1).take(2).toList();
    final footerEntries = entries.skip(3).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: '最近の写真',
          subtitle: 'タップすると、そのロールやインスタントの流れをそのまま見返せます。',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: _FeaturedPhotoTile(
                  entry: hero,
                  showMeta: true,
                ),
              ),
              if (sideEntries.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      for (int i = 0; i < sideEntries.length; i++) ...[
                        Expanded(
                          child: _FeaturedPhotoTile(
                            entry: sideEntries[i],
                            compact: true,
                          ),
                        ),
                        if (i != sideEntries.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (footerEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: footerEntries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => AspectRatio(
                aspectRatio: 1.4,
                child: _FeaturedPhotoTile(
                  entry: footerEntries[index],
                  compact: true,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedPhotoTile extends StatelessWidget {
  final AlbumPhotoEntry entry;
  final bool showMeta;
  final bool compact;

  const _FeaturedPhotoTile({
    required this.entry,
    this.showMeta = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = entry.isIndexSheet
        ? 'INDEX SHEET'
        : entry.photo?.subject?.trim().isNotEmpty == true
            ? entry.photo!.subject!
            : entry.session.title;

    return GestureDetector(
      onTap: () => _openAlbumEntryViewer(context, entry),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _albumEntryWidget(entry: entry),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.56),
                  ],
                ),
              ),
            ),
            if (entry.isIndexSheet)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Text(
                    'INDEX',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: compact ? 10 : 14,
              right: compact ? 10 : 14,
              bottom: compact ? 10 : 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 12 : 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (showMeta || !compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.session.locationName ?? entry.session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: compact ? 10 : 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryJournalCard extends StatelessWidget {
  final AlbumSessionEntry entry;

  const _MemoryJournalCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final draft = entry.latestAiDraft;
    if (draft == null) return const SizedBox.shrink();

    final summary = _memorySummaryText(draft);

    return SizedBox(
      width: 260,
      child: GestureDetector(
        onTap: () => _openJournalScreen(
          context,
          entry.session,
          entry.photos,
          startWithAiAssist: false,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF181716),
                Color(0xFF101010),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'MEMORY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatShortDate(draft.updatedAt),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                draft.title?.trim().isNotEmpty == true
                    ? draft.title!
                    : entry.session.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  height: 1.25,
                ),
              ),
              if (draft.subtitle?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  draft.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${entry.photos.length} 枚 · ${entry.session.locationName ?? entry.session.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumEmptyState extends StatelessWidget {
  const _AlbumEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Colors.white24,
                size: 36,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'まだ現像するフィルムがありません',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ロールをつくって撮り始めると、\nここに一日の思い出が整理されていきます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  DarkFadeRoute(page: const CheckInScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              child: const Text(
                '今日のロールをつくる',
                style: TextStyle(letterSpacing: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.44),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InstantSection extends ConsumerWidget {
  final AlbumSessionEntry? activeSession;
  final List<AlbumPhotoEntry> photos;

  const _InstantSection({
    required this.activeSession,
    required this.photos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewPhotos = photos.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'インスタント',
          subtitle: 'iPhone の写真やデジカメみたいに、撮った順で気軽に見返す。',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeSession != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'INSTANT READY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      enforceAnalogExperienceRules
                          ? 'BATTERY ${activeSession!.session.instantBatteryRemaining}%'
                          : '${activeSession!.photos.length} cuts',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                activeSession?.session.title ?? 'INSTANT LIBRARY',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                photos.isEmpty
                    ? 'まだインスタントの写真はありません。撮るとここへ普通のアルバムのように並びます。'
                    : '${photos.length} 枚を新しい順に並べています。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: previewPhotos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final entry = previewPhotos[index];
                    return _InstantPhotoTile(entry: entry);
                  },
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: activeSession == null
                          ? null
                          : () {
                              ref.read(mainTabIndexProvider.notifier).state = 0;
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'インスタントで撮る',
                        style: TextStyle(letterSpacing: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: photos.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _InstantAlbumScreen(
                                    photos: photos,
                                  ),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        '一覧で見る',
                        style: TextStyle(letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentRollCard extends ConsumerWidget {
  final AlbumSessionEntry entry;

  const _CurrentRollCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = FilmSession.maxPhotos - entry.session.remainingShots;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF181818),
            Color(0xFF0E0E0E),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.session.isFilmMode ? 'TODAY\'S ROLL' : 'INSTANT RECORD',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                entry.session.isFilmMode
                    ? '${entry.session.remainingShots.toString().padLeft(2, '0')} LEFT'
                    : enforceAnalogExperienceRules
                        ? 'BATTERY ${entry.session.instantBatteryRemaining}%'
                        : '${entry.session.photoCount} cuts',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            entry.session.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (entry.session.locationName?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              entry.session.locationName!,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ],
          if (entry.session.theme?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _ThemePill(theme: entry.session.theme!),
          ],
          if (entry.session.memo?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                entry.session.memo!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (entry.session.isFilmMode)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: used / FilmSession.maxPhotos,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            )
          else
            Text(
              enforceAnalogExperienceRules
                  ? 'インスタントは電池で動きます。残り ${entry.session.instantBatteryRemaining}% です。'
                  : 'インスタントで残したカットです。この訪問の思い出をすぐ見返せます。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 14),
          if (entry.photos.isEmpty)
            Text(
              'まだ何も写っていません。最初の1枚が、このロールの空気を決めます。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 12,
                height: 1.5,
              ),
            )
          else
            SizedBox(
              height: 76,
              child: Row(
                children: entry.photos.reversed.take(4).toList().reversed.map((
                  photo,
                ) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      child: _albumPhotoWidget(
                        session: entry.session,
                        photo: photo,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(mainTabIndexProvider.notifier).state = 0;
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    '撮影を再開',
                    style: TextStyle(letterSpacing: 1.4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _AlbumSessionDetailScreen(entry: entry),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'ロールを見る',
                    style: TextStyle(letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevelopingSessionCard extends StatelessWidget {
  final AlbumSessionEntry entry;

  const _DevelopingSessionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final readyAt = entry.session.developReadyAt;
    final isReady = entry.session.isDevelopReady;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          DarkFadeRoute(
            page: DevelopScreen(sessionId: entry.session.sessionId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: StreamBuilder<int>(
                stream: Stream<int>.periodic(
                  const Duration(seconds: 1),
                  (count) => count,
                ),
                builder: (context, _) {
                  final now = DateTime.now();
                  final remaining = readyAt?.difference(now);
                  final timerLabel = remaining == null || remaining.isNegative
                      ? null
                      : _formatDevelopCountdown(remaining);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.session.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${entry.photos.length} 枚 · ${_formatDate(entry.session.date)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isReady
                            ? '1時間が経ちました。タップで現像を始められます。'
                            : readyAt == null
                                ? 'まだ暗室で休ませています。Proなら待ち時間をスキップできます。'
                                : '撮影したフィルムは1時間後に見ることができます。現像開始: ${_formatReadyTime(readyAt)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      if (timerLabel != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            'あと $timerLabel',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            StreamBuilder<int>(
              stream: Stream<int>.periodic(
                const Duration(seconds: 1),
                (count) => count,
              ),
              builder: (context, _) {
                final badgeLabel = isReady
                    ? '現像する'
                    : readyAt == null
                        ? '現像待ち / PRO'
                        : _formatDevelopCountdown(
                            readyAt.difference(DateTime.now()),
                          );
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isReady
                            ? Colors.white
                            : const Color(0xFFB22222).withValues(alpha: 0.12))
                        .withValues(alpha: isReady ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: isReady ? Colors.white : const Color(0xFFE57373),
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPhotoCard extends StatelessWidget {
  final AlbumPhotoEntry entry;

  const _RecentPhotoCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAlbumEntryViewer(context, entry),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _albumEntryWidget(entry: entry),
                    if (entry.isIndexSheet)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.46),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'INDEX',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.isIndexSheet
                  ? 'INDEX SHEET'
                  : entry.photo?.subject?.trim().isNotEmpty == true
                      ? entry.photo!.subject!
                      : entry.session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatShortDate(entry.sortTimestamp),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstantPhotoTile extends StatelessWidget {
  final AlbumPhotoEntry entry;

  const _InstantPhotoTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAlbumEntryViewer(context, entry),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _albumEntryWidget(entry: entry),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.isIndexSheet
                      ? 'INDEX SHEET'
                      : _formatShortDate(entry.sortTimestamp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexGridTile extends StatelessWidget {
  final File file;

  const _IndexGridTile({required this.file});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const MockPhotoView(fit: BoxFit.cover),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'INDEX',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstantAlbumScreen extends StatelessWidget {
  final List<AlbumPhotoEntry> photos;

  const _InstantAlbumScreen({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'INSTANT',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) =>
            _InstantPhotoTile(entry: photos[index]),
      ),
    );
  }
}

class _ArchiveSessionCard extends StatelessWidget {
  final AlbumSessionEntry entry;

  const _ArchiveSessionCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final draft = entry.latestAiDraft;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _AlbumSessionDetailScreen(entry: entry),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  Expanded(
                    child: _SessionPreviewTile(
                      session: entry.session,
                      photo: entry.coverPhoto,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _SessionPreviewTile(
                            session: entry.session,
                            photo: entry.photos.length > 1
                                ? entry.photos[entry.photos.length - 2]
                                : entry.coverPhoto,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _SessionPreviewTile(
                            session: entry.session,
                            photo: entry.photos.length > 2
                                ? entry.photos[entry.photos.length - 3]
                                : entry.coverPhoto,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w300,
              ),
            ),
            if (entry.session.theme?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _ThemePill(theme: entry.session.theme!),
            ],
            if (entry.session.locationName?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                entry.session.locationName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
            if (draft != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '思い出ノート',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _memorySummaryText(draft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.photos.length} 枚 · ${_formatDate(entry.session.date)}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (entry.session.indexSheetPath?.isNotEmpty == true) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'INDEX',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
                if (draft != null) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEE3CE).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'NOTE',
                      style: TextStyle(
                        color: Color(0xFFF1D8AF),
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionPreviewTile extends StatelessWidget {
  final FilmSession session;
  final Photo? photo;

  const _SessionPreviewTile({
    required this.session,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.white24,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _albumPhotoWidget(session: session, photo: photo!),
    );
  }
}

class _AlbumSessionDetailScreen extends ConsumerWidget {
  final AlbumSessionEntry entry;

  const _AlbumSessionDetailScreen({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiSettings = ref.watch(aiMemoryAssistSettingsProvider);
    final canUseAiAssist = aiSettings.enabled &&
        entry.session.isFilmMode &&
        entry.session.status == FilmStatus.developed &&
        entry.photos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          entry.session.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _saveSessionToPhotoLibrary(context, entry),
            icon: const Icon(Icons.save_alt_rounded),
            tooltip: 'iPhoneの写真へ保存',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(label: '${entry.photos.length} 枚'),
                      _DetailChip(label: _statusLabel(entry.session.status)),
                      _DetailChip(label: _formatDate(entry.session.date)),
                      if (entry.session.theme?.isNotEmpty == true)
                        _DetailChip(label: 'THEME ${entry.session.theme!}'),
                    ],
                  ),
                  if (entry.session.locationName?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      entry.session.locationName!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (entry.session.memo?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      entry.session.memo!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                  if (entry.coverPhoto != null) ...[
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 1.48,
                        child: _albumPhotoWidget(
                          session: entry.session,
                          photo: entry.coverPhoto!,
                        ),
                      ),
                    ),
                  ],
                  if (entry.session.indexSheetPath?.isNotEmpty == true) ...[
                    const SizedBox(height: 18),
                    _IndexSheetPreview(path: entry.session.indexSheetPath!),
                  ] else if (entry.session.isFilmMode &&
                      entry.session.isFull &&
                      entry.photos.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _IndexSheetAutoPreview(
                      session: entry.session,
                      photos: entry.photos,
                    ),
                  ],
                  if (entry.latestAiDraft != null || canUseAiAssist) ...[
                    const SizedBox(height: 18),
                    _SessionMemoryPanel(
                      entry: entry,
                      canUseAiAssist: canUseAiAssist,
                    ),
                  ],
                  if (entry.photos.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PhotoViewerScreen(
                                    session: entry.session,
                                    photos: entry.photos,
                                    initialIndex: entry.photos.length - 1,
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '1枚ずつ見る',
                              style: TextStyle(letterSpacing: 1.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _saveSessionToPhotoLibrary(context, entry),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '写真アプリへ保存',
                              style: TextStyle(letterSpacing: 1.1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _openJournalScreen(
                          context,
                          entry.session,
                          entry.photos,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'このロールのメモを編集',
                          style: TextStyle(letterSpacing: 1.4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final hasIndexSheet =
                    entry.session.indexSheetPath?.isNotEmpty == true;
                if (hasIndexSheet && index == 0) {
                  final indexPath = entry.session.indexSheetPath!;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PhotoViewerScreen(
                            session: entry.session,
                            photos: entry.photos,
                            initialIndex: -1,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _IndexGridTile(file: File(indexPath)),
                    ),
                  );
                }

                final photo = entry.photos[index - (hasIndexSheet ? 1 : 0)];

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(
                          session: entry.session,
                          photos: entry.photos,
                          initialIndex: index - (hasIndexSheet ? 1 : 0),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _albumPhotoWidget(
                      session: entry.session,
                      photo: photo,
                    ),
                  ),
                );
              },
                  childCount: entry.photos.length +
                      ((entry.session.indexSheetPath?.isNotEmpty == true)
                          ? 1
                          : 0)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionMemoryPanel extends StatelessWidget {
  final AlbumSessionEntry entry;
  final bool canUseAiAssist;

  const _SessionMemoryPanel({
    required this.entry,
    required this.canUseAiAssist,
  });

  @override
  Widget build(BuildContext context) {
    final draft = entry.latestAiDraft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121110),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI MEMORY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (draft != null)
                Text(
                  _formatShortDate(draft.updatedAt),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            draft?.title?.trim().isNotEmpty == true
                ? draft!.title!
                : 'このロールの思い出を整理する',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            draft != null
                ? _memorySummaryText(draft)
                : '現像した写真、場所、メモをもとに note に持っていきやすい下書きを作れます。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (draft?.hashtags.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              draft!.hashtags.take(4).join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF1D8AF),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: canUseAiAssist || draft != null
                      ? () => _openJournalScreen(
                            context,
                            entry.session,
                            entry.photos,
                            startWithAiAssist: draft == null,
                          )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    draft == null ? 'AIで整理する' : '思い出ノートを開く',
                    style: const TextStyle(letterSpacing: 1.2),
                  ),
                ),
              ),
              if (draft != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openJournalScreen(
                      context,
                      entry.session,
                      entry.photos,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      '編集する',
                      style: TextStyle(letterSpacing: 1.2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;

  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _statusLabel(FilmStatus status) {
  switch (status) {
    case FilmStatus.shooting:
      return '撮影中';
    case FilmStatus.shelved:
      return '退避中';
    case FilmStatus.developing:
      return '現像中';
    case FilmStatus.developed:
      return '現像済み';
  }
}

void _openJournalScreen(
  BuildContext context,
  FilmSession session,
  List<Photo> photos, {
  int initialIndex = 0,
  bool startWithAiAssist = false,
}) {
  if (photos.isEmpty) return;
  Navigator.of(context).push(
    DarkFadeRoute(
      page: JournalScreen(
        sessionId: session.sessionId,
        photos: photos,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        startWithAiAssist: startWithAiAssist,
      ),
    ),
  );
}

String _memorySummaryText(AiLifelogDraft draft) {
  final candidates = [
    draft.intro,
    draft.socialSummary,
    draft.bodyPlainText,
    draft.bodyMarkdown,
  ];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed.replaceAll('\n', ' ');
    }
  }
  return 'このロールの記録がまだありません。';
}

Future<void> _saveSessionToPhotoLibrary(
  BuildContext context,
  AlbumSessionEntry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  try {
    var indexSheetPath = entry.session.indexSheetPath;
    if ((indexSheetPath?.isNotEmpty != true) &&
        entry.session.isFilmMode &&
        entry.session.isFull &&
        entry.photos.isNotEmpty) {
      indexSheetPath = await ContactSheetService.generate(
        session: entry.session,
        photos: entry.photos,
        format: ContactSheetFormat.indexSheet,
        persist: true,
      );
      await DatabaseHelper.updateFilmSession(
        entry.session.copyWith(indexSheetPath: indexSheetPath),
      );
    }

    final paths = <String>[
      ...entry.photos.map((photo) => photo.imagePath),
      if (indexSheetPath?.isNotEmpty == true) indexSheetPath!,
    ];
    final savedCount = await PhotoLibraryService.saveImages(paths);
    messenger.showSnackBar(
      SnackBar(
        content: Text('$savedCount 枚をiPhoneの写真へ保存しました'),
      ),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('保存に失敗しました: $error'),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String theme;

  const _ThemePill({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'THEME $theme',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _IndexSheetPreview extends StatelessWidget {
  final String path;

  const _IndexSheetPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INDEX SHEET',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.48,
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : const MockPhotoView(fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}

class _IndexSheetAutoPreview extends StatefulWidget {
  final FilmSession session;
  final List<Photo> photos;

  const _IndexSheetAutoPreview({
    required this.session,
    required this.photos,
  });

  @override
  State<_IndexSheetAutoPreview> createState() => _IndexSheetAutoPreviewState();
}

class _IndexSheetAutoPreviewState extends State<_IndexSheetAutoPreview> {
  String? _path;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _path = widget.session.indexSheetPath;
    if ((_path?.isNotEmpty != true) && widget.photos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureIndexSheet();
      });
    }
  }

  Future<void> _ensureIndexSheet() async {
    if (_isGenerating || _path?.isNotEmpty == true) return;
    setState(() => _isGenerating = true);
    try {
      final path = await ContactSheetService.generate(
        session: widget.session,
        photos: widget.photos,
        format: ContactSheetFormat.indexSheet,
        persist: true,
      );
      await DatabaseHelper.updateFilmSession(
        widget.session.copyWith(indexSheetPath: path),
      );
      if (!mounted) return;
      setState(() => _path = path);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path?.isNotEmpty == true) {
      return _IndexSheetPreview(path: path!);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'INDEX SHEET を準備しています。',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    color: Colors.white54,
                  ),
                )
              : IconButton(
                  onPressed: _ensureIndexSheet,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

String _formatShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month.$day';
}

String _formatReadyTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String _formatDevelopCountdown(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
