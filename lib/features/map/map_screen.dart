import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
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
          textColor: Colors.white.value,
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
    final photos =
        await DatabaseHelper.getPhotosForSession(session.sessionId);
    if (mounted) {
      _showSessionDetail(context, session, photos);
    }
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
                      const Text(
                        'ZootoCam',
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
                      IconButton(
                        onPressed: () => _showSessionList(context),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 新規フィルムボタン（チェックイン → フィルム作成）
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
          '動物園へ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  void _showSessionList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      builder: (ctx) => _SessionListSheet(
        onSessionTap: (session) async {
          Navigator.pop(ctx);
          final photos =
              await DatabaseHelper.getPhotosForSession(session.sessionId);
          if (mounted) {
            _showSessionDetail(context, session, photos);
          }
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '思い出',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 3,
                ),
              ),
            ),
            ...sessions.map(
              (s) => ListTile(
                onTap: () => onSessionTap(s),
                title: Text(
                  s.title,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${s.photoCount} 枚 · ${s.status.name}',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
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

            if (widget.session.memo != null &&
                widget.session.memo!.isNotEmpty)
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isGeneratingSheet ? null : _exportContactSheet,
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
                      : const Icon(Icons.film_filter_outlined, size: 18),
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
