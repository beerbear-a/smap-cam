import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 縦向き固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ステータスバーをオーバーレイ表示
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: SmapCamApp()));
}

class SmapCamApp extends StatelessWidget {
  const SmapCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smap Cam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Helvetica Neue',
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
