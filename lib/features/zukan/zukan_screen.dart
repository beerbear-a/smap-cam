import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';

// ── Data class ──────────────────────────────────────────────

class AnimalEntry {
  final String subject;
  final List<Photo> photos;
  final List<FilmSession> sessions;

  const AnimalEntry({
    required this.subject,
    required this.photos,
    required this.sessions,
  });

  int get encounterCount => photos.length;
  Photo get firstPhoto => photos.first;
}

// ── Provider ────────────────────────────────────────────────

final zukanProvider = FutureProvider<List<AnimalEntry>>((ref) async {
  final sessions = await DatabaseHelper.getAllFilmSessions();
  final developedSessions =
      sessions.where((s) => s.isDeveloped).toList();

  // subject → (photos, sessions)
  final Map<String, ({List<Photo> photos, List<FilmSession> sessions})>
      bySubject = {};

  for (final session in developedSessions) {
    final photos = await DatabaseHelper.getPhotosForSession(session.sessionId);
    for (final photo in photos) {
      final subj = (photo.subject ?? '').trim();
      if (subj.isEmpty) continue;
      if (!bySubject.containsKey(subj)) {
        bySubject[subj] = (photos: [], sessions: []);
      }
      bySubject[subj]!.photos.add(photo);
      if (!bySubject[subj]!
          .sessions
          .any((s) => s.sessionId == session.sessionId)) {
        bySubject[subj]!.sessions.add(session);
      }
    }
  }

  final entries = bySubject.entries.map((e) {
    final photos = e.value.photos
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return AnimalEntry(
      subject: e.key,
      photos: photos,
      sessions: e.value.sessions,
    );
  }).toList();

  entries.sort((a, b) => a.subject.compareTo(b.subject));
  return entries;
});

// ── Screen ──────────────────────────────────────────────────

class ZukanScreen extends ConsumerWidget {
  const ZukanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(zukanProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '図鑑',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 4,
                    ),
                  ),
                  entriesAsync.when(
                    data: (entries) => Text(
                      '${entries.length} 種類を記録',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // コンテンツ
            Expanded(
              child: entriesAsync.when(
                data: (entries) => entries.isEmpty
                    ? _EmptyState()
                    : _AnimalGrid(entries: entries),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white30,
                    strokeWidth: 1,
                  ),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'エラー: $err',
                    style: const TextStyle(color: Colors.white38),
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

// ── Empty state ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🦁',
            style: TextStyle(fontSize: 48),
          ),
          SizedBox(height: 24),
          Text(
            '図鑑がまだ空です',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '撮影後に動物名を記録すると\nここに表示されます',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white24,
              fontSize: 13,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid ────────────────────────────────────────────────────

class _AnimalGrid extends StatelessWidget {
  final List<AnimalEntry> entries;

  const _AnimalGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _AnimalCard(
          entry: entries[index],
          onTap: () => _showDetail(context, entries[index]),
        );
      },
    );
  }

  void _showDetail(BuildContext context, AnimalEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AnimalDetailScreen(entry: entry),
      ),
    );
  }
}

// ── Card ────────────────────────────────────────────────────

class _AnimalCard extends StatelessWidget {
  final AnimalEntry entry;
  final VoidCallback onTap;

  const _AnimalCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final file = File(entry.firstPhoto.imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[950],
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 写真
            Expanded(
              child: file.existsSync()
                  ? Image.file(
                      file,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Text(
                          '🦎',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
            ),

            // ラベル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.subject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.encounterCount} 枚 · ${entry.sessions.length} 施設',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Screen ────────────────────────────────────────────

class _AnimalDetailScreen extends ConsumerWidget {
  final AnimalEntry entry;

  const _AnimalDetailScreen({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          entry.subject,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // 統計バー
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _StatChip(
                    label: '出会い',
                    value: '${entry.encounterCount}',
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: '施設',
                    value: '${entry.sessions.length}',
                  ),
                ],
              ),
            ),
          ),

          // 施設リスト
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: const Text(
                '記録した場所',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final session = entry.sessions[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  title: Text(
                    session.locationName ?? session.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(session.date),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white24,
                    size: 16,
                  ),
                );
              },
              childCount: entry.sessions.length,
            ),
          ),

          // 写真グリッド
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: const Text(
                '写真',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = File(entry.photos[index].imagePath);
                  return file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white24,
                          ),
                        );
                },
                childCount: entry.photos.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
