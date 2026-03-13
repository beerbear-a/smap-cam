import 'package:flutter/material.dart';

/// カメラアプリらしい、暗転フェードのページ遷移
class DarkFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  DarkFadeRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
              ),
              child: child,
            );
          },
        );
}

/// push + removeUntil のフェード版
Route<T> darkFadeRoute<T>(Widget page) => DarkFadeRoute<T>(page: page);
