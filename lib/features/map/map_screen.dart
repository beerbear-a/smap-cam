import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../camera/camera_screen.dart';
import '../camera/film_session_notifier.dart';
import '../share/share_service.dart';
import 'map_notifier.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;

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
      final annotationManager =
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
        await annotationManager.create(options);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(mapProvider);

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
                // ヘッダー
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
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      // セッション一覧ボタン
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

          // ピンタップ時のセッション一覧（下から）
          sessionsAsync.when(
            data: (sessions) => sessions.isEmpty
                ? const SizedBox.shrink()
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),

      // 新規フィルムボタン
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewFilmDialog(context),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
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

  void _showNewFilmDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[950],
      builder: (ctx) => _NewFilmSheet(
        onCreated: (session) {
          Navigator.pop(ctx);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
        },
      ),
    );
  }
}

// ── セッション一覧シート ──────────────────────────────────

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
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ── セッション詳細シート ──────────────────────────────────

class _SessionDetailSheet extends StatelessWidget {
  final FilmSession session;
  final List<Photo> photos;

  const _SessionDetailSheet({
    required this.session,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scroll) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                        ),
                      ),
                      if (session.locationName != null)
                        Text(
                          session.locationName!,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () async {
                      await ShareService.shareSession(
                        session: session,
                        photos: photos,
                      );
                    },
                    icon: const Icon(Icons.share, color: Colors.white54),
                  ),
                ],
              ),
            ),
            if (session.memo != null && session.memo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  session.memo!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            const SizedBox(height: 16),
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
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
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

// ── 新規フィルムシート ────────────────────────────────────

class _NewFilmSheet extends ConsumerStatefulWidget {
  final void Function(FilmSession) onCreated;

  const _NewFilmSheet({required this.onCreated});

  @override
  ConsumerState<_NewFilmSheet> createState() => _NewFilmSheetState();
}

class _NewFilmSheetState extends ConsumerState<_NewFilmSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isCreating = true);

    final session = await ref.read(filmSessionProvider.notifier).createSession(
          title: _titleController.text.trim(),
          locationName: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
        );

    widget.onCreated(session);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '新しいフィルム',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 3,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 24),
          _buildField(_titleController, 'タイトル', '上野動物園'),
          const SizedBox(height: 16),
          _buildField(_locationController, '場所 (任意)', '東京都台東区'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'フィルムを装填する',
                      style: TextStyle(fontSize: 16, letterSpacing: 2),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white38),
            ),
          ),
        ),
      ],
    );
  }
}
