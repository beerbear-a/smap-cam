import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/services/camera_service.dart';
import '../../core/location/location_service.dart';
import 'widgets/film_preview.dart';

// ── セルフタイマー ─────────────────────────────────────────

enum TimerMode { off, three, ten }

extension TimerModeLabel on TimerMode {
  String get label {
    switch (this) {
      case TimerMode.off:
        return 'OFF';
      case TimerMode.three:
        return '3s';
      case TimerMode.ten:
        return '10s';
    }
  }

  int get seconds {
    switch (this) {
      case TimerMode.off:
        return 0;
      case TimerMode.three:
        return 3;
      case TimerMode.ten:
        return 10;
    }
  }
}

// ── State ─────────────────────────────────────────────────────

class CameraState {
  final FilmSession? activeSession;
  final bool isCameraReady;
  final bool isCapturing;
  final bool flashEnabled;
  final int? textureId;
  final String? error;
  final LutType selectedLut;
  final double lutIntensity; // 0.0〜1.0
  final bool showGrid;
  final LightLeakStrength lightLeak;
  final TimerMode timerMode;
  final int? timerCountdown; // null = タイマー非動作

  // NOTE: シャッター音OFFは日本国内では盗撮規制法により禁止。
  // iOS（日本向けモデル）はAVFoundationレベルで強制ON、
  // Android日本向け端末も同様。UI・実装ともに提供しない。

  const CameraState({
    this.activeSession,
    this.isCameraReady = false,
    this.isCapturing = false,
    this.flashEnabled = false,
    this.textureId,
    this.error,
    this.selectedLut = LutType.natural,
    this.lutIntensity = 1.0,
    this.showGrid = false,
    this.lightLeak = LightLeakStrength.none,
    this.timerMode = TimerMode.off,
    this.timerCountdown,
  });

  int get remainingShots =>
      (activeSession?.remainingShots) ?? FilmSession.maxPhotos;

  bool get canShoot =>
      activeSession != null &&
      !activeSession!.isFull &&
      activeSession!.status == FilmStatus.shooting &&
      isCameraReady &&
      !isCapturing &&
      timerCountdown == null;

  CameraState copyWith({
    FilmSession? activeSession,
    bool? isCameraReady,
    bool? isCapturing,
    bool? flashEnabled,
    int? textureId,
    String? error,
    LutType? selectedLut,
    double? lutIntensity,
    bool? showGrid,
    LightLeakStrength? lightLeak,
    TimerMode? timerMode,
    int? timerCountdown,
    bool clearTimerCountdown = false,
  }) {
    return CameraState(
      activeSession: activeSession ?? this.activeSession,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isCapturing: isCapturing ?? this.isCapturing,
      flashEnabled: flashEnabled ?? this.flashEnabled,
      textureId: textureId ?? this.textureId,
      error: error,
      selectedLut: selectedLut ?? this.selectedLut,
      lutIntensity: lutIntensity ?? this.lutIntensity,
      showGrid: showGrid ?? this.showGrid,
      lightLeak: lightLeak ?? this.lightLeak,
      timerMode: timerMode ?? this.timerMode,
      timerCountdown: clearTimerCountdown
          ? null
          : (timerCountdown ?? this.timerCountdown),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  Timer? _timerTick;

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }

  Future<void> loadActiveSession() async {
    final session = await DatabaseHelper.getActiveSession();
    state = state.copyWith(activeSession: session);
  }

  Future<void> initializeCamera() async {
    try {
      final result = await CameraService.initializeCamera();
      final textureId = result['textureId'] as int?;
      state = state.copyWith(textureId: textureId, isCameraReady: true);
    } on PlatformException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> disposeCamera() async {
    await CameraService.stopCamera();
    state = state.copyWith(isCameraReady: false, textureId: null);
  }

  Future<void> toggleFlash() async {
    final newValue = !state.flashEnabled;
    await CameraService.setFlash(newValue);
    state = state.copyWith(flashEnabled: newValue);
  }

  void setLut(LutType lut) => state = state.copyWith(selectedLut: lut);

  void setLutIntensity(double intensity) =>
      state = state.copyWith(lutIntensity: intensity.clamp(0.0, 1.0));

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);

  void setLightLeak(LightLeakStrength leak) =>
      state = state.copyWith(lightLeak: leak);

  void cycleTimerMode() {
    final idx = TimerMode.values.indexOf(state.timerMode);
    final next = TimerMode.values[(idx + 1) % TimerMode.values.length];
    state = state.copyWith(timerMode: next);
  }

  /// シャッター: タイマーあり/なし で分岐
  void triggerShutter() {
    if (!state.canShoot) return;
    if (state.timerMode == TimerMode.off) {
      takePicture();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    final secs = state.timerMode.seconds;
    state = state.copyWith(timerCountdown: secs);
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.timerCountdown ?? 0;
      if (current <= 1) {
        timer.cancel();
        state = state.copyWith(clearTimerCountdown: true);
        takePicture();
      } else {
        state = state.copyWith(timerCountdown: current - 1);
      }
    });
  }

  void cancelTimer() {
    _timerTick?.cancel();
    state = state.copyWith(clearTimerCountdown: true);
  }

  /// 撮影 → 画像保存 → DBに記録
  Future<void> takePicture() async {
    if (state.activeSession == null ||
        state.activeSession!.isFull ||
        state.activeSession!.status != FilmStatus.shooting ||
        !state.isCameraReady ||
        state.isCapturing) return;

    state = state.copyWith(isCapturing: true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final sessionDir = Directory(
        '${dir.path}/sessions/${state.activeSession!.sessionId}',
      );
      await sessionDir.create(recursive: true);

      final photoId = const Uuid().v4();
      final savePath = '${sessionDir.path}/$photoId.jpg';

      final imagePath = await CameraService.takePicture(savePath);
      if (imagePath == null) throw Exception('撮影に失敗しました');

      final position = await LocationService.getCurrentPosition();

      final photo = Photo(
        photoId: photoId,
        sessionId: state.activeSession!.sessionId,
        imagePath: imagePath,
        timestamp: DateTime.now(),
      );

      await DatabaseHelper.insertPhoto(photo);

      if (state.activeSession!.lat == null && position != null) {
        final updated = state.activeSession!.copyWith(
          lat: position.latitude,
          lng: position.longitude,
        );
        await DatabaseHelper.updateFilmSession(updated);
        state = state.copyWith(activeSession: updated);
      }

      final updated = await DatabaseHelper.getFilmSession(
        state.activeSession!.sessionId,
      );
      state = state.copyWith(
        activeSession: updated,
        isCapturing: false,
      );

      if (updated?.isFull == true) {
        await _startDeveloping(updated!);
      }
    } on PlatformException catch (e) {
      state = state.copyWith(isCapturing: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isCapturing: false, error: e.toString());
    }
  }

  Future<void> _startDeveloping(FilmSession session) async {
    final developing = session.copyWith(status: FilmStatus.developing);
    await DatabaseHelper.updateFilmSession(developing);
    state = state.copyWith(activeSession: developing);
  }
}

final cameraProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier();
});
