import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/experience_rules.dart';
import '../../core/mock/mock_photo_library.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/services/camera_service.dart';
import 'film_still_service.dart';
import 'widgets/film_preview.dart';

// ── 焦点距離（換算35mm）──────────────────────────────────────

enum FocalLength { f13, f24, f35, f48, f120 }

extension FocalLengthExt on FocalLength {
  String get label {
    switch (this) {
      case FocalLength.f13:
        return '13mm';
      case FocalLength.f24:
        return '24mm';
      case FocalLength.f35:
        return '35mm';
      case FocalLength.f48:
        return '48mm';
      case FocalLength.f120:
        return '120mm';
    }
  }

  String get zoomLabel {
    switch (this) {
      case FocalLength.f13:
        return '0.5×';
      case FocalLength.f24:
        return '1×';
      case FocalLength.f35:
        return '1.5×';
      case FocalLength.f48:
        return '2×';
      case FocalLength.f120:
        return '5×';
    }
  }

  // シミュレーター用スケール（数値が大きいほど望遠）
  double get simulatorZoom {
    switch (this) {
      case FocalLength.f13:
        return 0.55;
      case FocalLength.f24:
        return 0.95;
      case FocalLength.f35:
        return 1.18;
      case FocalLength.f48:
        return 1.65;
      case FocalLength.f120:
        return 4.0;
    }
  }
}

// ── アスペクト比 ────────────────────────────────────────────

enum AspectRatioMode { r4_3, r1_1, r16_9 }

extension AspectRatioModeLabel on AspectRatioMode {
  String get label {
    switch (this) {
      case AspectRatioMode.r4_3:
        return '4:3';
      case AspectRatioMode.r1_1:
        return '1:1';
      case AspectRatioMode.r16_9:
        return '16:9';
    }
  }
}

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
  final FilmSession? completedRollSession;
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
  final bool isSimulatorMode;
  final String? simulatorPreviewPath;
  final AspectRatioMode aspectRatio;
  final FocalLength focalLength;

  // NOTE: シャッター音OFFは日本国内では盗撮規制法により禁止。
  // iOS（日本向けモデル）はAVFoundationレベルで強制ON、
  // Android日本向け端末も同様。UI・実装ともに提供しない。

  const CameraState({
    this.activeSession,
    this.completedRollSession,
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
    this.isSimulatorMode = false,
    this.simulatorPreviewPath,
    this.aspectRatio = AspectRatioMode.r4_3,
    this.focalLength = FocalLength.f35,
  });

  int get remainingShots =>
      (activeSession?.remainingShots) ?? FilmSession.maxPhotos;

  bool get canShoot =>
      activeSession != null &&
      ((activeSession?.isFilmMode ?? false)
          ? (activeSession?.canTakeMore ?? false)
          : (enforceAnalogExperienceRules
              ? (activeSession?.canTakeMore ?? false)
              : true)) &&
      isCameraReady &&
      !isCapturing &&
      timerCountdown == null;

  CameraState copyWith({
    FilmSession? activeSession,
    FilmSession? completedRollSession,
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
    bool? isSimulatorMode,
    String? simulatorPreviewPath,
    AspectRatioMode? aspectRatio,
    FocalLength? focalLength,
    bool clearCompletedRollSession = false,
  }) {
    return CameraState(
      activeSession: activeSession ?? this.activeSession,
      completedRollSession: clearCompletedRollSession
          ? null
          : completedRollSession ?? this.completedRollSession,
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
      timerCountdown:
          clearTimerCountdown ? null : (timerCountdown ?? this.timerCountdown),
      isSimulatorMode: isSimulatorMode ?? this.isSimulatorMode,
      simulatorPreviewPath: simulatorPreviewPath ?? this.simulatorPreviewPath,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      focalLength: focalLength ?? this.focalLength,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────

// ── 撮影済み写真パス一覧 ───────────────────────────────────────

class _PhotoPathsNotifier extends StateNotifier<List<String>> {
  _PhotoPathsNotifier() : super([]);
  void add(String path) => state = [...state, path];
}

final photoPathsProvider =
    StateNotifierProvider<_PhotoPathsNotifier, List<String>>(
        (ref) => _PhotoPathsNotifier());

// ── Notifier ──────────────────────────────────────────────────

class CameraNotifier extends StateNotifier<CameraState> {
  final Ref _ref;
  CameraNotifier(this._ref) : super(const CameraState());

  Timer? _timerTick;

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }

  Future<void> loadActiveSession() async {
    final session = await DatabaseHelper.getActiveSession();
    if (session != null) {
      // 新セッションが見つかったら completedRollSession も同時にクリア
      state = state.copyWith(
        activeSession: session,
        clearCompletedRollSession: true,
      );
    } else {
      state = state.copyWith(activeSession: null);
    }
  }

  Future<void> initializeCamera() async {
    try {
      final result = await CameraService.initializeCamera();
      final textureId = result['textureId'] as int?;
      state = state.copyWith(textureId: textureId, isCameraReady: true);
      await setFocalLength(state.focalLength);
    } on PlatformException catch (_) {
      // シミュレーター：カメラなしでも続行
      state = state.copyWith(
        isCameraReady: true,
        isSimulatorMode: true,
        simulatorPreviewPath: pickRandomMockPhotoPath(),
      );
    } on MissingPluginException catch (_) {
      state = state.copyWith(
        isCameraReady: true,
        isSimulatorMode: true,
        simulatorPreviewPath: pickRandomMockPhotoPath(),
      );
    }
  }

  Future<void> disposeCamera() async {
    if (!state.isSimulatorMode) await CameraService.stopCamera();
    state = state.copyWith(isCameraReady: false, textureId: null);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  Future<void> toggleFlash() async {
    final newValue = !state.flashEnabled;
    if (!state.isSimulatorMode) await CameraService.setFlash(newValue);
    state = state.copyWith(flashEnabled: newValue);
  }

  void setLut(LutType lut) {
    if (state.activeSession?.isFilmLookLocked == true) {
      state = state.copyWith(error: 'フィルム装填中はルックを変更できません');
      return;
    }
    state = state.copyWith(selectedLut: lut, error: null);
  }

  void setLutIntensity(double intensity) {
    if (state.activeSession?.isFilmLookLocked == true) {
      state = state.copyWith(error: 'フィルム装填中はルックを変更できません');
      return;
    }
    state = state.copyWith(
      lutIntensity: intensity.clamp(0.0, 1.0),
      error: null,
    );
  }

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);

  void setLightLeak(LightLeakStrength leak) =>
      state = state.copyWith(lightLeak: leak);

  Future<void> setFocalLength(FocalLength fl) async {
    state = state.copyWith(focalLength: fl, error: null);
    if (state.isSimulatorMode) return;
    try {
      await CameraService.setFocalLength(fl.name);
    } on PlatformException catch (e) {
      state = state.copyWith(
        error: e.message ?? '焦点距離の切り替えに失敗しました',
      );
    } catch (_) {
      state = state.copyWith(error: '焦点距離の切り替えに失敗しました');
    }
  }

  /// チェックアウト：現像待ち状態へ進める
  Future<void> checkOut() async {
    final session = state.activeSession;
    if (session == null) return;

    if (session.isFilmMode) {
      if (!session.isFull) {
        state = state.copyWith(error: 'フィルムは27枚撮り切ってから現像します');
        return;
      }
      final updated = session.copyWith(
        status: FilmStatus.developing,
        developReadyAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await DatabaseHelper.updateFilmSession(updated);
      state = state.copyWith(
        activeSession: null,
        error: '現像は1時間後に始められます。アルバムの「現像待ち」から開けます',
      );
      return;
    }

    final updated = session.copyWith(status: FilmStatus.developed);
    await DatabaseHelper.updateFilmSession(updated);
    state = state.copyWith(activeSession: null, error: null);
  }

  Future<void> setCaptureMode(CaptureMode mode) async {
    final session = state.activeSession;
    if (session == null || session.captureMode == mode) return;
    final updated = session.copyWith(captureMode: mode);
    await DatabaseHelper.updateFilmSession(updated);
    state = state.copyWith(activeSession: updated, error: null);
  }

  Future<void> prepareForFilmStart() async {
    final session = state.activeSession;
    if (session == null) return;

    if (session.isInstantMode && session.photoCount == 0) {
      await DatabaseHelper.deleteFilmSession(session.sessionId);
    } else if (session.isInstantMode) {
      final updated = session.copyWith(status: FilmStatus.developed);
      await DatabaseHelper.updateFilmSession(updated);
    }

    state = state.copyWith(activeSession: null, error: null);
  }

  void clearCompletedRollPrompt() {
    state = state.copyWith(clearCompletedRollSession: true);
  }

  Future<void> stashFilmAndStartInstant() async {
    final session = state.activeSession;
    if (session == null || !session.isFilmMode) return;

    final shelved = session.copyWith(status: FilmStatus.shelved);
    await DatabaseHelper.updateFilmSession(shelved);

    final instantSession = FilmSession(
      sessionId: const Uuid().v4(),
      title: session.title,
      locationName: session.locationName,
      lat: session.lat,
      lng: session.lng,
      zooId: session.zooId,
      date: DateTime.now(),
      captureMode: CaptureMode.instant,
    );
    await DatabaseHelper.insertFilmSession(instantSession);
    state = state.copyWith(activeSession: instantSession, error: null);
  }

  Future<bool> restoreShelvedFilm(String sessionId) async {
    final current = await DatabaseHelper.getActiveSession();
    final target = await DatabaseHelper.getFilmSession(sessionId);
    if (target == null) return false;
    if (!target.canRestoreNow()) {
      state = state.copyWith(error: 'このフィルムは1週間に1回だけ復元できます');
      return false;
    }

    if (current != null) {
      final updatedCurrent = current.isInstantMode
          ? current.copyWith(status: FilmStatus.developed)
          : current.copyWith(status: FilmStatus.shelved);
      await DatabaseHelper.updateFilmSession(updatedCurrent);
    }

    final restored = target.copyWith(
      status: FilmStatus.shooting,
      lastRestoredAt: DateTime.now(),
    );
    await DatabaseHelper.updateFilmSession(restored);
    state = state.copyWith(activeSession: restored, error: null);
    return true;
  }

  void cycleAspectRatio() {
    final idx = AspectRatioMode.values.indexOf(state.aspectRatio);
    final next =
        AspectRatioMode.values[(idx + 1) % AspectRatioMode.values.length];
    state = state.copyWith(aspectRatio: next);
  }

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

  /// 撮影 → 画像保存（セッション不要）
  Future<void> takePicture() async {
    if (!state.isCameraReady || state.isCapturing) return;
    final session = state.activeSession;
    if (session == null) {
      state = state.copyWith(
        error: 'フィルムを作成してください。撮影したフィルムは1時間後に見ることができます。',
      );
      return;
    }

    state = state.copyWith(isCapturing: true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${dir.path}/zoosmap/photos');
      await photoDir.create(recursive: true);

      final photoId = const Uuid().v4();
      final savePath = '${photoDir.path}/$photoId.jpg';

      String savedPath;
      final currentPreviewPath = state.simulatorPreviewPath;
      if (state.isSimulatorMode) {
        savedPath = await _generateSimulatorPhoto(
          savePath,
          currentPreviewPath,
          focalLength: state.focalLength,
        );
      } else {
        final result = await CameraService.takePicture(savePath);
        if (result == null) throw Exception('撮影に失敗しました');
        savedPath = result;
      }

      if (session.isFilmMode) {
        final bakedPath = savePath.replaceAll('.jpg', '_film.png');
        try {
          savedPath = await FilmStillService.bakeFilmPhoto(
            inputPath: savedPath,
            outputPath: bakedPath,
            lutType: state.selectedLut,
            intensity: state.lutIntensity,
          );
          final rawFile = File(savePath);
          if (rawFile.existsSync()) {
            await rawFile.delete();
          }
        } catch (_) {
          // フィルム焼き込みに失敗しても写真自体は失わない。
        }
      }

      final photo = Photo(
        photoId: photoId,
        sessionId: session.sessionId,
        imagePath: savedPath,
        timestamp: DateTime.now(),
      );
      await DatabaseHelper.insertPhoto(photo);
      _ref.read(photoPathsProvider.notifier).add(savedPath);

      final refreshedSession =
          await DatabaseHelper.getFilmSession(session.sessionId) ??
              session.copyWith(photoCount: session.photoCount + 1);

      if (refreshedSession.isFilmMode && refreshedSession.isFull) {
        final developing = refreshedSession.copyWith(
          status: FilmStatus.developing,
          developReadyAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await DatabaseHelper.updateFilmSession(developing);
        state = state.copyWith(
          activeSession: null,
          completedRollSession: developing,
          isCapturing: false,
          error: null,
          simulatorPreviewPath:
              pickRandomMockPhotoPath(excluding: currentPreviewPath),
        );
        return;
      }

      state = state.copyWith(
        activeSession: refreshedSession,
        isCapturing: false,
        error: enforceAnalogExperienceRules &&
                refreshedSession.isInstantMode &&
                refreshedSession.instantBatteryRemaining == 0
            ? '電池が切れました。記録を閉じるまで撮影できません'
            : null,
        simulatorPreviewPath:
            pickRandomMockPhotoPath(excluding: currentPreviewPath),
      );
    } on PlatformException catch (e) {
      state = state.copyWith(isCapturing: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isCapturing: false, error: e.toString());
    }
  }

  /// シミュレーター用：実写真をコピーして保存
  Future<String> _generateSimulatorPhoto(
    String savePath,
    String? sourcePath, {
    required FocalLength focalLength,
  }) async {
    final resolvedSource = sourcePath ?? primaryMockPhotoPath();
    if (resolvedSource == null) {
      throw Exception('モック画像が見つかりません');
    }

    final sourceFile = File(resolvedSource);
    final outputPath = savePath.replaceAll('.jpg', '_sim.jpg');
    await File(outputPath).parent.create(recursive: true);
    await sourceFile.copy(outputPath);
    return outputPath;
  }
}

final cameraProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier(ref);
});
