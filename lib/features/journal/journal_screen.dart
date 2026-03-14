import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/photo.dart';
import '../../core/models/species.dart';
import '../../core/utils/routes.dart';
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

  // レアリティ4 遭遇演出
  bool _showRareOverlay = false;
  String? _rareSpeciesName;

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

    // 入力されたすべての subject を収集
    final subjectTexts = _entries
        .map((e) => e.subjectController.text.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    // レアリティ4チェック
    Species? rareFind;
    if (subjectTexts.isNotEmpty) {
      final allSpecies = await DatabaseHelper.getAllSpecies();
      final rarity4 =
          allSpecies.where((s) => s.rarity == 4).toList();
      for (final sp in rarity4) {
        if (subjectTexts.any((t) =>
            t.contains(sp.nameJa) || t.contains(sp.nameEn))) {
          rareFind = sp;
          break;
        }
      }
    }

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
      final session = await DatabaseHelper.getFilmSession(widget.sessionId);
      if (session != null) {
        await DatabaseHelper.updateFilmSession(
          session.copyWith(memo: _sessionMemoController.text.trim()),
        );
      }
    }

    setState(() => _isSaving = false);

    // レアリティ4演出
    if (rareFind != null && mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _showRareOverlay = true;
        _rareSpeciesName = rareFind!.nameJa;
      });
      // 演出後に自動遷移
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _navigateToMap();
      });
    } else if (mounted) {
      _navigateToMap();
    }
  }

  void _navigateToMap() {
    Navigator.of(context).pushAndRemoveUntil(
      DarkFadeRoute(page: const MapScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entries[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // メインコンテンツ
          Column(
            children: [
              AppBar(
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

          // ── レアリティ4 遭遇演出 ─────────────────────────
          if (_showRareOverlay)
            _RareEncounterOverlay(
              speciesName: _rareSpeciesName ?? '',
              onDismiss: _navigateToMap,
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
        fillColor: Colors.white.withValues(alpha: 0.05),
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

// ── レアリティ4 遭遇演出オーバーレイ ──────────────────────────

class _RareEncounterOverlay extends StatefulWidget {
  final String speciesName;
  final VoidCallback onDismiss;

  const _RareEncounterOverlay({
    required this.speciesName,
    required this.onDismiss,
  });

  @override
  State<_RareEncounterOverlay> createState() => _RareEncounterOverlayState();
}

class _RareEncounterOverlayState extends State<_RareEncounterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Opacity(
          opacity: _fadeIn.value,
          child: Container(
            color: Colors.black.withValues(alpha: 0.88),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 星アイコン群
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber.withValues(
                              alpha:
                                  (_controller.value > i * 0.15) ? 1.0 : 0.0,
                            ),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'LEGENDARY',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.speciesName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'に出会いました',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'タップして続ける',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
