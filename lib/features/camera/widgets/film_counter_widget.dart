import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '残り $remaining / $total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w300,
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
