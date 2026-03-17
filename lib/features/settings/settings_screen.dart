import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/ai_connection_settings.dart';
import '../../core/config/ai_memory_assist.dart';
import '../../core/config/camera_settings.dart';
import '../../core/config/debug_settings.dart';
import '../../core/config/runtime_compatibility.dart';
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
    this.showZukan = true,
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
    state = AddonTabsVisibility(
      showMap: prefs.getBool('show_map_tab') ?? true,
      showZukan: prefs.getBool('show_zukan_tab') ?? true,
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
    final aiConnection = ref.watch(aiConnectionSettingsProvider);
    final aiSettings = ref.watch(aiMemoryAssistSettingsProvider);
    final addonTabs = ref.watch(addonTabsVisibilityProvider);
    final debugSettings = ref.watch(debugSettingsProvider);
    final visibility = computeFeatureVisibility(
      debug: debugSettings,
      showMap: addonTabs.showMap,
      showZukan: addonTabs.showZukan,
      mapboxDisabled: RuntimeCompatibility.disableMapbox,
    );
    final effectiveAddonTabs = addonTabs.copyWith(
      showMap: visibility.mapVisible,
      showZukan: visibility.zukanVisible,
    );

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
                addonTabs: effectiveAddonTabs,
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
            _SettingsTile(
              title: '写ルンですモード',
              subtitle: '固定焦点と32mm相当の画角、明るめの露出に切り替えます',
              trailing: Switch(
                value: ref.watch(
                  cameraSettingsProvider.select(
                    (s) => s.utsurunModeEnabled,
                  ),
                ),
                onChanged: (value) => ref
                    .read(cameraSettingsProvider.notifier)
                    .setUtsurunModeEnabled(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            _SettingsTile(
              title: '撮影モード',
              subtitle: '撮影画面で使う標準モードを選びます',
              trailing: _CaptureModeSelector(
                value: ref.watch(
                  cameraSettingsProvider.select(
                    (s) => s.preferredCaptureMode,
                  ),
                ),
                onChanged: (mode) => ref
                    .read(cameraSettingsProvider.notifier)
                    .setPreferredCaptureMode(mode),
              ),
            ),
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

            const _SectionHeader(title: 'AI'),
            _SettingsTile(
              title: 'AIログイン / 接続',
              subtitle: aiConnection.summary,
              trailing: _AiConnectionStatusChip(settings: aiConnection),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _AiConnectionScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              title: 'AIで思い出を整理',
              subtitle: aiConnection.mode == AiConnectionMode.selfHosted &&
                      !aiConnection.canUseSelfHosted
                  ? '自前APIモードです。先に接続先を設定してください'
                  : '写真やメモから、ロール全体の下書きを作ります',
              trailing: Switch(
                value: aiSettings.enabled,
                onChanged: (value) => ref
                    .read(aiMemoryAssistSettingsProvider.notifier)
                    .setEnabled(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            _SettingsTile(
              title: '現像後に提案する',
              subtitle: '現像完了のあと、AI整理付きでメモ画面へ進めます',
              trailing: Switch(
                value: aiSettings.enabled && aiSettings.promptAfterDevelop,
                onChanged: aiSettings.enabled
                    ? (value) => ref
                        .read(aiMemoryAssistSettingsProvider.notifier)
                        .setPromptAfterDevelop(value)
                    : null,
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            _SettingsTile(
              title: '文章の雰囲気',
              subtitle: aiSettings.tone.description,
              trailing: _AiToneSelector(
                current: aiSettings.tone,
                enabled: aiSettings.enabled,
                onSelected: (tone) => ref
                    .read(aiMemoryAssistSettingsProvider.notifier)
                    .setTone(tone),
              ),
            ),
            const _SettingsTile(
              title: '送る情報',
              subtitle: '場所名、テーマ、セッションメモ、写真ごとのメモと時刻を使って下書きを作ります。画像送信はまだ無効です。',
            ),

            const Divider(color: Colors.white12, height: 1),

            if (RuntimeCompatibility.disableMapbox ||
                RuntimeCompatibility.disableFragmentShaders) ...[
              const _SectionHeader(title: '互換モード'),
              _SettingsTile(
                title: 'iOS 26 安定化対策',
                subtitle: [
                  RuntimeCompatibility.mapboxDisableReason,
                  RuntimeCompatibility.fragmentShaderDisableReason,
                ].whereType<String>().join('\n'),
              ),
              const Divider(color: Colors.white12, height: 1),
            ],

            const _SectionHeader(title: 'デバッグ'),
            _SettingsTile(
              title: 'デバッグモード',
              subtitle: '検証用の設定を表示します',
              trailing: Switch(
                value: debugSettings.enabled,
                onChanged: (value) => ref
                    .read(debugSettingsProvider.notifier)
                    .setEnabled(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            if (debugSettings.enabled) ...[
              _SettingsTile(
              title: '場所機能',
              subtitle: 'チェックイン/マップなど場所機能をまとめてON/OFF',
              trailing: Switch(
                value: debugSettings.zooFeaturesEnabled,
                onChanged: (value) => ref
                    .read(debugSettingsProvider.notifier)
                    .setZooFeaturesEnabled(value),
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white12,
                ),
              ),
              _SettingsTile(
                title: 'フィルムシェーダー',
                subtitle: 'プレビュー/焼き込みに使うシェーダーを切り替え',
                trailing: _DebugShaderSelector(
                  value: debugSettings.filmShaderAssetOverride,
                  onChanged: (value) => ref
                      .read(debugSettingsProvider.notifier)
                      .setFilmShaderAssetOverride(value),
                ),
              ),
            ],
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
              subtitle: !debugSettings.zooFeaturesEnabled
                  ? '場所機能がOFFのためマップは表示されません'
                  : RuntimeCompatibility.disableMapbox
                      ? (RuntimeCompatibility.mapboxDisableReason ??
                          '現在はマップはプレースホルダー表示です')
                      : '非表示にするとカメラとアルバムだけになります',
              trailing: Switch(
                value: visibility.mapVisible,
                onChanged: !debugSettings.zooFeaturesEnabled
                    ? null
                    : (value) => ref
                        .read(addonTabsVisibilityProvider.notifier)
                        .setMapVisible(value),
                activeThumbColor: Colors.white,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            _SettingsTile(
              title: '図鑑タブを表示',
              subtitle: !debugSettings.zooFeaturesEnabled
                  ? '場所機能がOFFのため図鑑は表示されません'
                  : '設定からいつでも表示 / 非表示を切り替えられます',
              trailing: Switch(
                value: visibility.zukanVisible,
                onChanged: !debugSettings.zooFeaturesEnabled
                    ? null
                    : (value) => ref
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
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useStackedLayout = constraints.maxWidth < 360 && trailing != null;

        return InkWell(
          onTap: onTap,
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

class _CaptureModeSelector extends StatelessWidget {
  final CaptureMode value;
  final ValueChanged<CaptureMode> onChanged;

  const _CaptureModeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CaptureMode>(
          value: value,
          dropdownColor: const Color(0xFF111111),
          icon: const Icon(Icons.expand_more, color: Colors.white54),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          items: const [
            DropdownMenuItem(
              value: CaptureMode.film,
              child: Text('フィルム'),
            ),
            DropdownMenuItem(
              value: CaptureMode.instant,
              child: Text('インスタント'),
            ),
          ],
          onChanged: (mode) {
            if (mode != null) onChanged(mode);
          },
        ),
      ),
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

class _AiToneSelector extends StatelessWidget {
  final AiMemoryTone current;
  final bool enabled;
  final ValueChanged<AiMemoryTone> onSelected;

  const _AiToneSelector({
    required this.current,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: AiMemoryTone.values.map((tone) {
            final selected = tone == current;
            return Padding(
              padding: EdgeInsets.only(
                left: tone == AiMemoryTone.values.first ? 0 : 6,
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(tone);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? Colors.white54 : Colors.white12,
                    ),
                  ),
                  child: Text(
                    tone.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AiConnectionStatusChip extends StatelessWidget {
  final AiConnectionSettings settings;

  const _AiConnectionStatusChip({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isConnected = settings.mode == AiConnectionMode.localPreview ||
        settings.canUseSelfHosted;
    final foreground = settings.mode == AiConnectionMode.localPreview
        ? Colors.white70
        : isConnected
            ? const Color(0xFFF1D8AF)
            : Colors.white54;
    final background = settings.mode == AiConnectionMode.localPreview
        ? Colors.white.withValues(alpha: 0.08)
        : isConnected
            ? const Color(0xFFF1D8AF).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        settings.statusLabel,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _AiConnectionScreen extends ConsumerStatefulWidget {
  const _AiConnectionScreen();

  @override
  ConsumerState<_AiConnectionScreen> createState() =>
      _AiConnectionScreenState();
}

class _AiConnectionScreenState extends ConsumerState<_AiConnectionScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _baseUrlController;
  late TextEditingController _tokenController;
  late AiConnectionMode _mode;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiConnectionSettingsProvider);
    _mode = settings.mode;
    _displayNameController = TextEditingController(text: settings.displayName);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _tokenController = TextEditingController(text: settings.accessToken);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(aiConnectionSettingsProvider.notifier);
    final next = AiConnectionSettings(
      mode: _mode,
      displayName: _displayNameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      accessToken: _tokenController.text.trim(),
    );
    await notifier.save(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI接続設定を保存しました')),
    );
  }

  Future<void> _clear() async {
    _displayNameController.clear();
    _baseUrlController.clear();
    _tokenController.clear();
    await ref
        .read(aiConnectionSettingsProvider.notifier)
        .clearSelfHostedCredentials();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('自前APIの接続情報を消去しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiConnectionSettingsProvider);
    final currentStatus = _mode == AiConnectionMode.localPreview
        ? 'ローカル下書きモード'
        : settings.canUseSelfHosted &&
                settings.baseUrl.trim() == _baseUrlController.text.trim() &&
                settings.accessToken.trim() == _tokenController.text.trim()
            ? '自前API 接続済み'
            : '自前API 未接続';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'AIログイン / 接続',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AIの接続方法',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '現在: $currentStatus',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'いまの生成はローカルでも動きます。ここでは将来の自前API接続先も先に保存できます。',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '接続モード',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: AiConnectionMode.values.map((mode) {
              final selected = mode == _mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _mode = mode;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(
                      right: mode == AiConnectionMode.values.last ? 0 : 10,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? Colors.white54 : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_mode == AiConnectionMode.selfHosted) ...[
            const SizedBox(height: 20),
            _AiConnectionField(
              controller: _displayNameController,
              label: '表示名',
              hintText: 'my-ai-workspace',
            ),
            const SizedBox(height: 14),
            _AiConnectionField(
              controller: _baseUrlController,
              label: 'API Base URL',
              hintText: 'https://api.example.com',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            _AiConnectionField(
              controller: _tokenController,
              label: 'Access Token',
              hintText: 'sk_live_...',
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Text(
              '保存済みトークン: ${settings.maskedToken}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '接続設定を保存',
              style: TextStyle(letterSpacing: 1.2),
            ),
          ),
          if (_mode == AiConnectionMode.selfHosted) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _clear,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                '自前APIの接続情報を消去',
                style: TextStyle(letterSpacing: 1.0),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiConnectionField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;

  const _AiConnectionField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white38),
            ),
          ),
        ),
      ],
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

class _DebugShaderSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DebugShaderSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          dropdownColor: const Color(0xFF1A1A1A),
          iconEnabledColor: Colors.white54,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          items: debugFilmShaderOptions.entries.map((entry) {
            return DropdownMenuItem<String?>(
              value: entry.value,
              child: Text(entry.key),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
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
