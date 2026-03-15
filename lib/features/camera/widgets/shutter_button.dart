import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShutterButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isCapturing;

  const ShutterButton({
    super.key,
    required this.onPressed,
    this.isCapturing = false,
  });

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null || widget.isCapturing) return;
    _isPressed = true;
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
    if (!widget.isCapturing) {
      HapticFeedback.mediumImpact();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isCapturing;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _ShutterPainter(
              enabled: enabled,
              isCapturing: widget.isCapturing,
            ),
            child: widget.isCapturing
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _ShutterPainter extends CustomPainter {
  final bool enabled;
  final bool isCapturing;

  const _ShutterPainter({required this.enabled, required this.isCapturing});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - 8;

    // 外リング（白い輪）
    final ringPaint = Paint()
      ..color = enabled ? Colors.white : Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, outerRadius - 1.5, ringPaint);

    // 内側の白い塗り潰し円
    if (!isCapturing) {
      final fillPaint = Paint()
        ..color = enabled ? Colors.white : Colors.white24
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, innerRadius - 2, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_ShutterPainter old) =>
      old.enabled != enabled || old.isCapturing != isCapturing;
}
