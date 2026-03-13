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

class CameraState {
  final FilmSession? activeSession;
  final bool isCameraReady;
  final bool isCapturing;
  final bool flashEnabled;
  final int? textureId;
  final String? error;

  const CameraState({
    this.activeSession,
    this.isCameraReady = false,
    this.isCapturing = false,
    this.flashEnabled = false,
    this.textureId,
    this.error,
  });

  int get remainingShots =>
      (activeSession?.remainingShots) ?? FilmSession.maxPhotos;

  bool get canShoot =>
      activeSession != null &&
      !activeSession!.isFull &&
      activeSession!.status == FilmStatus.shooting &&
      isCameraReady &&
      !isCapturing;

  CameraState copyWith({
    FilmSession? activeSession,
    bool? isCameraReady,
    bool? isCapturing,
    bool? flashEnabled,
    int? textureId,
    String? error,
  }) {
    return CameraState(
      activeSession: activeSession ?? this.activeSession,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isCapturing: isCapturing ?? this.isCapturing,
      flashEnabled: flashEnabled ?? this.flashEnabled,
      textureId: textureId ?? this.textureId,
      error: error,
    );
  }
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

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

  /// 撮影 → 画像保存 → DBに記録
  Future<void> takePicture() async {
    if (!state.canShoot) return;

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

      // 位置情報をセッションに更新（初回のみ）
      if (state.activeSession!.lat == null && position != null) {
        final updated = state.activeSession!.copyWith(
          lat: position.latitude,
          lng: position.longitude,
        );
        await DatabaseHelper.updateFilmSession(updated);
        state = state.copyWith(activeSession: updated);
      }

      // セッション再読み込み（photo_count 更新）
      final updated = await DatabaseHelper.getFilmSession(
        state.activeSession!.sessionId,
      );
      state = state.copyWith(
        activeSession: updated,
        isCapturing: false,
      );

      // 27枚達した場合は自動で現像フローへ
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
