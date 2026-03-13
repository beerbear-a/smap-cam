import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
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

  void _handleTap() {
    if (widget.onPressed == null) return;
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.onPressed == null
                ? Colors.grey.withOpacity(0.4)
                : Colors.white,
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 3,
            ),
            boxShadow: [
              if (widget.onPressed != null)
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 16,
                  spreadRadius: 4,
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
