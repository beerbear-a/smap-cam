import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/utils/routes.dart';
import '../camera/film_session_notifier.dart';
import '../journal/journal_screen.dart';

class DevelopScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const DevelopScreen({super.key, required this.sessionId});

  @override
  ConsumerState<DevelopScreen> createState() => _DevelopScreenState();
}

class _DevelopScreenState extends ConsumerState<DevelopScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _isDone = false;
  List<Photo> _photos = [];
  FilmSession? _session;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startDeveloping();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startDeveloping() async {
    // 現像演出: 3秒待機
    await Future.delayed(const Duration(seconds: 3));

    final session = await DatabaseHelper.getFilmSession(widget.sessionId);
    final photos = await DatabaseHelper.getPhotosForSession(widget.sessionId);

    // ステータスを developed に更新
    await ref.read(filmSessionProvider.notifier).markDeveloped(widget.sessionId);

    if (mounted) {
      setState(() {
        _session = session;
        _photos = photos;
        _isDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isDone ? _buildResult() : _buildDeveloping(),
    );
  }

  Widget _buildDeveloping() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _pulseAnim,
            child: const Text(
              '現像中...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w100,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 40),
          const SizedBox(
            width: 48,
            child: LinearProgressIndicator(
              color: Colors.white30,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 80),
          const Text(
            'フィルムを現像しています\nしばらくお待ちください',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white30,
              fontSize: 14,
              height: 2,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '現像完了',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 4,
                  ),
                ),
                if (_session?.title != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _session!.title,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                return _FilmPhoto(photo: _photos[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    DarkFadeRoute(
                      page: JournalScreen(
                        sessionId: widget.sessionId,
                        photos: _photos,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '観察日記を書く',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilmPhoto extends StatelessWidget {
  final Photo photo;

  const _FilmPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PhotoDetailScreen(photo: photo),
          ),
        );
      },
      child: file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : Container(
              color: Colors.grey[900],
              child: const Icon(Icons.image_not_supported, color: Colors.white24),
            ),
    );
  }
}

class _PhotoDetailScreen extends StatelessWidget {
  final Photo photo;

  const _PhotoDetailScreen({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(photo.imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
