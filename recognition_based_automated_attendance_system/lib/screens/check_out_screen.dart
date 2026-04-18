import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/captured_image.dart';
import '../providers/attendance_provider.dart';
import '../utils/camera_selector.dart';
import '../utils/platform_utils.dart';
import '../widgets/custom_button.dart';

class CheckOutScreen extends StatefulWidget {
  const CheckOutScreen({super.key});

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;
  bool _isCapturing = false;
  CapturedImage? _capturedImage;
  int _previewQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
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

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      final capturedImage = await CapturedImage.fromXFile(
        image,
        fallbackPrefix: 'checkout',
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
    });
  }

  Future<void> _confirmCheckOut() async {
    if (_capturedImage == null) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final success = await attendanceProvider.checkOut(_capturedImage!);

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      _showError(attendanceProvider.error ?? context.trRead('checkOutFailed'));
    }
  }

  void _showSuccessDialog() {
    final t = context.t;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                size: 64,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t('checkOutSuccess'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t('checkOut'),
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.successColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(t('Done')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('checkOut')),
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.infoColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.logout, color: AppTheme.infoColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('checkOutDescription'),
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
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: _capturedImage != null
                    ? Image.memory(
                        _capturedImage!.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : _isCameraReady && _cameraController != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildCameraPreview(),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final overlayWidth = constraints.maxWidth < 420
                                  ? constraints.maxWidth * 0.62
                                  : 250.0;
                              final overlayHeight = constraints.maxWidth < 420
                                  ? constraints.maxHeight * 0.48
                                  : 300.0;

                              return Container(
                                width: overlayWidth,
                                height: overlayHeight,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    overlayHeight / 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _cameraError == null
                              ? const CircularProgressIndicator()
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _cameraError!,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _initCamera,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(t('Retry')),
                                    ),
                                  ],
                                ),
                        ),
                      ),
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
                              text: t('Retake'),
                              isOutlined: true,
                              onPressed: _retake,
                              icon: Icons.refresh,
                            ),
                            const SizedBox(height: 12),
                            Consumer<AttendanceProvider>(
                              builder: (context, attendance, child) {
                                return CustomButton(
                                  text: t('Confirm'),
                                  isLoading: attendance.isLoading,
                                  onPressed: _confirmCheckOut,
                                  icon: Icons.check,
                                  backgroundColor: AppTheme.successColor,
                                );
                              },
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: t('Retake'),
                              isOutlined: true,
                              onPressed: _retake,
                              icon: Icons.refresh,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Consumer<AttendanceProvider>(
                              builder: (context, attendance, child) {
                                return CustomButton(
                                  text: t('Confirm'),
                                  isLoading: attendance.isLoading,
                                  onPressed: _confirmCheckOut,
                                  icon: Icons.check,
                                  backgroundColor: AppTheme.successColor,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : CustomButton(
                    text: _isCapturing ? t('Capturing...') : t('Capture'),
                    isLoading: _isCapturing,
                    onPressed: _captureImage,
                    icon: Icons.camera_alt,
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
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
