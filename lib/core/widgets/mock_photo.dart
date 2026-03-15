import 'dart:io';

import 'package:flutter/material.dart';
import '../mock/mock_photo_library.dart';

class MockPhotoView extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;
  final bool monochrome;
  final double opacity;

  const MockPhotoView({
    super.key,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.monochrome = false,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPath = imagePath ?? primaryMockPhotoPath();
    final child = resolvedPath != null && File(resolvedPath).existsSync()
        ? Image.file(File(resolvedPath), fit: fit)
        : Container(
            color: const Color(0xFF1A1A1A),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                color: Colors.white24,
                size: 32,
              ),
            ),
          );

    Widget content =
        opacity < 1.0 ? Opacity(opacity: opacity, child: child) : child;

    if (monochrome) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: content,
      );
    }

    return content;
  }
}
