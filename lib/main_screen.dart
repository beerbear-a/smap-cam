import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/debug_settings.dart';
import 'core/config/runtime_compatibility.dart';
import 'core/models/film_session.dart';
import 'core/navigation/main_tab_provider.dart';
import 'features/camera/camera_screen.dart';
import 'features/album/album_screen.dart';
import 'features/map/map_screen.dart';
import 'features/zukan/zukan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/develop/auto_develop_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final Set<int> _initializedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processExpiredFilmDevelopment();
    });
  }

  Future<void> _processExpiredFilmDevelopment() async {
    final sessions = await AutoDevelopService.processExpiredFilms();
    if (!mounted || sessions.isEmpty) return;

    final openAlbum = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          '現像通知',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          _buildAutoDevelopMessage(sessions),
          style: const TextStyle(color: Colors.white70, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('あとで見る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('アルバムを開く'),
          ),
        ],
      ),
    );

    await AutoDevelopService.clearPendingNotifications(
      sessions.map((session) => session.sessionId),
    );

    if (!mounted) return;
    if (openAlbum == true) {
      ref.read(mainTabIndexProvider.notifier).state = 1;
    }
  }

  String _buildAutoDevelopMessage(List<FilmSession> sessions) {
    final titles =
        sessions.take(3).map((session) => '・${session.title}').join('\n');
    final extraCount = sessions.length - 3;
    final suffix = extraCount > 0 ? '\nほか $extraCount 本' : '';
    return '1年以上現像されなかったフィルムを自動で現像しました。\n\n$titles$suffix';
  }

  void _onTabTap(int index) {
    final currentIndex = ref.read(mainTabIndexProvider);
    if (index == currentIndex) return;
    _initializedTabs.add(index);
    HapticFeedback.selectionClick();
    ref.read(mainTabIndexProvider.notifier).state = index;
  }

  Widget _buildScreen(int index) {
    if (!_initializedTabs.contains(index)) {
      return const SizedBox.shrink();
    }

    return switch (index) {
      0 => const CameraScreen(),
      1 => const AlbumScreen(),
      2 => RuntimeCompatibility.disableMapbox
          ? _CompatibilityPlaceholder(
              title: 'マップは非表示',
              message:
                  RuntimeCompatibility.mapboxDisableReason ??
                  'マップは現在表示しない設定です。',
            )
          : const MapScreen(),
      3 => const ZukanScreen(),
      4 => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final showLabels = ref.watch(navigationLabelsVisibleProvider);
    final currentIndex = ref.watch(mainTabIndexProvider);
    final addonTabs = ref.watch(addonTabsVisibilityProvider);
    final debugSettings = ref.watch(debugSettingsProvider);
    final visibility = computeFeatureVisibility(
      debug: debugSettings,
      showMap: addonTabs.showMap,
      showZukan: addonTabs.showZukan,
      mapboxDisabled: RuntimeCompatibility.disableMapbox,
    );
    final isCurrentTabHidden = (currentIndex == 2 && !visibility.mapVisible) ||
        (currentIndex == 3 && !visibility.zukanVisible);
    final visibleIndex = isCurrentTabHidden ? 0 : currentIndex;
    _initializedTabs.add(visibleIndex);

    if (isCurrentTabHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(mainTabIndexProvider.notifier).state = 0;
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: visibleIndex,
        children: List.generate(5, _buildScreen),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: visibleIndex,
        onTap: _onTabTap,
        showLabels: showLabels,
        showMap: visibility.mapVisible,
        showZukan: visibility.zukanVisible,
      ),
    );
  }
}

class _CompatibilityPlaceholder extends StatelessWidget {
  final String title;
  final String message;

  const _CompatibilityPlaceholder({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Colors.white54,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom Navigation ────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool showLabels;
  final bool showMap;
  final bool showZukan;
  final void Function(int) onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.showLabels,
    required this.showMap,
    required this.showZukan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: showLabels ? 56 : 44,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.camera_alt_outlined,
                activeIcon: Icons.camera_alt,
                label: 'カメラ',
                selected: currentIndex == 0,
                showLabel: showLabels,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.photo_library_outlined,
                activeIcon: Icons.photo_library,
                label: 'アルバム',
                selected: currentIndex == 1,
                showLabel: showLabels,
                onTap: () => onTap(1),
              ),
              if (showMap)
                _NavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: 'マップ',
                  selected: currentIndex == 2,
                  showLabel: showLabels,
                  onTap: () => onTap(2),
                ),
              if (showZukan)
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view,
                  label: '図鑑',
                  selected: currentIndex == 3,
                  showLabel: showLabels,
                  onTap: () => onTap(3),
                ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: '設定',
                selected: currentIndex == 4,
                showLabel: showLabels,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アクティブインジケータードット
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: selected ? 4 : 0,
              height: selected ? 4 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            Icon(
              selected ? activeIcon : icon,
              color: selected ? Colors.white : Colors.white38,
              size: 22,
            ),
            if (showLabel) ...[
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
