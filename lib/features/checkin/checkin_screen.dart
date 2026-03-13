import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/zoo.dart';
import '../../core/utils/routes.dart';
import '../camera/camera_screen.dart';
import '../camera/film_session_notifier.dart';
import 'checkin_notifier.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkInProvider.notifier).detectNearbyZoos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkInProvider);
    final filtered = _query.isEmpty
        ? state.nearbyZoos
        : state.nearbyZoos
            .where((z) =>
                z.name.contains(_query) || z.prefecture.contains(_query))
            .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white70,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'チェックイン',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                state.isLoading
                    ? '近くの動物園を検索中 ...'
                    : state.nearbyZoos.isEmpty
                        ? '動物園が見つかりませんでした'
                        : '${state.nearbyZoos.length} 件',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 検索
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '動物園名・都道府県で絞り込み',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),

            const SizedBox(height: 8),

            if (state.isLoading)
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white30,
                      strokeWidth: 1,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _WildModeItem(
                        onTap: () => _onSelectZoo(context, null),
                      );
                    }
                    final zoo = filtered[index - 1];
                    return _ZooListItem(
                      zoo: zoo,
                      onTap: () => _onSelectZoo(context, zoo),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onSelectZoo(BuildContext context, Zoo? zoo) {
    if (zoo != null) {
      ref.read(checkInProvider.notifier).checkIn(zoo);
    } else {
      ref.read(checkInProvider.notifier).checkOut();
    }
    _showNewFilmSheet(context, zoo);
  }

  void _showNewFilmSheet(BuildContext context, Zoo? zoo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _NewFilmSheet(
        zoo: zoo,
        onCreated: () {
          Navigator.pop(ctx);
          Navigator.of(context).pushReplacement(
            DarkFadeRoute(page: const CameraScreen()),
          );
        },
      ),
    );
  }
}

// ── ワイルドモード（任意の場所）──────────────────────────────

class _WildModeItem extends StatelessWidget {
  final VoidCallback onTap;

  const _WildModeItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.terrain,
            color: Colors.white.withValues(alpha: 0.5),
            size: 18,
          ),
        ),
        title: const Text(
          '野生・その他',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: Text(
          '動物園以外の場所で撮影',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

// ── 動物園リストアイテム ──────────────────────────────────────

class _ZooListItem extends StatelessWidget {
  final Zoo zoo;
  final VoidCallback onTap;

  const _ZooListItem({required this.zoo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.location_on_outlined,
            color: Colors.white.withValues(alpha: 0.4),
            size: 18,
          ),
        ),
        title: Text(
          zoo.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Text(
          zoo.prefecture,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

// ── 新規フィルム作成シート ────────────────────────────────────

class _NewFilmSheet extends ConsumerStatefulWidget {
  final Zoo? zoo;
  final VoidCallback onCreated;

  const _NewFilmSheet({required this.zoo, required this.onCreated});

  @override
  ConsumerState<_NewFilmSheet> createState() => _NewFilmSheetState();
}

class _NewFilmSheetState extends ConsumerState<_NewFilmSheet> {
  late final TextEditingController _titleController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.zoo?.name ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isCreating = true);

    await ref.read(filmSessionProvider.notifier).createSession(
          title: _titleController.text.trim(),
          locationName: widget.zoo?.name,
          zooId: widget.zoo?.zooId,
        );

    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.zoo != null) ...[
                Icon(
                  Icons.location_on,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.zoo!.prefecture,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ] else
                Text(
                  '野生・その他',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'フィルムを装填する',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 3,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'タイトル',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            autofocus: widget.zoo == null,
          ),
          const SizedBox(height: 24),
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
                elevation: 0,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '撮影開始',
                      style: TextStyle(fontSize: 16, letterSpacing: 3),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
