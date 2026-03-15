import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/experience_rules.dart';
import '../../core/database/database_helper.dart';
import '../../core/mock/mock_photo_library.dart';
import '../../core/models/film_session.dart';
import '../../core/models/photo.dart';
import '../../core/navigation/main_tab_provider.dart';
import '../../core/services/camera_service.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/mock_photo.dart';
import '../checkin/checkin_screen.dart';
import '../develop/develop_screen.dart';
import 'camera_notifier.dart';
import 'film_session_notifier.dart';
import 'widgets/film_preview.dart';
import 'widgets/lut_selector.dart';
import 'widgets/shutter_button.dart';

LutType _effectiveLutForSession(FilmSession? session, LutType selectedLut) {
  return selectedLut;
}

double _effectiveLutIntensityForSession(
  FilmSession? session,
  double selectedIntensity,
) {
  return selectedIntensity;
}

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final CameraNotifier _cameraNotifier;
  final GlobalKey _previewAreaKey = GlobalKey();
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;

  Offset? _focusPoint;
  late AnimationController _focusController;
  late Animation<double> _focusScale;
  late Animation<double> _focusOpacity;

  bool _showLutPanel = false;
  bool _isControlDockOpen = false;

  @override
  void initState() {
    super.initState();
    _cameraNotifier = ref.read(cameraProvider.notifier);
    WidgetsBinding.instance.addObserver(this);

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _focusScale = Tween<double>(begin: 1.6, end: 1.0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeOut),
    );
    _focusOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _cameraNotifier.loadActiveSession();
      await _cameraNotifier.initializeCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashController.dispose();
    _focusController.dispose();
    _cameraNotifier.disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _cameraNotifier.disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _cameraNotifier.initializeCamera();
    }
  }

  void _onShutter() {
    final cs = ref.read(cameraProvider);
    if (cs.timerMode == TimerMode.off) {
      _flashController.forward().then((_) => _flashController.reverse());
    }
    HapticFeedback.mediumImpact();
    ref.read(cameraProvider.notifier).triggerShutter();
  }

  void _onTapUp(TapUpDetails details) {
    final cs = ref.read(cameraProvider);
    if (!cs.isCameraReady) return;
    final size = _previewAreaKey.currentContext?.size;
    if (size == null) return;
    final tapPos = details.localPosition;
    final cropRect = _resolvePreviewCropRect(
      size,
      cs.aspectRatio,
      MediaQuery.orientationOf(context),
    );
    if (!cropRect.contains(tapPos)) return;
    CameraService.setFocusPoint(
      (tapPos.dx / size.width).clamp(0.0, 1.0),
      (tapPos.dy / size.height).clamp(0.0, 1.0),
    );
    setState(() => _focusPoint = tapPos);
    _focusController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    });
  }

  void _showSettingsSheet(BuildContext context, CameraState cs) {
    final canEditInstantLook = cs.activeSession?.isInstantMode == true;
    var showGrid = cs.showGrid;
    var flashEnabled = cs.flashEnabled;
    var lightLeak = cs.lightLeak;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // グリッド
                  _SheetRow(
                    icon: Icons.grid_on_outlined,
                    label: 'グリッドライン',
                    trailing: Switch(
                      value: showGrid,
                      onChanged: (_) {
                        ref.read(cameraProvider.notifier).toggleGrid();
                        showGrid = !showGrid;
                        setSheetState(() {});
                      },
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white12,
                    ),
                  ),
                  // フラッシュ
                  _SheetRow(
                    icon: flashEnabled ? Icons.flash_on : Icons.flash_off,
                    label: 'フラッシュ',
                    iconColor: flashEnabled ? Colors.yellow : Colors.white54,
                    trailing: Switch(
                      value: flashEnabled,
                      onChanged: (_) {
                        ref.read(cameraProvider.notifier).toggleFlash();
                        flashEnabled = !flashEnabled;
                        setSheetState(() {});
                      },
                      activeThumbColor: Colors.yellow,
                      inactiveTrackColor: Colors.white12,
                    ),
                  ),
                  // ライトリーク
                  _SheetRow(
                    icon: Icons.flare,
                    label: '光漏れ（ライトリーク）',
                    iconColor: lightLeak != LightLeakStrength.none
                        ? Colors.orange
                        : Colors.white54,
                    trailing: _LightLeakSegment(
                      current: lightLeak,
                      onSelect: (v) {
                        ref.read(cameraProvider.notifier).setLightLeak(v);
                        lightLeak = v;
                        setSheetState(() {});
                      },
                    ),
                  ),
                  // LUTフィルム
                  if (canEditInstantLook)
                    _SheetRow(
                      icon: Icons.photo_filter,
                      label: '現像後の色味',
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _showLutPanel = !_showLutPanel);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCheckOutDialog() {
    final session = ref.read(cameraProvider).activeSession;
    if (session == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                session.isFilmMode
                    ? '${session.photoCount} / ${FilmSession.maxPhotos} 枚'
                    : '${session.photoCount} 枚を記録しました',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              if (session.isFilmMode && !session.isFull) ...[
                Text(
                  'あと ${session.remainingShots} 枚で現像できます。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: session.canDevelop
                      ? () async {
                          await ref.read(cameraProvider.notifier).checkOut();
                          if (mounted) Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    session.isFilmMode
                        ? session.isFull
                            ? '現像へ進む'
                            : 'あと ${session.remainingShots} 枚'
                        : '記録を閉じる',
                    style: const TextStyle(fontSize: 15, letterSpacing: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRollStatusDialog(BuildContext context, CameraState cs) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _RollStatusCard(
                session: cs.activeSession,
                isCapturing: cs.isCapturing,
                selectedLut: _effectiveLutForSession(
                  cs.activeSession,
                  cs.selectedLut,
                ),
                aspectRatio: cs.aspectRatio,
                onSetMode: (mode) async {
                  final session = cs.activeSession;
                  if (session?.isFilmMode == true &&
                      mode == CaptureMode.instant) {
                    Navigator.pop(dialogContext);
                    _showSwitchToInstantWarning();
                    return;
                  }
                  if (session?.isInstantMode == true &&
                      mode == CaptureMode.film) {
                    Navigator.pop(dialogContext);
                    _showSwitchToFilmWarning();
                    return;
                  }
                  await ref.read(cameraProvider.notifier).setCaptureMode(mode);
                },
                onOpenLut: () {
                  Navigator.pop(dialogContext);
                  HapticFeedback.selectionClick();
                  setState(() => _showLutPanel = true);
                },
                onOpenCheckIn: () {
                  Navigator.pop(dialogContext);
                  Navigator.of(context).push(
                    DarkFadeRoute(page: const CheckInScreen()),
                  );
                },
                onStartInstant: () async {
                  Navigator.pop(dialogContext);
                  await ref.read(cameraProvider.notifier).startInstantSession();
                },
                onOpenAlbum: () {
                  Navigator.pop(dialogContext);
                  ref.read(mainTabIndexProvider.notifier).state = 1;
                },
                onCheckOut: cs.activeSession == null
                    ? null
                    : !(cs.activeSession?.canDevelop ?? false)
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _showCheckOutDialog();
                          },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSwitchToInstantWarning() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'フィルムをしまいますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'フィルムロールはカメラ画面から消えます。ただし削除はされず、設定画面から復元できます。復元は1本ごとに7日に1回だけです。',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(cameraProvider.notifier)
                  .stashFilmAndStartInstant();
            },
            child: const Text('インスタントへ切替'),
          ),
        ],
      ),
    );
  }

  void _showSwitchToFilmWarning() {
    final session = ref.read(cameraProvider).activeSession;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'フィルムを始めますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${session == null || session.photoCount == 0 ? 'いまのインスタント記録を閉じて、新しいフィルムを作成します。' : 'いまのインスタント記録はアルバムに残したまま閉じて、新しいフィルム作成へ進みます。'}\n\nフィルムは27枚撮り切ったあと、1時間待って現像します。',
          style: const TextStyle(color: Colors.white70, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() {
                _showLutPanel = false;
                _isControlDockOpen = false;
              });
              await ref.read(cameraProvider.notifier).prepareForFilmStart();
              if (!mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).push(
                  DarkFadeRoute(page: const CheckInScreen()),
                );
              });
            },
            child: const Text('フィルムを作る'),
          ),
        ],
      ),
    );
  }

  void _showRollCompletedActions(FilmSession session) {
    final continueWithInstant =
        enforceAnalogExperienceRules && session.isFilmMode;
    final effectiveLut = _effectiveLutForSession(
      session,
      ref.read(cameraProvider).selectedLut,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ロールを使い切りました',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                continueWithInstant
                    ? '撮影したフィルムは1時間後に見ることができます。今日はフィルムを使い切ったので、続けるならインスタントへ切り替えます。'
                    : '撮影したフィルムは1時間後に見ることができます。次は新しいフィルムを始めるか、現像作業へ進めます。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    if (continueWithInstant) {
                      await ref
                          .read(filmSessionProvider.notifier)
                          .createSession(
                            title: session.locationName ?? session.title,
                            locationName: session.locationName,
                            lat: session.lat,
                            lng: session.lng,
                            zooId: session.zooId,
                            captureMode: CaptureMode.instant,
                          );
                      await ref
                          .read(cameraProvider.notifier)
                          .loadActiveSession();
                      ref
                          .read(cameraProvider.notifier)
                          .clearCompletedRollPrompt();
                      return;
                    }
                    // clearCompletedRollPrompt はここではしない。
                    // CheckInScreen で新フィルムが作成 → loadActiveSession が
                    // 自動クリアする。戻るだけなら overlay を維持する。
                    Navigator.of(context).push(
                      DarkFadeRoute(page: const CheckInScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    continueWithInstant ? 'この場所でインスタントを始める' : '新しいフィルムをつくる',
                    style: const TextStyle(letterSpacing: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ref
                        .read(cameraProvider.notifier)
                        .clearCompletedRollPrompt();
                    Navigator.of(context).push(
                      DarkFadeRoute(
                        page: DevelopScreen(
                          sessionId: session.sessionId,
                          lutType: effectiveLut,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '現像作業へ',
                    style: TextStyle(letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(cameraProvider);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompactHeight = screenHeight < 760;
    final canEditInstantLook = cs.activeSession?.isInstantMode == true;
    final showLutPanel =
        _showLutPanel && canEditInstantLook && cs.isCameraReady;

    // エラーメッセージを 2.5 秒後に自動消去
    ref.listen<String?>(
      cameraProvider.select((s) => s.error),
      (prev, next) {
        if (next != null && prev != next) {
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) ref.read(cameraProvider.notifier).clearError();
          });
        }
      },
    );

    // ロール完了時は _RollCompletedOverlay がビューファインダーに表示される。
    // 自動でボトムシートを出すと二重表示になるため auto-trigger を廃止。
    // ユーザーは Overlay の「次のステップへ」ボタンからシートを開く。

    void openCheckIn() {
      Navigator.of(context).push(
        DarkFadeRoute(page: const CheckInScreen()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: isCompactHeight ? 8 : 12),

            // ── プレビュー（ラウンドコーナー）──────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AspectRatioPreviewViewport(
                        key: _previewAreaKey,
                        aspectRatio: cs.aspectRatio,
                        orientation: MediaQuery.orientationOf(context),
                        child: _buildPreview(cs),
                      ),
                      IgnorePointer(
                        child: FadeTransition(
                          opacity: _flashOpacity,
                          child: const ColoredBox(color: Colors.white),
                        ),
                      ),
                      _AspectRatioCropOverlay(
                        aspectRatio: cs.aspectRatio,
                        orientation: MediaQuery.orientationOf(context),
                      ),
                      Positioned(
                        top: 14,
                        left: 18,
                        right: 18,
                        child: Row(
                          children: [
                            const SizedBox(width: 46),
                            const Spacer(),
                            if (cs.completedRollSession == null &&
                                cs.activeSession != null)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showRollStatusDialog(context, cs),
                                child: _SessionIndicator(
                                  session: cs.activeSession!,
                                  isCapturing: cs.isCapturing,
                                ),
                              ),
                            const Spacer(),
                            const SizedBox(width: 46),
                          ],
                        ),
                      ),
                      if (_isControlDockOpen)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () =>
                                setState(() => _isControlDockOpen = false),
                          ),
                        ),
                      Positioned(
                        right: 16,
                        bottom: 18,
                        child: _ControlDock(
                          isOpen: _isControlDockOpen,
                          aspectRatioLabel: _aspectRatioLabel(
                            cs.aspectRatio,
                            MediaQuery.orientationOf(context),
                          ),
                          timerLabel: cs.timerMode.label,
                          timerActive: cs.timerMode != TimerMode.off,
                          lutActive: showLutPanel,
                          showLutButton: canEditInstantLook,
                          flashActive: cs.flashEnabled,
                          onToggle: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _isControlDockOpen = !_isControlDockOpen,
                            );
                          },
                          onAspectRatioTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(cameraProvider.notifier)
                                .cycleAspectRatio();
                          },
                          onTimerTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(cameraProvider.notifier).cycleTimerMode();
                          },
                          onLutTap: () {
                            if (!canEditInstantLook) return;
                            HapticFeedback.selectionClick();
                            setState(() {
                              _showLutPanel = !_showLutPanel;
                            });
                          },
                          onFlashTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(cameraProvider.notifier).toggleFlash();
                          },
                          onSettingsTap: () {
                            HapticFeedback.selectionClick();
                            _showSettingsSheet(context, cs);
                          },
                        ),
                      ),
                      if (showLutPanel)
                        Positioned(
                          left: 12,
                          right: 84,
                          bottom: isCompactHeight ? 138 : 150,
                          child: _InstantLutPanel(
                            selectedLut: cs.selectedLut,
                            lutIntensity: cs.lutIntensity,
                            onClose: () =>
                                setState(() => _showLutPanel = false),
                            onSelected: (lut) =>
                                ref.read(cameraProvider.notifier).setLut(lut),
                            onIntensityChanged: (value) => ref
                                .read(cameraProvider.notifier)
                                .setLutIntensity(value),
                          ),
                        ),
                      if (cs.completedRollSession != null)
                        _RollCompletedOverlay(
                          session: cs.completedRollSession!,
                          onNextTap: () => _showRollCompletedActions(
                            cs.completedRollSession!,
                          ),
                        )
                      else if (cs.activeSession == null)
                        _NoFilmLoadedHint(
                          onStartTap: openCheckIn,
                          onInstantTap: () async {
                            await ref
                                .read(cameraProvider.notifier)
                                .startInstantSession();
                          },
                        ),
                      // タイマーカウントダウン
                      if (cs.timerCountdown != null)
                        _TimerCountdownOverlay(
                          count: cs.timerCountdown!,
                          onCancel: () {
                            HapticFeedback.lightImpact();
                            ref.read(cameraProvider.notifier).cancelTimer();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: isCompactHeight ? 8 : 12),

            if (cs.error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  cs.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE57373),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                isCompactHeight ? 12 : 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LensSelector(
                    focal: cs.focalLength,
                    compact: isCompactHeight,
                    onSelect: (fl) {
                      HapticFeedback.selectionClick();
                      ref.read(cameraProvider.notifier).setFocalLength(fl);
                    },
                  ),
                  SizedBox(height: isCompactHeight ? 8 : 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShutterButton(
                        isCapturing: cs.isCapturing,
                        onPressed: cs.canShoot ? _onShutter : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(CameraState cs) {
    if (!cs.isCameraReady) return const _CameraLoadingView();

    final targetScale = cs.focalLength.simulatorZoom;
    final effectiveLut = _effectiveLutForSession(
      cs.activeSession,
      cs.selectedLut,
    );
    final effectiveLutIntensity = _effectiveLutIntensityForSession(
      cs.activeSession,
      cs.lutIntensity,
    );

    if (cs.isSimulatorMode) {
      final previewPath = cs.simulatorPreviewPath ?? primaryMockPhotoPath();
      return AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: previewPath == null
            ? const SizedBox.expand(child: MockPhotoView())
            : SizedBox.expand(
                child: FilmProcessedSurface(
                  lutType: effectiveLut,
                  lutIntensity: effectiveLutIntensity,
                  animated: true,
                  child: Image.file(
                    File(previewPath),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const MockPhotoView(),
                  ),
                ),
              ),
      );
    }

    // Real camera: no scale transform — iOS/Android driver handles lens switching.
    return FilmPreviewWidget(
      textureId: cs.textureId!,
      lutType: effectiveLut,
      lutIntensity: effectiveLutIntensity,
      showGrid: cs.showGrid,
      lightLeak: cs.lightLeak,
      onTapUp: _onTapUp,
      focusIndicator: _focusPoint != null
          ? Positioned(
              left: _focusPoint!.dx - 32,
              top: _focusPoint!.dy - 32,
              child: AnimatedBuilder(
                animation: _focusController,
                builder: (_, __) => Transform.scale(
                  scale: _focusScale.value,
                  child: Opacity(
                    opacity: _focusOpacity.value,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: CustomPaint(painter: _FocusReticlePainter()),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── セッションインジケーター ──────────────────────────────────

class _SessionIndicator extends StatelessWidget {
  final FilmSession session;
  final bool isCapturing;

  const _SessionIndicator({
    required this.session,
    required this.isCapturing,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.black.withValues(alpha: 0.34);
    if (session.isInstantMode) {
      return Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BatteryPict(remaining: session.instantBatteryRemaining),
            const SizedBox(width: 6),
            Text(
              '${session.instantBatteryRemaining}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }
    // フィルムカメラらしく「撮影済み枚数 / 合計」で数え上げ表示
    // isCapturing 中は +1 して応答性を確保
    final predictedTaken = FilmSession.maxPhotos -
        _predictedRemainingShots(session, isCapturing: isCapturing);
    final frameNum =
        predictedTaken.clamp(0, FilmSession.maxPhotos);
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_roll_outlined,
            color: Colors.white54,
            size: 12,
          ),
          const SizedBox(width: 5),
          Text(
            '${frameNum.toString().padLeft(2, '0')} / ${FilmSession.maxPhotos}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white38,
            size: 14,
          ),
        ],
      ),
    );
  }
}

class _NoFilmLoadedHint extends StatelessWidget {
  final VoidCallback onStartTap;
  final Future<void> Function() onInstantTap;

  const _NoFilmLoadedHint({
    required this.onStartTap,
    required this.onInstantTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: MockPhotoView(opacity: 0.78),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ロールを作って撮影を始めましょう',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '今日フィルムを作れない日でも、インスタントならすぐ始められます。',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        onPressed: onStartTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'ロールをつくる',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: onInstantTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9FE2DC),
                          side: BorderSide(
                            color:
                                const Color(0xFF77C8C1).withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'インスタント',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RollCompletedOverlay extends StatelessWidget {
  final FilmSession session;
  final VoidCallback onNextTap;

  const _RollCompletedOverlay({
    required this.session,
    required this.onNextTap,
  });

  @override
  Widget build(BuildContext context) {
    final canDevelop = session.isDevelopReady;
    final wait = session.remainingDevelopWait;
    String waitText = '';
    if (!canDevelop && wait != null && !wait.isNegative) {
      final h = wait.inHours;
      final m = wait.inMinutes % 60;
      waitText = h > 0 ? '$h時間$m分後に現像できます' : '$m分後に現像できます';
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.82),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_roll_outlined,
                  color: Color(0xFFFFD580),
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  'フィルムを撮り切りました',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  canDevelop
                      ? '現像の準備ができました'
                      : waitText.isNotEmpty
                          ? waitText
                          : 'しばらく待つと現像できます',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onNextTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD580),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      canDevelop ? '現像する' : '次のステップへ',
                      style: const TextStyle(letterSpacing: 1.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RollStatusCard extends StatelessWidget {
  final FilmSession? session;
  final bool isCapturing;
  final LutType selectedLut;
  final AspectRatioMode aspectRatio;
  final Future<void> Function(CaptureMode) onSetMode;
  final VoidCallback onOpenLut;
  final VoidCallback onOpenCheckIn;
  final Future<void> Function() onStartInstant;
  final VoidCallback onOpenAlbum;
  final VoidCallback? onCheckOut;

  const _RollStatusCard({
    required this.session,
    required this.isCapturing,
    required this.selectedLut,
    required this.aspectRatio,
    required this.onSetMode,
    required this.onOpenLut,
    required this.onOpenCheckIn,
    required this.onStartInstant,
    required this.onOpenAlbum,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    if (this.session == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF131313),
              Color(0xFF0A0A0A),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '撮影モード',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'まだロールがありません',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'フィルムを始めるか、そのままインスタントで撮るかをここから選べます。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: _ModeSummaryCard(
                    title: 'フィルム',
                    body: '27枚で残す一本。撮り切ったあと1時間待って現像します。',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _ModeSummaryCard(
                    title: 'インスタント',
                    body: 'すぐ撮れて、そのままアルバムに残ります。',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenCheckIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '今日のロールをつくる',
                      style: TextStyle(letterSpacing: 1.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onStartInstant,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: const Color(0xFF77C8C1).withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'インスタントを始める',
                      style: TextStyle(letterSpacing: 1.1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onOpenAlbum,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('アルバムを見る'),
              ),
            ),
          ],
        ),
      );
    }

    // ここ以降 session は non-null
    final session = this.session!;
    final remaining = _predictedRemainingShots(
      session,
      isCapturing: isCapturing,
    );
    final used = FilmSession.maxPhotos - remaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF131313),
            Color(0xFF0A0A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CaptureModeToggle(
            current: session.captureMode,
            onChanged: onSetMode,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  session.isFilmMode ? 'ROLL LOADED' : 'INSTANT READY',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (session.isFilmMode)
                Text(
                  '${used.toString().padLeft(2, '0')} / ${FilmSession.maxPhotos}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BatteryPict(remaining: session.instantBatteryRemaining),
                    const SizedBox(width: 6),
                    Text(
                      '${session.instantBatteryRemaining}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (session.theme?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'THEME  ${session.theme!}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 1.7,
              ),
            ),
          ],
          if (session.locationName?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              session.locationName!,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: session.isFilmMode
                    ? Column(
                        key: const ValueKey('film-summary'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: used / FilmSession.maxPhotos,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '一本のロールとして残し、撮り切ったあと1時間待って現像します。残り $remaining 枚です。',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      )
                    : Align(
                        key: const ValueKey('instant-summary'),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          enforceAnalogExperienceRules
                              ? 'インスタントはすぐ使えます。電池は ${session.instantBatteryRemaining}% です。'
                              : '気軽に残したい場面では、撮った瞬間にこの訪問の思い出として残せます。',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (session.isFilmModeLocked) ...[
            const SizedBox(height: 10),
            Text(
              session.isFilmLookLocked
                  ? 'このロールは撮り切るまでモードもルックも固定です。'
                  : 'このロールは撮り切るまでモードを変更できません。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RollMetaChip(
                label: 'ルック',
                value: selectedLut.subtitle,
              ),
              _RollMetaChip(label: '比率', value: aspectRatio.label),
              _RollMetaChip(
                label: session.isFilmMode
                    ? '残り'
                    : enforceAnalogExperienceRules
                        ? '電池'
                        : '枚数',
                value: session.isFilmMode
                    ? remaining.toString().padLeft(2, '0')
                    : enforceAnalogExperienceRules
                        ? '${session.instantBatteryRemaining}%'
                        : session.photoCount.toString().padLeft(2, '0'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Photo>>(
            future: DatabaseHelper.getPhotosForSession(session.sessionId),
            builder: (context, snapshot) {
              final photos = snapshot.data ?? const <Photo>[];
              if (photos.isEmpty) {
                return Text(
                  session.isFilmMode
                      ? '最初の1枚を撮ると、このロールにサムネイルが並びます。'
                      : '最初の1枚を撮ると、この記録のサムネイルがここに並びます。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 12,
                    height: 1.5,
                  ),
                );
              }

              final previewPhotos = photos.reversed.take(4).toList().reversed;
              return Row(
                children: previewPhotos.map((photo) {
                  final file = File(photo.imagePath);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      height: 52,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      child: file.existsSync()
                          ? Image.file(file, fit: BoxFit.cover)
                          : const Icon(
                              Icons.image_not_supported,
                              color: Colors.white24,
                              size: 16,
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenAlbum,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'アルバムを見る',
                    style: TextStyle(letterSpacing: 1.2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: session.isInstantMode ||
                        session.isFilmLookLocked ||
                        session.isFull
                    ? FilledButton(
                        onPressed: onCheckOut,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          session.isFilmMode
                              ? session.isFull
                                  ? '現像へ進む'
                                  : 'あと ${session.remainingShots} 枚'
                              : '記録を閉じる',
                          style: const TextStyle(letterSpacing: 1.5),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: onOpenLut,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '見た目を調整',
                          style: TextStyle(letterSpacing: 1.2),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int _predictedRemainingShots(
  FilmSession session, {
  required bool isCapturing,
}) {
  if (!session.isFilmMode) return session.remainingShots;
  if (!isCapturing) return session.remainingShots;
  return (session.remainingShots - 1).clamp(0, FilmSession.maxPhotos);
}

class _RollMetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _RollMetaChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSummaryCard extends StatelessWidget {
  final String title;
  final String body;

  const _ModeSummaryCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureModeToggle extends StatelessWidget {
  final CaptureMode current;
  final Future<void> Function(CaptureMode) onChanged;

  const _CaptureModeToggle({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFilm = current == CaptureMode.film;
    final statusLabel = isFilm ? '現在はフィルム' : '現在はインスタント';
    final statusBody = isFilm
        ? '27枚を撮り切ってから現像する流れです。インスタントを押すと、いまのフィルムをしまって切り替えます。'
        : '撮るとすぐアルバムに入ります。フィルムを押すと、新しいロール作成へ進みます。';

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CaptureModeButton(
                  icon: Icons.camera_roll_outlined,
                  label: 'フィルム',
                  subtitle: '27枚で1本',
                  detail: current == CaptureMode.film ? 'いま撮影中' : '新しいロールを作る',
                  accentColor: const Color(0xFFD8B26B),
                  selected: current == CaptureMode.film,
                  onTap: () => onChanged(CaptureMode.film),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CaptureModeButton(
                  icon: Icons.bolt_rounded,
                  label: 'インスタント',
                  subtitle: 'すぐ残る',
                  detail: current == CaptureMode.instant ? 'いま撮影中' : 'すぐ撮影へ切替',
                  accentColor: const Color(0xFF77C8C1),
                  selected: current == CaptureMode.instant,
                  onTap: () => onChanged(CaptureMode.instant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilm
                        ? const Color(0xFFD8B26B)
                        : const Color(0xFF77C8C1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusBody,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontSize: 10,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String detail;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _CaptureModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.detail,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.16)
                : const Color(0xFF050505),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.78)
                  : Colors.white10,
              width: selected ? 1.1 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? accentColor : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white60,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '選択中',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected ? Colors.white70 : Colors.white54,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: selected ? Colors.white60 : Colors.white38,
                  fontSize: 9,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryPict extends StatelessWidget {
  final int remaining;

  const _BatteryPict({required this.remaining});

  IconData get _icon {
    if (remaining <= 5) return Icons.battery_alert_rounded;
    if (remaining <= 15) return Icons.battery_1_bar_rounded;
    if (remaining <= 35) return Icons.battery_2_bar_rounded;
    if (remaining <= 55) return Icons.battery_3_bar_rounded;
    if (remaining <= 75) return Icons.battery_4_bar_rounded;
    if (remaining <= 90) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      _icon,
      size: 18,
      color: remaining <= 15 ? const Color(0xFFE8A16A) : Colors.white70,
    );
  }
}

// ── アスペクト比クロップオーバーレイ ─────────────────────────

class _AspectRatioCropOverlay extends StatelessWidget {
  final AspectRatioMode aspectRatio;
  final Orientation orientation;

  const _AspectRatioCropOverlay({
    required this.aspectRatio,
    required this.orientation,
  });

  @override
  Widget build(BuildContext context) {
    if (aspectRatio == AspectRatioMode.r4_3) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final cropRect = _resolvePreviewCropRect(
        Size(constraints.maxWidth, constraints.maxHeight),
        aspectRatio,
        orientation,
      );
      return IgnorePointer(
        child: CustomPaint(
          painter: _CropMaskPainter(cropRect: cropRect),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        ),
      );
    });
  }
}

class _AspectRatioPreviewViewport extends StatelessWidget {
  final AspectRatioMode aspectRatio;
  final Orientation orientation;
  final Widget child;

  const _AspectRatioPreviewViewport({
    super.key,
    required this.aspectRatio,
    required this.orientation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final cropRect = _resolvePreviewCropRect(
          size,
          aspectRatio,
          orientation,
        );
        if (cropRect == Offset.zero & size) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            ClipPath(
              clipper: _PreviewCropClipper(cropRect),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class _PreviewCropClipper extends CustomClipper<Path> {
  final Rect cropRect;

  const _PreviewCropClipper(this.cropRect);

  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(14)));

  @override
  bool shouldReclip(_PreviewCropClipper oldClipper) {
    return oldClipper.cropRect != cropRect;
  }
}

class _CropMaskPainter extends CustomPainter {
  final Rect cropRect;

  const _CropMaskPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0x7A000000);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final window = RRect.fromRectAndRadius(
      cropRect,
      const Radius.circular(14),
    );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawRRect(window, clearPaint);
    canvas.drawRRect(window, framePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CropMaskPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

String _aspectRatioLabel(
  AspectRatioMode aspectRatio,
  Orientation orientation,
) {
  final isPortrait = orientation == Orientation.portrait;
  return switch (aspectRatio) {
    AspectRatioMode.r4_3 => isPortrait ? '3:4' : '4:3',
    AspectRatioMode.r1_1 => '1:1',
    AspectRatioMode.r16_9 => isPortrait ? '9:16' : '16:9',
  };
}

Rect _resolvePreviewCropRect(
  Size size,
  AspectRatioMode aspectRatio,
  Orientation orientation,
) {
  final isPortrait = orientation == Orientation.portrait;
  final targetAR = switch (aspectRatio) {
    AspectRatioMode.r4_3 => isPortrait ? 3 / 4 : 4 / 3,
    AspectRatioMode.r1_1 => 1.0,
    AspectRatioMode.r16_9 => isPortrait ? 9 / 16 : 16 / 9,
  };
  final screenAR = size.width / size.height;
  double top = 0, bottom = 0, left = 0, right = 0;
  if (targetAR > screenAR) {
    final crop = (size.height - size.width / targetAR) / 2;
    top = crop;
    bottom = crop;
  } else {
    final crop = (size.width - size.height * targetAR) / 2;
    left = crop;
    right = crop;
  }
  return Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
}

// ── 焦点距離セレクター ────────────────────────────────────────

class _LensSelector extends StatelessWidget {
  final FocalLength focal;
  final bool compact;
  final void Function(FocalLength) onSelect;
  const _LensSelector({
    required this.focal,
    required this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: FocalLength.values.map((fl) {
        final sel = fl == focal;
        return GestureDetector(
          onTap: () => onSelect(fl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 10,
              vertical: compact ? 7 : 5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fl.zoomLabel,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white38,
                    fontSize: sel ? 13 : 12,
                    fontWeight: sel ? FontWeight.w500 : FontWeight.w300,
                  ),
                ),
                if (!compact)
                  Text(
                    fl.label,
                    style: TextStyle(
                      color: sel
                          ? Colors.white38
                          : Colors.white.withValues(alpha: 0.18),
                      fontSize: 8,
                    ),
                  ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: sel ? 16 : 0,
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: sel ? 0.72 : 0.0,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OverlayActionButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _OverlayActionButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.6,
          ),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.white70,
          size: 21,
        ),
      ),
    );
  }
}

class _InstantLutPanel extends StatelessWidget {
  final LutType selectedLut;
  final double lutIntensity;
  final VoidCallback onClose;
  final ValueChanged<LutType> onSelected;
  final ValueChanged<double> onIntensityChanged;

  const _InstantLutPanel({
    required this.selectedLut,
    required this.lutIntensity,
    required this.onClose,
    required this.onSelected,
    required this.onIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '現像後の色味',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'ファインダーには反映せず、見返すときにだけ色味を切り替えます。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              LutSelectorWidget(
                selected: selectedLut,
                onSelected: onSelected,
              ),
              _LutIntensitySlider(
                value: lutIntensity,
                onChanged: onIntensityChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlDock extends StatelessWidget {
  final bool isOpen;
  final String aspectRatioLabel;
  final String timerLabel;
  final bool timerActive;
  final bool lutActive;
  final bool showLutButton;
  final bool flashActive;
  final VoidCallback onToggle;
  final VoidCallback onAspectRatioTap;
  final VoidCallback onTimerTap;
  final VoidCallback onLutTap;
  final VoidCallback onFlashTap;
  final VoidCallback onSettingsTap;

  const _ControlDock({
    required this.isOpen,
    required this.aspectRatioLabel,
    required this.timerLabel,
    required this.timerActive,
    required this.lutActive,
    required this.showLutButton,
    required this.flashActive,
    required this.onToggle,
    required this.onAspectRatioTap,
    required this.onTimerTap,
    required this.onLutTap,
    required this.onFlashTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          offset: isOpen ? Offset.zero : const Offset(0.18, 0.08),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: isOpen ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !isOpen,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.6,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DockButton(
                            icon: Icons.crop_rounded,
                            label: aspectRatioLabel,
                            onTap: onAspectRatioTap,
                          ),
                          const SizedBox(height: 8),
                          _DockButton(
                            icon: Icons.timer_outlined,
                            label: timerActive ? timerLabel : 'OFF',
                            active: timerActive,
                            onTap: onTimerTap,
                          ),
                          const SizedBox(height: 8),
                          if (showLutButton) ...[
                            _DockButton(
                              icon: Icons.photo_filter,
                              label: 'LUT',
                              active: lutActive,
                              onTap: onLutTap,
                            ),
                            const SizedBox(height: 8),
                          ],
                          _DockButton(
                            icon:
                                flashActive ? Icons.flash_on : Icons.flash_off,
                            label: 'FLASH',
                            active: flashActive,
                            onTap: onFlashTap,
                          ),
                          const SizedBox(height: 8),
                          _DockButton(
                            icon: Icons.tune,
                            label: 'MENU',
                            onTap: onSettingsTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isOpen ? 0.42 : 0.34),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: isOpen ? 0.24 : 0.14),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isOpen ? 0.28 : 0.16),
                blurRadius: isOpen ? 18 : 10,
                spreadRadius: isOpen ? 2 : 0,
              ),
            ],
          ),
          child: _OverlayActionButton(
            icon: isOpen ? Icons.close_rounded : Icons.tune,
            active: isOpen,
            onTap: onToggle,
          ),
        ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? Colors.white : Colors.white70,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 9,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LUT強度スライダー ─────────────────────────────────────────

class _LutIntensitySlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _LutIntensitySlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        const Text('強さ',
            style: TextStyle(
                color: Colors.white24, fontSize: 9, letterSpacing: 2)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 1.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.white54,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
            ),
            child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9, letterSpacing: 1)),
        ),
      ]),
    );
  }
}

// ── タイマーカウントダウンオーバーレイ ───────────────────────

class _TimerCountdownOverlay extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  const _TimerCountdownOverlay({required this.count, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(count),
                tween: Tween(begin: 1.4, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 80,
                        fontWeight: FontWeight.w100)),
              ),
              const Text('タップでキャンセル',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 12, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── フォーカスレティクル ──────────────────────────────────────

class _FocusReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const corner = 12.0;
    final w = size.width;
    final h = size.height;
    for (final path in [
      Path()
        ..moveTo(0, corner)
        ..lineTo(0, 0)
        ..lineTo(corner, 0),
      Path()
        ..moveTo(w - corner, 0)
        ..lineTo(w, 0)
        ..lineTo(w, corner),
      Path()
        ..moveTo(w, h - corner)
        ..lineTo(w, h)
        ..lineTo(w - corner, h),
      Path()
        ..moveTo(corner, h)
        ..lineTo(0, h)
        ..lineTo(0, h - corner),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FocusReticlePainter _) => false;
}

// ── 設定シート行 ──────────────────────────────────────────────

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SheetRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── ライトリーク選択セグメント ────────────────────────────────

class _LightLeakSegment extends StatelessWidget {
  final LightLeakStrength current;
  final void Function(LightLeakStrength) onSelect;

  const _LightLeakSegment({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = [
      (LightLeakStrength.none, 'OFF'),
      (LightLeakStrength.weak, '弱'),
      (LightLeakStrength.medium, '中'),
      (LightLeakStrength.strong, '強'),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((entry) {
        final (strength, label) = entry;
        final selected = current == strength;
        return GestureDetector(
          onTap: () => onSelect(strength),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? Colors.orange.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.orange : Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── ローディング ─────────────────────────────────────────────

class _CameraLoadingView extends StatelessWidget {
  const _CameraLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white24, strokeWidth: 1),
            ),
            SizedBox(height: 16),
            Text('LOADING',
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w300)),
          ],
        ),
      ),
    );
  }
}
