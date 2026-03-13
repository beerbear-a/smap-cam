import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/map/map_screen.dart';
import 'features/zukan/zukan_screen.dart';
import 'features/settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    MapScreen(),
    ZukanScreen(),
    SettingsScreen(),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// ── Bottom Navigation ────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

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
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'マップ',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view,
                label: '図鑑',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.sliders_outlined,
                activeIcon: Icons.sliders,
                label: '設定',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
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
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: selected ? Colors.white : Colors.white38,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight:
                    selected ? FontWeight.w400 : FontWeight.w300,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
