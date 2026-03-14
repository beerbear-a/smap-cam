import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/models/species.dart';
import '../../core/utils/routes.dart';
import '../checkin/checkin_screen.dart';

// ── Data classes ─────────────────────────────────────────────

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

class ZukanData {
  final List<AnimalEntry> met;
  final List<Species> allSpecies;
  final Set<String> metSpeciesIds; // 出会い済み species_id

  const ZukanData({
    required this.met,
    required this.allSpecies,
    required this.metSpeciesIds,
  });

  int get totalSpecies => allSpecies.length;
  int get metCount => metSpeciesIds.length;
  double get completionRate =>
      totalSpecies == 0 ? 0 : metCount / totalSpecies;

  List<Species> get unmet =>
      allSpecies.where((s) => !metSpeciesIds.contains(s.speciesId)).toList();
}

// ── Provider ─────────────────────────────────────────────────

final zukanProvider = FutureProvider<ZukanData>((ref) async {
  // 写真ベースの出会いリスト（フォトタグ = subject テキスト）
  final sessions = await DatabaseHelper.getAllFilmSessions();
  final developedSessions = sessions.where((s) => s.isDeveloped).toList();

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

  final metEntries = bySubject.entries.map((e) {
    final photos = e.value.photos
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return AnimalEntry(
      subject: e.key,
      photos: photos,
      sessions: e.value.sessions,
    );
  }).toList()
    ..sort((a, b) => a.subject.compareTo(b.subject));

  // 種マスターを取得（コンプリート率用）
  final allSpecies = await DatabaseHelper.getAllSpecies();

  // encounters テーブルから出会い済み species_id を取得
  final encounterSummary = await DatabaseHelper.getEncounterSummary();
  final metSpeciesIds =
      encounterSummary.map((r) => r['species_id'] as String).toSet();

  return ZukanData(
    met: metEntries,
    allSpecies: allSpecies,
    metSpeciesIds: metSpeciesIds,
  );
});

// ── Screen ───────────────────────────────────────────────────

class ZukanScreen extends ConsumerStatefulWidget {
  const ZukanScreen({super.key});

  @override
  ConsumerState<ZukanScreen> createState() => _ZukanScreenState();
}

class _ZukanScreenState extends ConsumerState<ZukanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(zukanProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
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
                  const SizedBox(width: 16),
                  dataAsync.when(
                    data: (data) => _CompletionBadge(data: data),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // タブバー
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 1,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: '出会い済み'),
                Tab(text: '未発見'),
              ],
            ),

            // コンテンツ
            Expanded(
              child: dataAsync.when(
                data: (data) => TabBarView(
                  controller: _tabController,
                  children: [
                    // タブ1: 出会い済み
                    data.met.isEmpty
                        ? _EmptyState()
                        : _AnimalGrid(entries: data.met),

                    // タブ2: 未発見
                    _UndiscoveredList(species: data.unmet),
                  ],
                ),
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

// ── コンプリートバッジ ────────────────────────────────────────

class _CompletionBadge extends StatelessWidget {
  final ZukanData data;

  const _CompletionBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = (data.completionRate * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.metCount} / ${data.totalSpecies} 種',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(
            value: data.completionRate,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white54),
            minHeight: 2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$pct%',
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ── 未発見リスト ─────────────────────────────────────────────

class _UndiscoveredList extends StatelessWidget {
  final List<Species> species;

  const _UndiscoveredList({required this.species});

  @override
  Widget build(BuildContext context) {
    if (species.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🎉',
              style: TextStyle(fontSize: 48),
            ),
            SizedBox(height: 16),
            Text(
              'すべての動物に出会いました！',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: species.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white08, height: 1),
      itemBuilder: (context, index) {
        final sp = species[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: _RarityIcon(rarity: sp.rarity),
          title: Text(
            sp.nameJa,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
          ),
          subtitle: Text(
            sp.nameEn,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          trailing: _RarityStars(rarity: sp.rarity),
        );
      },
    );
  }
}

class _RarityIcon extends StatelessWidget {
  final int rarity;

  const _RarityIcon({required this.rarity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text('?', style: TextStyle(color: Colors.white24, fontSize: 18)),
      ),
    );
  }
}

class _RarityStars extends StatelessWidget {
  final int rarity;

  const _RarityStars({required this.rarity});

  Color get _color {
    switch (rarity) {
      case 4:
        return Colors.amber;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.white60;
      default:
        return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        rarity,
        (_) => Icon(Icons.star, size: 10, color: _color),
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
                style: TextStyle(letterSpacing: 2, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostAnimalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path();

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
                        child: Text('🦎', style: TextStyle(fontSize: 40)),
                      ),
                    ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _StatChip(label: '出会い', value: '${entry.encounterCount}'),
                  const SizedBox(width: 12),
                  _StatChip(label: '施設', value: '${entry.sessions.length}'),
                ],
              ),
            ),
          ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
