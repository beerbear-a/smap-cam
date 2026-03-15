import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/experience_rules.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/navigation/main_tab_provider.dart';
import '../../core/models/zoo.dart';
import '../camera/camera_notifier.dart';
import '../camera/film_session_notifier.dart';
import '../camera/widgets/film_preview.dart';
import 'checkin_notifier.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isCheckingRules = false;
  bool _filmAvailableToday = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkInProvider.notifier).detectNearbyZoos();
      _loadFilmAvailability();
    });
  }

  Future<void> _loadFilmAvailability() async {
    if (!enforceAnalogExperienceRules) return;
    setState(() => _isCheckingRules = true);
    final alreadyCreated = await DatabaseHelper.hasFilmSessionOnDay(
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _filmAvailableToday = !alreadyCreated;
      _isCheckingRules = false;
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
            .where(
                (z) => z.name.contains(_query) || z.prefecture.contains(_query))
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
                    'ロールをつくる',
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
                    ? '近くの場所を探しています ...'
                    : state.nearbyZoos.isEmpty
                        ? '近くの候補が見つかりませんでした'
                        : '近くの場所 ${state.nearbyZoos.length} 件',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _RollStartSummaryCard(
                isChecking: _isCheckingRules,
                filmAvailableToday: _filmAvailableToday,
                onQuickStart: () => _onSelectZoo(context, null),
              ),
            ),

            const SizedBox(height: 14),

            // 検索
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '名前・都道府県で絞り込み',
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

  Future<void> _showNewFilmSheet(BuildContext context, Zoo? zoo) async {
    final parentNavigator = Navigator.of(context);
    var created = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        final sheetNavigator = Navigator.of(ctx);
        return _NewFilmSheet(
          zoo: zoo,
          onCancel: () => sheetNavigator.pop(),
          onCreated: () async {
            created = true;
            await ref.read(cameraProvider.notifier).loadActiveSession();
            ref.read(mainTabIndexProvider.notifier).state = 0;
            sheetNavigator.pop();
            if (parentNavigator.canPop()) {
              parentNavigator.pop();
            }
          },
        );
      },
    );
    if (!created && mounted) {
      ref.read(checkInProvider.notifier).checkOut();
    }
  }
}

// ── 手入力モード（任意の場所）──────────────────────────────

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
            Icons.edit_location_alt_outlined,
            color: Colors.white.withValues(alpha: 0.5),
            size: 18,
          ),
        ),
        title: const Text(
          '場所を自由に決める',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w300,
          ),
        ),
        subtitle: Text(
          '公園、街、旅先でも一本残せます',
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

class _RollStartSummaryCard extends StatelessWidget {
  final bool isChecking;
  final bool filmAvailableToday;
  final VoidCallback onQuickStart;

  const _RollStartSummaryCard({
    required this.isChecking,
    required this.filmAvailableToday,
    required this.onQuickStart,
  });

  @override
  Widget build(BuildContext context) {
    final title = !enforceAnalogExperienceRules
        ? '今日はどこで残す？'
        : filmAvailableToday
            ? '今日はまだフィルムを作れます'
            : '今日はインスタントで残す日です';
    final body = !enforceAnalogExperienceRules
        ? '行き先を決めて、今日のロールを始めます。'
        : filmAvailableToday
            ? 'フィルムは1日1本です。場所を決めて、27枚の一本を始めます。'
            : '今日のフィルムは作成済みです。追加で残すならインスタントから始めます。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  filmAvailableToday ? 'FILM DAY' : 'INSTANT DAY',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (isChecking)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white38,
                    strokeWidth: 1.4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onQuickStart,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              ),
              child: const Text(
                '場所をあとで決めて始める',
                style: TextStyle(letterSpacing: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 場所候補リストアイテム ───────────────────────────────────

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
  final VoidCallback onCancel;
  final Future<void> Function() onCreated;

  const _NewFilmSheet({
    required this.zoo,
    required this.onCancel,
    required this.onCreated,
  });

  @override
  ConsumerState<_NewFilmSheet> createState() => _NewFilmSheetState();
}

class _NewFilmSheetState extends ConsumerState<_NewFilmSheet> {
  late final TextEditingController _locationController;
  late final TextEditingController _themeController;
  late final TextEditingController _memoController;
  bool _isCreating = false;
  bool _isCheckingFilmAvailability = false;
  bool _filmAvailableToday = true;
  LutType _selectedLut = LutType.natural;

  static const _themeSuggestions = [
    '今日いちばん残したいもの',
    '光と影',
    '午後のやわらかい光',
    '何気ない一瞬',
  ];

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(
      text: widget.zoo?.name ?? '',
    );
    _themeController = TextEditingController();
    _memoController = TextEditingController();
    _loadFilmAvailability();
  }

  Future<void> _loadFilmAvailability() async {
    if (!enforceAnalogExperienceRules) return;
    setState(() => _isCheckingFilmAvailability = true);
    final alreadyCreated = await DatabaseHelper.hasFilmSessionOnDay(
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _filmAvailableToday = !alreadyCreated;
      _isCheckingFilmAvailability = false;
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _themeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final destination = _locationController.text.trim();
    final theme = _themeController.text.trim();
    final memo = _memoController.text.trim();
    final title = destination.isNotEmpty
        ? destination
        : theme.isNotEmpty
            ? theme
            : widget.zoo?.name ?? '新しいロール';
    if (title.isEmpty) return;
    if (_isCheckingFilmAvailability) return;
    if (enforceAnalogExperienceRules && !_filmAvailableToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('フィルムは1日1本までです。今日は新しいフィルムを作れません。'),
        ),
      );
      return;
    }
    setState(() => _isCreating = true);

    await ref.read(filmSessionProvider.notifier).createSession(
          title: title,
          locationName: destination.isNotEmpty ? destination : widget.zoo?.name,
          zooId: widget.zoo?.zooId,
          theme: theme.isNotEmpty ? theme : null,
          memo: memo.isNotEmpty ? memo : null,
          captureMode: CaptureMode.film,
        );
    ref.read(cameraProvider.notifier).setLut(_selectedLut);

    await widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
              IconButton(
                onPressed: _isCreating ? null : widget.onCancel,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white70,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    if (widget.zoo != null) ...[
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.zoo!.prefecture} の候補',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ] else
                      Text(
                        '自由に場所を決める',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isCreating ? null : widget.onCancel,
                child: const Text('閉じる'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '撮影を始める',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 3,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'どこかへ一本だけ持っていく気持ちで、行き先とテーマを決めて残します。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          if (widget.zoo != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                'この場所を中心に、一本だけ持っていくイメージです。撮り切るまでフィルムは交換できません。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (enforceAnalogExperienceRules) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                _filmAvailableToday
                    ? 'フィルムは一本の時間を残すモードです。撮り切ったあとも1時間待ってから現像します。'
                    : '今日はもうフィルムを作成済みです。続きは使い切ったあとのインスタント移行から進めます。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
          if (widget.zoo != null) ...[
            _SelectedLocationCard(
              title: widget.zoo!.name,
              subtitle: '${widget.zoo!.prefecture} · ここで撮影を始めます',
            ),
          ] else ...[
            const Text(
              '目的地 / 場所',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'どこでこのロールを残す？',
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
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'このロールのテーマ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _themeController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: '今日は何を残したい？',
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
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _themeSuggestions.map((theme) {
              return ActionChip(
                label: Text(theme),
                onPressed: () => _themeController.text = theme,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                labelStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            '撮る前のメモ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _memoController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: '会いたいもの、残したい光、その日の約束ごとなど',
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
          ),
          const SizedBox(height: 28),
          const Text(
            'フィルムの色味',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: LutType.values.map((lut) {
              final selected = lut == _selectedLut;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLut = lut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.only(
                      right: lut != LutType.values.last ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                        width: selected ? 1.0 : 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lut.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lut.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.3),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating || !_filmAvailableToday ? null : _create,
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
                      'フィルムを作成する',
                      style: TextStyle(fontSize: 16, letterSpacing: 2.4),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedLocationCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SelectedLocationCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
