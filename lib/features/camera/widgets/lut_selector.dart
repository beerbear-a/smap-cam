import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'film_preview.dart';

class LutSelectorWidget extends StatelessWidget {
  final LutType selected;
  final void Function(LutType) onSelected;

  const LutSelectorWidget({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: LutType.values.map((lut) {
          final isSelected = lut == selected;
          return _LutChip(
            lut: lut,
            isSelected: isSelected,
            onTap: () {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                onSelected(lut);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}

class _LutChip extends StatelessWidget {
  final LutType lut;
  final bool isSelected;
  final VoidCallback onTap;

  const _LutChip({
    required this.lut,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.white54 : Colors.white12,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w300,
                    letterSpacing: 2.5,
                  ),
                  child: Text(lut.label),
                ),
                if (!lut.isPro) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: isSelected ? Colors.white54 : Colors.white24,
                fontSize: 9,
                letterSpacing: 1,
              ),
              child: Text(lut.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}
