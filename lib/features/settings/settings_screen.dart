import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/pro_access.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/navigation/main_tab_provider.dart';
import '../camera/camera_notifier.dart';
import '../share/watermark_service.dart';

// ── Username Provider ────────────────────────────────────────

final usernameProvider = StateNotifierProvider<UsernameNotifier, String>((ref) {
  return UsernameNotifier();
});

class UsernameNotifier extends StateNotifier<String> {
  UsernameNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('username') ?? '';
  }

  Future<void> setUsername(String value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', value);
  }
}

// ── Watermark Position Provider ──────────────────────────────

final watermarkPositionProvider =
    StateNotifierProvider<WatermarkPositionNotifier, WatermarkPosition>((ref) {
  return WatermarkPositionNotifier();
});

final navigationLabelsVisibleProvider =
    StateNotifierProvider<NavigationLabelsVisibleNotifier, bool>((ref) {
  return NavigationLabelsVisibleNotifier();
});

final addonTabsVisibilityProvider =
    StateNotifierProvider<AddonTabsVisibilityNotifier, AddonTabsVisibility>(
        (ref) {
  return AddonTabsVisibilityNotifier();
});

class AddonTabsVisibility {
  final bool showMap;
  final bool showZukan;

  const AddonTabsVisibility({
    this.showMap = true,
    this.showZukan = false,
  });

  AddonTabsVisibility copyWith({
    bool? showMap,
    bool? showZukan,
  }) {
    return AddonTabsVisibility(
      showMap: showMap ?? this.showMap,
      showZukan: showZukan ?? this.showZukan,
    );
  }
}

class WatermarkPositionNotifier extends StateNotifier<WatermarkPosition> {
  WatermarkPositionNotifier() : super(WatermarkPosition.bottomRight) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('watermark_position') ?? 0;
    state = WatermarkPosition
        .values[index.clamp(0, WatermarkPosition.values.length - 1)];
  }

  Future<void> setPosition(WatermarkPosition position) async {
    state = position;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'watermark_position', WatermarkPosition.values.indexOf(position));
  }
}

class NavigationLabelsVisibleNotifier extends StateNotifier<bool> {
  NavigationLabelsVisibleNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('navigation_labels_visible') ?? true;
  }

  Future<void> setVisible(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('navigation_labels_visible', value);
  }
}

class AddonTabsVisibilityNotifier extends StateNotifier<AddonTabsVisibility> {
  AddonTabsVisibilityNotifier() : super(const AddonTabsVisibility()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_zukan_tab', false);
    state = AddonTabsVisibility(
      showMap: prefs.getBool('show_map_tab') ?? true,
      showZukan: false,
    );
  }

  Future<void> setMapVisible(bool value) async {
    state = state.copyWith(showMap: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_map_tab', value);
  }

  Future<void> setZukanVisible(bool value) async {
    state = state.copyWith(showZukan: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_zukan_tab', value);
  }
}

// ── Screen ──────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: ref.read(usernameProvider),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(
      cameraProvider.select((state) => state.activeSession),
    );
    final addonTabs = ref.watch(addonTabsVisibilityProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Text(
                '設定',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: _SettingsOverviewCard(
                activeSession: activeSession,
                addonTabs: addonTabs,
                onOpenCamera: () {
                  ref.read(mainTabIndexProvider.notifier).state = 0;
                },
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // プロフィール
            const _SectionHeader(title: 'プロフィール'),
            _SettingsTile(
              title: 'ユーザー名',
              subtitle: 'シェア時の透かしに使用',
              trailing: _UsernameField(controller: _usernameController),
            ),

            const Divider(color: Colors.white12, height: 1),

            // カメラ
            const _SectionHeader(title: 'カメラ'),
            const _SettingsTile(
              title: 'フィルム枚数',
              subtitle: '1本あたりの撮影枚数',
              trailing: Text(
                '27 枚',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            const _SectionHeader(title: 'Pro 機能'),
            _SettingsTile(
              title: 'Proを有効化',
              subtitle: '現像の待ち時間をスキップできるようになります',
              trailing: Switch(
                value: ref.watch(proAccessProvider),
                onChanged: (value) =>
                    ref.read(proAccessProvider.notifier).setEnabled(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            const _SectionHeader(title: '表示'),
            _SettingsTile(
              title: 'タブ名を表示',
              subtitle: 'ナビゲーションバーにラベルを表示します',
              trailing: Switch(
                value: ref.watch(navigationLabelsVisibleProvider),
                onChanged: (value) => ref
                    .read(navigationLabelsVisibleProvider.notifier)
                    .setVisible(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            _SettingsTile(
              title: 'マップタブを表示',
              subtitle: '非表示にするとカメラとアルバムだけになります',
              trailing: Switch(
                value: ref.watch(addonTabsVisibilityProvider).showMap,
                onChanged: (value) => ref
                    .read(addonTabsVisibilityProvider.notifier)
                    .setMapVisible(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            _SettingsTile(
              title: '図鑑タブを表示',
              subtitle: '設定からいつでも表示 / 非表示を切り替えられます',
              trailing: Switch(
                value: ref.watch(addonTabsVisibilityProvider).showZukan,
                onChanged: (value) => ref
                    .read(addonTabsVisibilityProvider.notifier)
                    .setZukanVisible(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            const _SectionHeader(title: 'フィルムの復元'),
            const _ShelvedFilmRestoreTile(),

            const Divider(color: Colors.white12, height: 1),

            // 透かし
            const _SectionHeader(title: '透かし'),
            const _WatermarkPositionSelector(),
            const _WatermarkPreview(),

            const Divider(color: Colors.white12, height: 1),

            // アプリ情報
            const _SectionHeader(title: 'アプリ情報'),
            const _SettingsTile(
              title: 'バージョン',
              trailing: Text(
                '1.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
            const _SettingsTile(
              title: 'アプリ名',
              trailing: Text(
                'ZOOSMAP',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),

            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ── Subwidgets ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SettingsOverviewCard extends StatelessWidget {
  final FilmSession? activeSession;
  final AddonTabsVisibility addonTabs;
  final VoidCallback onOpenCamera;

  const _SettingsOverviewCard({
    required this.activeSession,
    required this.addonTabs,
    required this.onOpenCamera,
  });

  @override
  Widget build(BuildContext context) {
    final sessionLabel = activeSession == null
        ? 'いまはロール未開始です'
        : activeSession!.isFilmMode
            ? 'フィルム撮影中: ${activeSession!.title}'
            : 'インスタント記録中: ${activeSession!.title}';
    final addonLabel = [
      if (addonTabs.showMap) 'マップ',
      if (addonTabs.showZukan) '図鑑',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOW',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sessionLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            addonLabel.isEmpty
                ? 'カメラとアルバムのみ表示しています'
                : '表示中: ${addonLabel.join(' / ')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onOpenCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'カメラへ戻る',
                style: TextStyle(letterSpacing: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedLayout = constraints.maxWidth < 360 && trailing != null;

        return InkWell(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: useStackedLayout
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsTileLabel(title: title, subtitle: subtitle),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: trailing!,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _SettingsTileLabel(
                          title: title,
                          subtitle: subtitle,
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _SettingsTileLabel extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SettingsTileLabel({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _UsernameField extends ConsumerWidget {
  final TextEditingController controller;

  const _UsernameField({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.end,
        decoration: const InputDecoration(
          hintText: '@username',
          hintStyle: TextStyle(color: Colors.white24),
          border: InputBorder.none,
          isDense: true,
        ),
        onSubmitted: (v) {
          ref.read(usernameProvider.notifier).setUsername(v.trim());
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

// ── 透かし位置選択 ────────────────────────────────────────────

class _WatermarkPositionSelector extends ConsumerWidget {
  const _WatermarkPositionSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(watermarkPositionProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '透かし位置',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            children: WatermarkPosition.values.map((pos) {
              final isSelected = pos == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(watermarkPositionProvider.notifier)
                        .setPosition(pos);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? Colors.white54 : Colors.white12,
                        width: isSelected ? 1.0 : 0.5,
                      ),
                    ),
                    child: Text(
                      pos.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white38,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── 透かしプレビュー ──────────────────────────────────────────

class _WatermarkPreview extends ConsumerWidget {
  const _WatermarkPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider);
    final position = ref.watch(watermarkPositionProvider);

    final label =
        username.isNotEmpty ? '@$username · ZOOSMAP' : '@username · ZOOSMAP';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プレビュー',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white12,
                      size: 40,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: position == WatermarkPosition.bottomRight ? null : 12,
                    right: position == WatermarkPosition.bottomLeft ? null : 12,
                    child: Text(
                      label,
                      textAlign: position == WatermarkPosition.bottomCenter
                          ? TextAlign.center
                          : position == WatermarkPosition.bottomRight
                              ? TextAlign.right
                              : TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
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
}

class _ShelvedFilmRestoreTile extends ConsumerWidget {
  const _ShelvedFilmRestoreTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      cameraProvider.select(
        (state) => '${state.activeSession?.sessionId}:${state.error}',
      ),
    );

    return FutureBuilder<List<FilmSession>>(
      future: DatabaseHelper.getShelvedFilmSessions(),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <FilmSession>[];
        if (sessions.isEmpty) {
          return const _SettingsTile(
            title: '退避中のフィルムはありません',
            subtitle: 'フィルムからインスタントへ切り替えたロールがここに並びます。復元は1本ごとに7日に1回だけです。',
          );
        }

        return Column(
          children: sessions.map((session) {
            final canRestore = session.canRestoreNow();
            final nextRestore = session.nextRestoreAvailableAt;
            final previousRestore = session.lastRestoredAt;
            final subtitle = canRestore
                ? session.theme?.isNotEmpty == true
                    ? 'テーマ: ${session.theme} · いま復元できます'
                    : 'このフィルムはいま復元できます'
                : previousRestore == null
                    ? '前回の復元から7日後に再び戻せます'
                    : '前回の復元: ${_formatRestoreDate(previousRestore)} · 次回: ${_formatRestoreDate(nextRestore!)}';

            return _SettingsTile(
              title: session.title,
              subtitle: subtitle,
              trailing: FilledButton(
                onPressed: canRestore
                    ? () async {
                        final restored = await ref
                            .read(cameraProvider.notifier)
                            .restoreShelvedFilm(session.sessionId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              restored
                                  ? 'フィルムを復元しました'
                                  : nextRestore != null
                                      ? 'このフィルムは ${_formatRestoreDate(nextRestore)} まで復元できません'
                                      : 'このフィルムはまだ復元できません',
                            ),
                          ),
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white24,
                ),
                child: Text(canRestore ? '復元' : '待機中'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

String _formatRestoreDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
