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
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
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
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? Colors.white : Colors.grey.withValues(alpha: 0.4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 3,
            ),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: widget.isCapturing
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
