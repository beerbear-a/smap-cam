import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/models/zoo.dart';
import '../../core/utils/routes.dart';
import '../checkin/checkin_screen.dart';
import '../settings/settings_screen.dart';
import '../share/contact_sheet_service.dart';
import '../share/share_service.dart';
import 'map_notifier.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  final Map<String, FilmSession> _annotationSessionMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).loadSessions();
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _addSessionAnnotations();
  }

  Future<void> _addSessionAnnotations() async {
    final sessionsAsync = ref.read(mapProvider);
    sessionsAsync.whenData((sessions) async {
      if (_mapboxMap == null) return;

      _annotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();

      for (final session in sessions) {
        if (session.lat == null || session.lng == null) continue;

        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(session.lng!, session.lat!),
          ),
          iconSize: 1.5,
          textField: '● ${session.title}',
          textSize: 12,
          textColor: Colors.white.toARGB32(),
          textOffset: [0, 1.5],
        );
        final annotation = await _annotationManager!.create(options);
        _annotationSessionMap[annotation.id] = session;
      }

      _annotationManager!.addOnPointAnnotationClickListener(
        _AnnotationClickListener(onTap: _onPinTapped),
      );
    });
  }

  Future<void> _onPinTapped(PointAnnotation annotation) async {
    final session = _annotationSessionMap[annotation.id];
    if (session == null) return;
    final photos = await DatabaseHelper.getPhotosForSession(session.sessionId);
    final zoo = session.zooId == null
        ? null
        : await DatabaseHelper.getZoo(session.zooId!);
    final highlights = session.zooId == null
        ? const <Map<String, dynamic>>[]
        : await DatabaseHelper.getZooEncounterHighlights(session.zooId!);
    final zooSessions = session.zooId == null
        ? <FilmSession>[session]
        : await DatabaseHelper.getFilmSessionsForZoo(session.zooId!);
    if (!mounted) return;
    _showZooStorySheet(
      context,
      session: session,
      photos: photos,
      zoo: zoo,
      highlights: highlights,
      zooSessions: zooSessions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mapbox地図
          MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(139.7671, 35.6812), // 東京
              ),
              zoom: 10,
            ),
          ),

          // UI オーバーレイ
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MAP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 8),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '現像したロールを地図でたどる',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _showSessionList(context),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                        ),
                        tooltip: '訪問したロールを見る',
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final sessionsAsync = ref.watch(mapProvider);
                    return sessionsAsync.when(
                      data: (sessions) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            sessions.isEmpty
                                ? 'まだ地図に残るロールがありません'
                                : '${sessions.length} 本のロールが地図に残っています',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      // 新規フィルムボタン（ロール作成）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            DarkFadeRoute(page: const CheckInScreen()),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          '撮影を始める',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  void _showZooStorySheet(
    BuildContext context, {
    required FilmSession session,
    required List<Photo> photos,
    required Zoo? zoo,
    required List<Map<String, dynamic>> highlights,
    required List<FilmSession> zooSessions,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[950],
      builder: (ctx) => _ZooStorySheet(
        session: session,
        photos: photos,
        zoo: zoo,
        highlights: highlights,
        zooSessions: zooSessions,
        onOpenSession: (selected) async {
          Navigator.pop(ctx);
          final selectedPhotos =
              await DatabaseHelper.getPhotosForSession(selected.sessionId);
          if (!context.mounted) return;
          _showSessionDetail(context, selected, selectedPhotos);
        },
      ),
    );
  }

  void _showSessionList(BuildContext context) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      builder: (ctx) => _SessionListSheet(
        onSessionTap: (session) async {
          Navigator.pop(ctx);
          final photos =
              await DatabaseHelper.getPhotosForSession(session.sessionId);
          if (!parentContext.mounted) return;
          _showSessionDetail(parentContext, session, photos);
        },
      ),
    );
  }

  void _showSessionDetail(
    BuildContext context,
    FilmSession session,
    List<Photo> photos,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[950],
      builder: (ctx) => _SessionDetailSheet(
        session: session,
        photos: photos,
      ),
    );
  }
}

// ── Mapbox アノテーションクリックリスナー ─────────────────────

class _AnnotationClickListener extends OnPointAnnotationClickListener {
  final void Function(PointAnnotation) onTap;

  _AnnotationClickListener({required this.onTap});

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    onTap(annotation);
  }
}

// ── セッション一覧シート ──────────────────────────────────────

class _SessionListSheet extends ConsumerWidget {
  final void Function(FilmSession) onSessionTap;

  const _SessionListSheet({required this.onSessionTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<FilmSession>>(
      future: DatabaseHelper.getAllFilmSessions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snap.data ?? [];
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '訪問したロール',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Expanded(
                  child: sessions.isEmpty
                      ? const Center(
                          child: Text(
                            'まだ地図に残るロールがありません',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              letterSpacing: 1.5,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final s = sessions[index];
                            return ListTile(
                              onTap: () => onSessionTap(s),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${s.photoCount} 枚 · ${_mapStatusLabel(s.status)}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZooStorySheet extends StatelessWidget {
  final FilmSession session;
  final List<Photo> photos;
  final Zoo? zoo;
  final List<Map<String, dynamic>> highlights;
  final List<FilmSession> zooSessions;
  final Future<void> Function(FilmSession session) onOpenSession;

  const _ZooStorySheet({
    required this.session,
    required this.photos,
    required this.zoo,
    required this.highlights,
    required this.zooSessions,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final title = zoo?.name ?? session.locationName ?? session.title;
    final subtitle = [
      if (zoo != null) zoo!.prefecture,
      '${zooSessions.length} 本のロール',
    ].join(' · ');

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'この場所で出会った動物',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    highlights.isEmpty
                        ? 'まだ動物タグはありませんが、ロールは地図に残っています。'
                        : '地図から見返すと、その場所で会った動物のまとまりが立ち上がります。',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: highlights.take(8).map((highlight) {
                        return _SpeciesHighlightChip(highlight: highlight);
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'この場所のロール',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            ...zooSessions.take(6).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ZooSessionTile(
                      session: item,
                      selected: item.sessionId == session.sessionId,
                      onTap: () => onOpenSession(item),
                    ),
                  ),
                ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '最新のロールから',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length.clamp(0, 8),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final file = File(photo.imagePath);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 78,
                        child: file.existsSync()
                            ? Image.file(file, fit: BoxFit.cover)
                            : Container(
                                color: Colors.white10,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white24,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SpeciesHighlightChip extends StatelessWidget {
  final Map<String, dynamic> highlight;

  const _SpeciesHighlightChip({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final count = (highlight['encounter_count'] as int?) ?? 0;
    final rarity = (highlight['rarity'] as int?) ?? 1;
    final rarityLabel = switch (rarity) {
      4 => 'RARE',
      3 => 'UNCOMMON',
      2 => 'SEEN',
      _ => 'FOUND',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            highlight['name_ja'] as String? ?? '動物',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$count 回 · $rarityLabel',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZooSessionTile extends StatelessWidget {
  final FilmSession session;
  final bool selected;
  final VoidCallback onTap;

  const _ZooSessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_mapFormatDate(session.date)} · ${session.photoCount} 枚',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    if (session.theme?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        session.theme!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked : Icons.chevron_right,
                color: selected ? Colors.white70 : Colors.white30,
                size: selected ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── セッション詳細シート ──────────────────────────────────────

class _SessionDetailSheet extends ConsumerStatefulWidget {
  final FilmSession session;
  final List<Photo> photos;

  const _SessionDetailSheet({
    required this.session,
    required this.photos,
  });

  @override
  ConsumerState<_SessionDetailSheet> createState() =>
      _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<_SessionDetailSheet> {
  bool _isGeneratingSheet = false;

  Future<void> _exportContactSheet() async {
    setState(() => _isGeneratingSheet = true);
    try {
      final path = await ContactSheetService.generate(
        session: widget.session,
        photos: widget.photos,
      );
      await Share.shareXFiles(
        [XFile(path)],
        text:
            '📷 ${widget.session.locationName ?? widget.session.title}\n#ZOOSMAP',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('書き出しに失敗しました: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSheet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = ref.watch(usernameProvider);
    final watermarkPosition = ref.watch(watermarkPositionProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scroll) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ヘッダー ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                        if (widget.session.locationName != null)
                          Text(
                            widget.session.locationName!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 個別シェアボタン（透かし付き）
                  IconButton(
                    onPressed: () async {
                      await ShareService.shareSession(
                        session: widget.session,
                        photos: widget.photos,
                        username: username,
                        position: watermarkPosition,
                      );
                    },
                    icon: const Icon(Icons.share, color: Colors.white54),
                    tooltip: '写真をシェア',
                  ),
                ],
              ),
            ),

            if (widget.session.memo != null && widget.session.memo!.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  widget.session.memo!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),

            // ── フィルム書き出しボタン ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingSheet ? null : _exportContactSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isGeneratingSheet
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white38,
                          ),
                        )
                      : const Icon(Icons.photo_filter_outlined, size: 18),
                  label: Text(
                    _isGeneratingSheet ? '生成中...' : 'フィルムで書き出す',
                    style: const TextStyle(
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

            // ── 写真グリッド ───────────────────────────────
            Expanded(
              child: GridView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: widget.photos.length,
                itemBuilder: (context, index) {
                  final photo = widget.photos[index];
                  final file = File(photo.imagePath);
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
              ),
            ),
          ],
        );
      },
    );
  }
}

String _mapStatusLabel(FilmStatus status) {
  switch (status) {
    case FilmStatus.shooting:
      return '撮影中';
    case FilmStatus.shelved:
      return '退避中';
    case FilmStatus.developing:
      return '現像待ち';
    case FilmStatus.developed:
      return '現像済み';
  }
}

String _mapFormatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
