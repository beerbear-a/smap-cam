import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/main_tab_provider.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/services/photo_library_service.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/mock_photo.dart';
import '../camera/widgets/film_preview.dart';
import '../camera/widgets/lut_selector.dart';
import '../journal/journal_screen.dart';

class _ViewerItem {
  final Photo? photo;
  final String imagePath;
  final bool isIndexSheet;

  _ViewerItem.photo(this.photo)
      : imagePath = photo!.imagePath,
        isIndexSheet = false;

  const _ViewerItem.index(this.imagePath)
      : photo = null,
        isIndexSheet = true;
}

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final FilmSession session;
  final List<Photo> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.session,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  late LutType _selectedLut;
  bool _isSavingToPhotos = false;

  bool get _canAdjustLook => widget.session.isInstantMode;
  List<_ViewerItem> get _items {
    final items = <_ViewerItem>[
      if (widget.session.isFilmMode &&
          widget.session.indexSheetPath?.isNotEmpty == true)
        _ViewerItem.index(widget.session.indexSheetPath!),
      ...widget.photos.map(_ViewerItem.photo),
    ];
    return items;
  }

  int get _photoIndexOffset => widget.session.isFilmMode &&
          widget.session.indexSheetPath?.isNotEmpty == true
      ? 1
      : 0;

  bool get _isCurrentIndexSheet => _items[_currentIndex].isIndexSheet;

  @override
  void initState() {
    super.initState();
    final resolvedInitial =
        (widget.initialIndex + _photoIndexOffset).clamp(0, _items.length - 1);
    _currentIndex = resolvedInitial;
    _pageController = PageController(initialPage: _currentIndex);
    _selectedLut = LutType.natural;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showColorSheet() {
    if (!_canAdjustLook) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '色味を切り替える',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'アルバムで見返すときにだけフィルムの色味を選べます。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              LutSelectorWidget(
                selected: _selectedLut,
                onSelected: (lut) => setState(() => _selectedLut = lut),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentPhotoToLibrary() async {
    if (_isSavingToPhotos) return;
    setState(() => _isSavingToPhotos = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final currentItem = _items[_currentIndex];
      final savedCount = await PhotoLibraryService.saveImage(
        currentItem.imagePath,
      );
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
    } finally {
      if (mounted) setState(() => _isSavingToPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _items[_currentIndex];
    final currentPhoto = currentItem.photo;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${_items.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isSavingToPhotos ? null : _saveCurrentPhotoToLibrary,
            icon: Icon(
              _isSavingToPhotos
                  ? Icons.downloading_rounded
                  : Icons.save_alt_rounded,
            ),
            tooltip: 'iPhoneの写真へ保存',
          ),
          if (_canAdjustLook)
            IconButton(
              onPressed: _showColorSheet,
              icon: const Icon(Icons.photo_filter_outlined),
              tooltip: '色味を切り替える',
            ),
          IconButton(
            onPressed: () {
              ref.read(mainTabIndexProvider.notifier).state = 1;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'アルバムへ',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final file = File(item.imagePath);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: _buildItemSurface(item, file),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final file = File(item.imagePath);
                  final selected = index == _currentIndex;

                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 58,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? Colors.white70 : Colors.white12,
                          width: selected ? 1.2 : 0.6,
                        ),
                      ),
                      child: item.isIndexSheet
                          ? _IndexThumb(file: file)
                          : file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : const MockPhotoView(fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentItem.isIndexSheet
                        ? 'INDEX SHEET'
                        : currentPhoto?.subject?.trim().isNotEmpty == true
                            ? currentPhoto!.subject!
                            : 'CUT ${(_currentIndex + 1 - _photoIndexOffset).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentItem.isIndexSheet
                        ? '${widget.session.locationName ?? widget.session.title} の一覧'
                        : widget.session.locationName ?? widget.session.title,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentItem.isIndexSheet
                        ? '${widget.photos.length} CUTS'
                        : _formatTimestamp(currentPhoto!.timestamp),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  if (currentPhoto?.memo?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      currentPhoto!.memo!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _isSavingToPhotos ? null : _saveCurrentPhotoToLibrary,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _isSavingToPhotos ? '保存中...' : 'iPhoneの写真へ保存',
                        style: const TextStyle(letterSpacing: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isCurrentIndexSheet
                          ? null
                          : () {
                              Navigator.of(context).push(
                                DarkFadeRoute(
                                  page: JournalScreen(
                                    sessionId: widget.session.sessionId,
                                    photos: widget.photos,
                                    initialIndex:
                                        (_currentIndex - _photoIndexOffset)
                                            .clamp(0, widget.photos.length - 1),
                                  ),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'この写真のメモを編集',
                        style: TextStyle(letterSpacing: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        ref.read(mainTabIndexProvider.notifier).state = 1;
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        'アルバムへ戻る',
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 1.2,
                        ),
                      ),
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

  Widget _buildItemSurface(_ViewerItem item, File file) {
    if (!file.existsSync()) return const MockPhotoView(fit: BoxFit.cover);

    if (item.isIndexSheet) {
      return Image.file(file, fit: BoxFit.contain);
    }

    final photo = item.photo!;
    // 既にシェーダーが焼き込まれた画像はそのまま表示
    if (photo.imagePath.endsWith('_film.png')) {
      return Image.file(file, fit: BoxFit.contain);
    }

    // フィルター未適用の元画像: グレイン+ビネットを乗せてアスペクト比を維持
    final lut =
        widget.session.isFilmMode ? LutType.natural : _selectedLut;
    return FilmProcessedSurface(
      lutType: lut,
      animated: false, // 写真閲覧時はグレイン静止
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}

class _IndexThumb extends StatelessWidget {
  final File file;

  const _IndexThumb({required this.file});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const MockPhotoView(fit: BoxFit.cover),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'INDEX',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  final y = timestamp.year.toString();
  final m = timestamp.month.toString().padLeft(2, '0');
  final d = timestamp.day.toString().padLeft(2, '0');
  final h = timestamp.hour.toString().padLeft(2, '0');
  final min = timestamp.minute.toString().padLeft(2, '0');
  return '$y.$m.$d  $h:$min';
}
