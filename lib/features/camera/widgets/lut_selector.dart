import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'film_preview.dart';

class LutSelectorWidget extends StatelessWidget {
  final LutType selected;
  final void Function(LutType) onSelected;
  final bool enabled;

  const LutSelectorWidget({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        children: LutType.values.map((lut) {
          final isSelected = lut == selected;
          return _LutChip(
            lut: lut,
            isSelected: isSelected,
            enabled: enabled,
            onTap: () {
              if (enabled && !isSelected) {
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
  final bool enabled;
  final VoidCallback onTap;

  const _LutChip({
    required this.lut,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: enabled ? 0.12 : 0.08)
              : Colors.black.withValues(alpha: enabled ? 0.35 : 0.25),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? Colors.white54
                : Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
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
                    color: enabled
                        ? (isSelected ? Colors.white : Colors.white38)
                        : Colors.white24,
                    fontSize: 12,
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
                      color:
                          Colors.white.withValues(alpha: enabled ? 0.15 : 0.08),
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
                color: enabled
                    ? (isSelected ? Colors.white54 : Colors.white24)
                    : Colors.white24,
                fontSize: 10,
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
