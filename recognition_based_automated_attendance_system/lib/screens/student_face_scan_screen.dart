import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/captured_image.dart';
import '../providers/auth_provider.dart';
import '../utils/camera_selector.dart';
import '../utils/platform_utils.dart';
import '../widgets/custom_button.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

class StudentFaceScanScreen extends StatefulWidget {
  const StudentFaceScanScreen({super.key});

  @override
  State<StudentFaceScanScreen> createState() => _StudentFaceScanScreenState();
}

class _StudentFaceScanScreenState extends State<StudentFaceScanScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  String? _cameraError;
  CapturedImage? _capturedImage;
  int _previewQuarterTurns = 0;

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
    final tRead = context.tRead;

    try {
      if (PlatformUtils.requiresSecureWebCameraContext) {
        throw Exception(PlatformUtils.webCameraContextMessage);
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception(tRead('No cameras found'));
      }

      final camera = CameraSelector.forSelfie(cameras);
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _cameraError = null;
        _previewQuarterTurns =
            PlatformUtils.isNativeDesktop && camera.sensorOrientation == 0
            ? 2
            : 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraReady = false;
        _cameraError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final image = await _cameraController!.takePicture();
      final capturedImage = await CapturedImage.fromXFile(
        image,
        fallbackPrefix: 'student_face_login',
      );

      if (!mounted) return;
      setState(() {
        _capturedImage = capturedImage;
        _isCapturing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      _showMessage(
        context.tRead('Failed to capture image'),
        AppTheme.errorColor,
      );
    }
  }

  Future<void> _continueWithFace() async {
    final capturedImage = _capturedImage;
    if (capturedImage == null) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithStudentFace(capturedImage);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/student-dashboard');
      return;
    }

    _showMessage(
      auth.error ?? context.tRead('Student face not recognized.'),
      AppTheme.errorColor,
    );
  }

  void _retake() {
    setState(() => _capturedImage = null);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _openGovernmentIntro() {
    Navigator.pushReplacementNamed(context, '/gov-login-intro');
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthProvider, bool>(
      (provider) => provider.isLoading,
    );

    return Scaffold(
      body: Column(
        children: [
          if (ResponsiveLayout.isNativeDesktop()) const WindowTitleBar(),
          Expanded(
            child: Container(
              color: AppTheme.bgBase,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: ResponsiveLayout.pagePadding(context),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _openGovernmentIntro,
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: AppTheme.textSecondary,
                                tooltip: context.t('Back'),
                              ),
                              const Spacer(),
                              if (_isCameraReady)
                                IconButton(
                                  onPressed: _capturedImage == null
                                      ? () {
                                          setState(() {
                                            _previewQuarterTurns =
                                                (_previewQuarterTurns + 1) % 4;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.rotate_right_rounded),
                                  color: AppTheme.textSecondary,
                                  tooltip: context.t('Rotate Camera'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.t('Student Face Scan'),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t(
                              'Scan your registered face to view all absence records across your classes.',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildCameraCard(),
                          const SizedBox(height: 20),
                          _buildActions(isLoading: isLoading),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.face_retouching_natural,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _capturedImage == null
                      ? context.t('Position your face in the frame')
                      : context.t('Review the captured face image'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.bgDeep,
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: _buildPreviewSurface(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSurface() {
    final capturedImage = _capturedImage;
    if (capturedImage != null) {
      return Image.memory(capturedImage.bytes, fit: BoxFit.cover);
    }

    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 42,
                color: AppTheme.warningColor,
              ),
              const SizedBox(height: 12),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.t('Retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraReady || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RotatedBox(
      quarterTurns: _previewQuarterTurns,
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildActions({required bool isLoading}) {
    final hasCapture = _capturedImage != null;

    if (!hasCapture) {
      return CustomButton(
        text: _isCapturing ? 'Capturing...' : 'Capture Face',
        isLoading: _isCapturing,
        onPressed: _isCameraReady ? _captureImage : null,
        icon: Icons.camera_alt_rounded,
        useGradient: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final retake = CustomButton(
          text: 'Retake',
          isOutlined: true,
          onPressed: isLoading ? null : _retake,
          icon: Icons.refresh_rounded,
        );
        final continueButton = CustomButton(
          text: 'Show My Absences',
          isLoading: isLoading,
          onPressed: _continueWithFace,
          icon: Icons.event_busy_rounded,
          useGradient: true,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [retake, const SizedBox(height: 12), continueButton],
          );
        }

        return Row(
          children: [
            Expanded(child: retake),
            const SizedBox(width: 14),
            Expanded(child: continueButton),
          ],
        );
      },
    );
  }
}
