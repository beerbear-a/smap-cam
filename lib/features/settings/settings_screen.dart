import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Provider ────────────────────────────────────────────────

final usernameProvider =
    StateNotifierProvider<UsernameNotifier, String>((ref) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          children: [
            // ヘッダー
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

            const Divider(color: Colors.white12, height: 1),

            // プロフィールセクション
            _SectionHeader(title: 'プロフィール'),
            _SettingsTile(
              title: 'ユーザー名',
              subtitle: 'シェア時の透かしに使用',
              trailing: _UsernameField(controller: _usernameController),
            ),

            const Divider(color: Colors.white12, height: 1),

            // カメラセクション
            _SectionHeader(title: 'カメラ'),
            _SettingsTile(
              title: 'フィルム枚数',
              subtitle: '1本あたりの撮影枚数',
              trailing: const Text(
                '27 枚',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // 透かしセクション
            _SectionHeader(title: '透かし'),
            _WatermarkPreview(),

            const Divider(color: Colors.white12, height: 1),

            // アプリ情報
            _SectionHeader(title: 'アプリ情報'),
            _SettingsTile(
              title: 'バージョン',
              trailing: const Text(
                '1.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
            _SettingsTile(
              title: 'アプリ名',
              trailing: const Text(
                'ZootoCam',
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
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
              ),
            ),
            if (trailing != null) trailing!,
          ],
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
        },
        onEditingComplete: () {
          ref
              .read(usernameProvider.notifier)
              .setUsername(controller.text.trim());
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

class _WatermarkPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
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
            // 透かしイメージ
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
                    right: 12,
                    child: Text(
                      username.isNotEmpty
                          ? '@$username · ZootoCam'
                          : '@username · ZootoCam',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                          ),
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
