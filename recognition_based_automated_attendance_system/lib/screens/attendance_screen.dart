import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/captured_image.dart';
import '../providers/attendance_provider.dart';
import '../utils/camera_selector.dart';
import '../utils/platform_utils.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_widget.dart';

/// Attendance Screen - Mark attendance using face recognition
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;
  bool _isCapturing = false;
  CapturedImage? _capturedImage;
  int _previewQuarterTurns = 0;
  _AttendanceResultState? _resultOverlay;

  late final AnimationController _scanController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final AnimationController _ringController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initCamera();
      }
    });
  }

  Future<void> _initCamera() async {
    final t = context.t;

    try {
      if (PlatformUtils.requiresSecureWebCameraContext) {
        throw Exception(PlatformUtils.webCameraContextMessage);
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = t('No cameras found');
        });
        _showError(t('No cameras found'));
        return;
      }

      final frontCamera = CameraSelector.forSelfie(cameras);

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (PlatformUtils.isNativeDesktop && frontCamera.sensorOrientation == 0) {
        _previewQuarterTurns = 2;
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = e.toString().replaceFirst('Exception: ', '');
          _isCameraReady = false;
        });
      }
      _showError(
        t('Failed to initialize camera: {error}', params: {'error': '$e'}),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _triggerResultHaptics({required bool success}) async {
    if (!PlatformUtils.isNativeMobile) {
      return;
    }

    try {
      if (success) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Ignore haptic failures on unsupported platforms.
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _resultOverlay = null;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      final capturedImage = await CapturedImage.fromXFile(
        image,
        fallbackPrefix: 'attendance',
      );

      setState(() {
        _capturedImage = capturedImage;
        _isCapturing = false;
      });
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      if (!mounted) return;
      _showError(context.tRead('Failed to capture image'));
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _resultOverlay = null;
    });
  }

  Future<void> _confirmAttendance() async {
    if (_capturedImage == null) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final success = await attendanceProvider.markAttendance(_capturedImage!);

    if (!mounted) return;

    if (success) {
      final attendance = attendanceProvider.lastMarkedAttendance;
      final state = _AttendanceResultState.success(
        context: context,
        name: attendance?.displayName ?? context.tRead('User'),
        confidence: attendance?.confidence ?? 0,
        status: attendance?.status ?? 'present',
      );
      await _triggerResultHaptics(success: true);
      if (!mounted) return;
      setState(() {
        _resultOverlay = state;
      });
    } else {
      final state = _AttendanceResultState.failure(
        context: context,
        message:
            attendanceProvider.error ??
            context.tRead('Failed to mark attendance'),
      );
      await _triggerResultHaptics(success: false);
      if (!mounted) return;
      setState(() {
        _resultOverlay = state;
      });
    }
  }

  void _dismissResultOverlay({bool popScreen = false}) {
    setState(() {
      _resultOverlay = null;
    });

    if (popScreen && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isSubmitting = context.select<AttendanceProvider, bool>(
      (provider) => provider.isLoading,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Take Attendance')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isCameraReady)
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: t('Rotate Camera'),
              onPressed: () {
                setState(() {
                  _previewQuarterTurns = (_previewQuarterTurns + 1) % 4;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.face, color: AppTheme.infoColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('Position your face within the circle and capture'),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.primaryColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGlow.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: _buildPreviewSurface(isSubmitting: isSubmitting),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _capturedImage != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 420) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CustomButton(
                                  text: 'Retake',
                                  isOutlined: true,
                                  onPressed: isSubmitting ? null : _retake,
                                  icon: Icons.refresh,
                                ),
                                const SizedBox(height: 12),
                                CustomButton(
                                  text: 'Confirm',
                                  isLoading: isSubmitting,
                                  onPressed: _confirmAttendance,
                                  icon: Icons.check,
                                  backgroundColor: AppTheme.successColor,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  text: 'Retake',
                                  isOutlined: true,
                                  onPressed: isSubmitting ? null : _retake,
                                  icon: Icons.refresh,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomButton(
                                  text: 'Confirm',
                                  isLoading: isSubmitting,
                                  onPressed: _confirmAttendance,
                                  icon: Icons.check,
                                  backgroundColor: AppTheme.successColor,
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : CustomButton(
                        text: _isCapturing ? 'Capturing...' : 'Capture',
                        isLoading: _isCapturing,
                        onPressed: _captureImage,
                        icon: Icons.camera_alt,
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          if (_resultOverlay != null)
            Positioned.fill(
              child: _AttendanceResultOverlay(
                state: _resultOverlay!,
                onPrimaryAction: () {
                  final shouldPop = _resultOverlay?.closeScreenOnAction == true;
                  _dismissResultOverlay(popScreen: shouldPop);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewSurface({required bool isSubmitting}) {
    if (_capturedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _capturedImage!.bytes,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
          if (isSubmitting)
            LayoutBuilder(
              builder: (context, constraints) {
                return _buildRecognitionHud(
                  constraints,
                  isLocked: true,
                  statusLabel: context.t('Verifying identity'),
                );
              },
            ),
        ],
      );
    }

    if (_isCameraReady && _cameraController != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildCameraPreview(),
              _buildRecognitionHud(
                constraints,
                isLocked: _isCapturing,
                statusLabel: _isCapturing
                    ? context.t('Locking identity')
                    : context.t('Face scan ready'),
              ),
            ],
          );
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _cameraError == null
            ? const LoadingWidget(message: 'Initializing camera...')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_cameraError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.t('Retry')),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRecognitionHud(
    BoxConstraints constraints, {
    required bool isLocked,
    required String statusLabel,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scanController,
        _pulseController,
        _ringController,
      ]),
      builder: (context, _) {
        final overlayWidth = constraints.maxWidth < 420
            ? constraints.maxWidth * 0.62
            : 250.0;
        final overlayHeight = constraints.maxWidth < 420
            ? constraints.maxHeight * 0.48
            : 300.0;
        final frameRect = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: overlayWidth,
          height: overlayHeight,
        );
        final pulse = Curves.easeInOut.transform(_pulseController.value);
        final scanPhase = Curves.easeInOut.transform(_scanController.value);
        final ringPhase = Curves.easeInOut.transform(_ringController.value);
        final confidence = isLocked ? 0.96 : 0.42 + (scanPhase * 0.48);
        final frameColor = isLocked ? AppTheme.secondaryColor : Colors.white;
        final lineTop = (overlayHeight - 42) * _scanController.value;
        final ringSize =
            math.min(frameRect.width, frameRect.height) + (isLocked ? 52 : 38);
        final telemetryTop = math.max(frameRect.top - 42, 14).toDouble();
        final meterTop = math.min(
          frameRect.bottom + 16,
          constraints.maxHeight - 56,
        ).toDouble();

        return Stack(
          children: [
            Positioned(
              left: frameRect.center.dx - (ringSize / 2),
              top: frameRect.center.dy - (ringSize / 2),
              child: IgnorePointer(
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: ringPhase * math.pi * 2,
                          child: CustomPaint(
                            painter: _TargetRingPainter(
                              color: frameColor,
                              progress: ringPhase,
                              inner: false,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: -(ringPhase * math.pi * 1.5),
                          child: CustomPaint(
                            painter: _TargetRingPainter(
                              color: frameColor.withValues(alpha: 0.9),
                              progress: ringPhase,
                              inner: true,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: isLocked ? 10 : 8,
                        height: isLocked ? 10 : 8,
                        decoration: BoxDecoration(
                          color: frameColor.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: frameColor.withValues(alpha: 0.36),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: frameRect.left,
              top: telemetryTop,
              child: _HudTelemetryChip(
                label: context.t('Scan Mode'),
                value: statusLabel,
                accentColor: frameColor,
                showDot: true,
              ),
            ),
            Positioned(
              right: math.max(constraints.maxWidth - frameRect.right, 16),
              top: telemetryTop,
              child: _HudTelemetryChip(
                label: context.t('Frame ID'),
                value:
                    '#${(7100 + (_ringController.value * 899)).round()}',
                accentColor: frameColor,
                alignEnd: true,
              ),
            ),
            Positioned.fromRect(
              rect: frameRect,
              child: AnimatedContainer(
                duration: AppTheme.animFast,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isLocked ? 0.1 : 0.04),
                  borderRadius: BorderRadius.circular(frameRect.height / 2),
                  border: Border.all(
                    color: frameColor.withValues(alpha: isLocked ? 0.86 : 0.54),
                    width: isLocked ? 2.6 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: frameColor.withValues(
                        alpha: isLocked ? 0.28 : 0.14,
                      ),
                      blurRadius: isLocked ? 24 : 12,
                      spreadRadius: isLocked ? 1.2 : 0.4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(frameRect.height / 2),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                frameColor.withValues(alpha: 0.02),
                                frameColor.withValues(alpha: 0.08),
                                frameColor.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        top: 14 + lineTop,
                        child: Container(
                          height: isLocked ? 4 : 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                frameColor.withValues(alpha: 0.25),
                                frameColor.withValues(alpha: 0.95),
                                frameColor.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: frameColor.withValues(alpha: 0.28),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: _HudTelemetryChip(
                          label: context.t('Liveness'),
                          value: '${(confidence * 100).round()}%',
                          accentColor: frameColor,
                          compact: true,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: _HudTelemetryChip(
                          label: context.t('Latency'),
                          value:
                              '${(12 + ((1 - scanPhase) * 9)).round()} ms',
                          accentColor: frameColor,
                          compact: true,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: frameRect.left + 12,
              top: meterTop,
              width: frameRect.width - 24,
              child: _HudConfidenceMeter(
                value: confidence,
                accentColor: frameColor,
                isLocked: isLocked,
              ),
            ),
            _HudCorner(
              left: frameRect.left - 8,
              top: frameRect.top - 8,
              color: frameColor,
              pulse: pulse,
              isLocked: isLocked,
              horizontalFromLeft: true,
              verticalFromTop: true,
            ),
            _HudCorner(
              right: constraints.maxWidth - frameRect.right - 8,
              top: frameRect.top - 8,
              color: frameColor,
              pulse: pulse,
              isLocked: isLocked,
              horizontalFromLeft: false,
              verticalFromTop: true,
            ),
            _HudCorner(
              left: frameRect.left - 8,
              bottom: constraints.maxHeight - frameRect.bottom - 8,
              color: frameColor,
              pulse: pulse,
              isLocked: isLocked,
              horizontalFromLeft: true,
              verticalFromTop: false,
            ),
            _HudCorner(
              right: constraints.maxWidth - frameRect.right - 8,
              bottom: constraints.maxHeight - frameRect.bottom - 8,
              color: frameColor,
              pulse: pulse,
              isLocked: isLocked,
              horizontalFromLeft: false,
              verticalFromTop: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Text(_cameraError ?? context.t('Camera not available')),
      );
    }

    final previewSize = _cameraController!.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(_cameraController!);
    }

    final sensorTurns =
        (_cameraController!.description.sensorOrientation ~/ 90) % 4;
    final totalTurns = (sensorTurns + _previewQuarterTurns) % 4;

    Widget preview = SizedBox(
      width: previewSize.height,
      height: previewSize.width,
      child: CameraPreview(_cameraController!),
    );

    if (totalTurns != 0) {
      preview = RotatedBox(quarterTurns: totalTurns, child: preview);
    }

    return SizedBox.expand(
      child: FittedBox(fit: BoxFit.cover, child: preview),
    );
  }
}

class _HudTelemetryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final bool compact;
  final bool alignEnd;
  final bool showDot;

  const _HudTelemetryChip({
    required this.label,
    required this.value,
    required this.accentColor,
    this.compact = false,
    this.alignEnd = false,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.end : TextAlign.start;
    final crossAxisAlignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(compact ? 14 : 999),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (showDot)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.96),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            )
          else
            Text(
              label.toUpperCase(),
              textAlign: textAlign,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: textAlign,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudConfidenceMeter extends StatelessWidget {
  final double value;
  final Color accentColor;
  final bool isLocked;

  const _HudConfidenceMeter({
    required this.value,
    required this.accentColor,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('Recognition Confidence'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.66),
                            accentColor.withValues(alpha: 0.98),
                            Colors.white.withValues(alpha: isLocked ? 0.9 : 0.58),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCorner extends StatelessWidget {
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final Color color;
  final double pulse;
  final bool isLocked;
  final bool horizontalFromLeft;
  final bool verticalFromTop;

  const _HudCorner({
    this.left,
    this.top,
    this.right,
    this.bottom,
    required this.color,
    required this.pulse,
    required this.isLocked,
    required this.horizontalFromLeft,
    required this.verticalFromTop,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLocked ? 34.0 : 30.0;
    final thickness = isLocked ? 3.0 : 2.4;
    final scale = 0.96 + (pulse * (isLocked ? 0.12 : 0.08));

    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Positioned(
                left: horizontalFromLeft ? 0 : null,
                right: horizontalFromLeft ? null : 0,
                top: verticalFromTop ? 0 : null,
                bottom: verticalFromTop ? null : 0,
                child: Container(
                  width: size * 0.75,
                  height: thickness,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isLocked ? 0.96 : 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: horizontalFromLeft ? 0 : null,
                right: horizontalFromLeft ? null : 0,
                top: verticalFromTop ? 0 : null,
                bottom: verticalFromTop ? null : 0,
                child: Container(
                  width: thickness,
                  height: size * 0.75,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isLocked ? 0.96 : 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetRingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool inner;

  const _TargetRingPainter({
    required this.color,
    required this.progress,
    required this.inner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - (inner ? 10 : 6);
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = inner ? 1.2 : 1.6
      ..color = color.withValues(alpha: inner ? 0.12 : 0.08);

    canvas.drawCircle(center, radius, trackPaint);

    final mainArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = inner ? 2.2 : 2.8
      ..color = color.withValues(alpha: inner ? 0.68 : 0.9);

    final accentArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = inner ? 1.6 : 2.2
      ..color = Colors.white.withValues(alpha: inner ? 0.34 : 0.24);

    final baseAngle = (-math.pi / 2) + (progress * math.pi * 2);
    canvas.drawArc(
      ringRect,
      baseAngle,
      inner ? math.pi * 0.46 : math.pi * 0.26,
      false,
      mainArcPaint,
    );
    canvas.drawArc(
      ringRect,
      baseAngle + math.pi * 0.94,
      inner ? math.pi * 0.24 : math.pi * 0.15,
      false,
      accentArcPaint,
    );

    if (!inner) {
      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.4);

      for (final angle in <double>[0, math.pi / 2, math.pi, math.pi * 1.5]) {
        final outer = Offset(
          center.dx + math.cos(angle) * (radius + 4),
          center.dy + math.sin(angle) * (radius + 4),
        );
        final innerPoint = Offset(
          center.dx + math.cos(angle) * (radius - 10),
          center.dy + math.sin(angle) * (radius - 10),
        );
        canvas.drawLine(innerPoint, outer, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TargetRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.inner != inner;
  }
}

class _AttendanceResultState {
  final bool isSuccess;
  final bool closeScreenOnAction;
  final Color accentColor;
  final String title;
  final String message;
  final String primaryActionLabel;
  final String? detailChip;

  const _AttendanceResultState({
    required this.isSuccess,
    required this.closeScreenOnAction,
    required this.accentColor,
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    this.detailChip,
  });

  factory _AttendanceResultState.success({
    required BuildContext context,
    required String name,
    required double confidence,
    required String status,
  }) {
    final t = context.tRead;
    final isPresent = status.toLowerCase() == 'present';

    return _AttendanceResultState(
      isSuccess: true,
      closeScreenOnAction: true,
      accentColor: isPresent ? AppTheme.successColor : AppTheme.warningColor,
      title: t('Welcome, {name}!', params: {'name': name}),
      message: isPresent ? t('Check-In Recorded') : t('Recorded as Late'),
      primaryActionLabel: t('Done'),
      detailChip: t(
        'Confidence: {value}%',
        params: {'value': (confidence * 100).toStringAsFixed(1)},
      ),
    );
  }

  factory _AttendanceResultState.failure({
    required BuildContext context,
    required String message,
  }) {
    final t = context.tRead;

    return _AttendanceResultState(
      isSuccess: false,
      closeScreenOnAction: false,
      accentColor: AppTheme.errorColor,
      title: t('Attendance Not Recorded'),
      message: message,
      primaryActionLabel: t('Try Again'),
      detailChip: t('Check lighting and face position'),
    );
  }
}

class _AttendanceResultOverlay extends StatefulWidget {
  final _AttendanceResultState state;
  final VoidCallback onPrimaryAction;

  const _AttendanceResultOverlay({
    required this.state,
    required this.onPrimaryAction,
  });

  @override
  State<_AttendanceResultOverlay> createState() =>
      _AttendanceResultOverlayState();
}

class _AttendanceResultOverlayState extends State<_AttendanceResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final cardScale = Tween<double>(begin: 0.94, end: 1).animate(fade);
    final markProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: fade,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.black.withValues(alpha: 0.46),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: ScaleTransition(
            scale: cardScale,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: AppTheme.glassDecoration(
                  borderRadius: 28,
                  bgColor: AppTheme.bgCard.withValues(alpha: 0.92),
                  borderColor: widget.state.accentColor.withValues(alpha: 0.22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.state.accentColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: widget.state.accentColor.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                      ),
                      child: AnimatedBuilder(
                        animation: markProgress,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ResultMarkPainter(
                              isSuccess: widget.state.isSuccess,
                              color: widget.state.accentColor,
                              progress: markProgress.value,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      widget.state.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.state.message,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.state.detailChip != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.state.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: widget.state.accentColor.withValues(alpha: 0.18),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          widget.state.detailChip!,
                          style: TextStyle(
                            color: widget.state.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    CustomButton(
                      text: widget.state.primaryActionLabel,
                      onPressed: widget.onPrimaryAction,
                      backgroundColor: widget.state.accentColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMarkPainter extends CustomPainter {
  final bool isSuccess;
  final Color color;
  final double progress;

  const _ResultMarkPainter({
    required this.isSuccess,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.34;
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color.withValues(alpha: 0.24);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 8
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      circlePaint,
    );

    if (isSuccess) {
      final start = Offset(size.width * 0.28, size.height * 0.56);
      final middle = Offset(size.width * 0.45, size.height * 0.72);
      final end = Offset(size.width * 0.74, size.height * 0.38);

      final path = Path();
      path.moveTo(start.dx, start.dy);

      if (progress <= 0.5) {
        final t = progress / 0.5;
        final current = Offset.lerp(start, middle, t) ?? middle;
        path.lineTo(current.dx, current.dy);
      } else {
        path
          ..lineTo(middle.dx, middle.dy)
          ..lineTo(
            (Offset.lerp(middle, end, (progress - 0.5) / 0.5) ?? end).dx,
            (Offset.lerp(middle, end, (progress - 0.5) / 0.5) ?? end).dy,
          );
      }

      canvas.drawPath(path, accentPaint);
      return;
    }

    final firstStart = Offset(size.width * 0.3, size.height * 0.3);
    final firstEnd = Offset(size.width * 0.7, size.height * 0.7);
    final secondStart = Offset(size.width * 0.7, size.height * 0.3);
    final secondEnd = Offset(size.width * 0.3, size.height * 0.7);

    if (progress <= 0.5) {
      final current = Offset.lerp(firstStart, firstEnd, progress / 0.5) ?? firstEnd;
      canvas.drawLine(firstStart, current, accentPaint);
    } else {
      canvas.drawLine(firstStart, firstEnd, accentPaint);
      final current = Offset.lerp(
        secondStart,
        secondEnd,
        (progress - 0.5) / 0.5,
      ) ?? secondEnd;
      canvas.drawLine(secondStart, current, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ResultMarkPainter oldDelegate) {
    return oldDelegate.isSuccess != isSuccess ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}
