import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/utils/routes.dart';
import '../checkin/checkin_screen.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // シルエット演出: 薄い動物のアイコン
            CustomPaint(
              size: const Size(80, 80),
              painter: _GhostAnimalPainter(),
            ),
            const SizedBox(height: 32),
            const Text(
              'まだ出会いがありません',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '動物園へ行ってシャッターを切ってみよう',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white24,
                fontSize: 13,
                height: 1.8,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 36),
            OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  DarkFadeRoute(page: const CheckInScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'チェックインする',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ゴーストシルエット: 汎用動物の輪郭を薄白で描く（Reiスタイル）
class _GhostAnimalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path();

    // 汎用4足動物シルエット（フォールバックと同じ構造）
    path.addOval(Rect.fromLTWH(w * 0.18, h * 0.35, w * 0.50, h * 0.32));
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.76, h * 0.30),
      width: w * 0.28,
      height: w * 0.26,
    ));
    path.addRect(Rect.fromLTWH(w * 0.62, h * 0.32, w * 0.12, h * 0.16));
    for (final dx in [0.22, 0.36, 0.50, 0.62]) {
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * dx, h * 0.64, w * 0.08, h * 0.22),
        const Radius.circular(3),
      ));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GhostAnimalPainter old) => false;
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
