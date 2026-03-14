import 'package:flutter/material.dart';

/// フィルムカウンター — 残りコマ数をフィルム風に表示
/// シャッターを切るたびに数字がカチッとめくれるアニメーション付き
class FilmCounterWidget extends StatefulWidget {
  final int remaining;
  final int total;

  const FilmCounterWidget({
    super.key,
    required this.remaining,
    required this.total,
  });

  @override
  State<FilmCounterWidget> createState() => _FilmCounterWidgetState();
}

class _FilmCounterWidgetState extends State<FilmCounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  int _displayedRemaining = 0;

  @override
  void initState() {
    super.initState();
    _displayedRemaining = widget.remaining;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(FilmCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) {
      _flipController.forward(from: 0).then((_) {
        setState(() => _displayedRemaining = widget.remaining);
        _flipController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final used = widget.total - widget.remaining;
    final ratio = widget.total > 0 ? used / widget.total : 0.0;
    final isLow = widget.remaining <= 5 && widget.remaining > 0;
    final isEmpty = widget.remaining == 0;

    final digitColor = isEmpty
        ? Colors.redAccent
        : isLow
            ? Colors.orange
            : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEmpty
              ? Colors.redAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // コマ数インジケーター
          SizedBox(
            width: 28,
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                color: isEmpty
                    ? Colors.redAccent
                    : isLow
                        ? Colors.orange
                        : Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // アニメーション付きカウンター
          AnimatedBuilder(
            animation: _flipAnimation,
            builder: (_, __) {
              // 0→0.5: 古い数字がスライドアップで消える
              // 0.5→1: 新しい数字がスライドダウンで現れる
              final t = _flipAnimation.value;
              final offset = t < 0.5
                  ? Offset(0, -t * 2 * 6) // 上へ飛ぶ
                  : Offset(0, (1 - t) * 2 * 6); // 下から現れる
              final displayNum = t < 0.5
                  ? _displayedRemaining
                  : widget.remaining;

              return Transform.translate(
                offset: offset,
                child: Opacity(
                  opacity: (1 - (t < 0.5 ? t * 2 : (t - 0.5) * 2))
                      .clamp(0.0, 1.0),
                  child: Text(
                    displayNum.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: digitColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
