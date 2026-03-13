import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/photo.dart';
import '../map/map_screen.dart';
import '../share/share_service.dart';

class JournalScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final List<Photo> photos;

  const JournalScreen({
    super.key,
    required this.sessionId,
    required this.photos,
  });

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late List<_JournalEntry> _entries;
  final _sessionMemoController = TextEditingController();
  bool _isSaving = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _entries = widget.photos
        .map((p) => _JournalEntry(
              photo: p,
              subjectController: TextEditingController(text: p.subject ?? ''),
              memoController: TextEditingController(text: p.memo ?? ''),
            ))
        .toList();
  }

  @override
  void dispose() {
    _sessionMemoController.dispose();
    for (final e in _entries) {
      e.subjectController.dispose();
      e.memoController.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    for (final entry in _entries) {
      await DatabaseHelper.updatePhotoJournal(
        entry.photo.photoId,
        entry.subjectController.text.trim().isEmpty
            ? null
            : entry.subjectController.text.trim(),
        entry.memoController.text.trim().isEmpty
            ? null
            : entry.memoController.text.trim(),
      );
    }
    if (_sessionMemoController.text.trim().isNotEmpty) {
      final session =
          await DatabaseHelper.getFilmSession(widget.sessionId);
      if (session != null) {
        await DatabaseHelper.updateFilmSession(
          session.copyWith(memo: _sessionMemoController.text.trim()),
        );
      }
    }
    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MapScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entries[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${_entries.length}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text(
              '完了',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 写真
          SizedBox(
            height: 240,
            child: PageView.builder(
              itemCount: _entries.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final p = _entries[index].photo;
                final file = File(p.imagePath);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white24,
                          ),
                        ),
                );
              },
            ),
          ),

          // フォーム
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '動物',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: entry.subjectController,
                    hint: 'レッサーパンダ',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'メモ',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: entry.memoController,
                    hint: '木の上で寝ていた',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  // シェアボタン
                  if (_currentIndex < _entries.length)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final e = _entries[_currentIndex];
                        await ShareService.sharePhoto(
                          photo: e.photo.copyWith(
                            subject: e.subjectController.text,
                            memo: e.memoController.text,
                          ),
                          session: await DatabaseHelper.getFilmSession(
                            widget.sessionId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('この写真をシェア'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 16),
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
    );
  }
}

class _JournalEntry {
  final Photo photo;
  final TextEditingController subjectController;
  final TextEditingController memoController;

  _JournalEntry({
    required this.photo,
    required this.subjectController,
    required this.memoController,
  });
}
