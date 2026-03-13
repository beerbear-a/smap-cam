import 'package:flutter/material.dart';

/// フィルムカウンター — 残りコマ数をフィルム風に表示
class FilmCounterWidget extends StatelessWidget {
  final int remaining;
  final int total;

  const FilmCounterWidget({
    super.key,
    required this.remaining,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final used = total - remaining;
    final ratio = total > 0 ? used / total : 0.0;
    final isLow = remaining <= 5 && remaining > 0;
    final isEmpty = remaining == 0;

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
          // 残りコマ数
          Text(
            remaining.toString().padLeft(2, '0'),
            style: TextStyle(
              color: isEmpty
                  ? Colors.redAccent
                  : isLow
                      ? Colors.orange
                      : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
