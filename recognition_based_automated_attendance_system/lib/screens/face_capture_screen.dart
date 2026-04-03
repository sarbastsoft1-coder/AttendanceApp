import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';
import '../utils/camera_selector.dart';
import '../widgets/custom_button.dart';

/// Face Capture Screen - Captures multiple face images for registration
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cameraController;
  final List<File> _capturedImages = [];
  bool _isCameraReady = false;
  bool _isCapturing = false;
  int _previewQuarterTurns = 0;
  static const int _requiredImages = 2;
  static const int _minImages = _requiredImages;

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  String _localizeMessage(String message) {
    final minFaceImagesMatch = RegExp(
      r'^Please upload at least (\d+) face images$',
    ).firstMatch(message);
    if (minFaceImagesMatch != null) {
      return t(
        'Please upload at least {count} face images',
        params: {'count': minFaceImagesMatch.group(1)!},
      );
    }

    final maxImagesMatch = RegExp(
      r'^Maximum (\d+) images allowed$',
    ).firstMatch(message);
    if (maxImagesMatch != null) {
      return t(
        'Maximum {count} images allowed',
        params: {'count': maxImagesMatch.group(1)!},
      );
    }

    return t(message);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
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

      final isDesktop =
          Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      if (isDesktop && frontCamera.sensorOrientation == 0) {
        _previewQuarterTurns = 2;
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      _showError(
        t('Failed to initialize camera: {error}', params: {'error': '$e'}),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localizeMessage(message)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;
    if (_capturedImages.length >= _requiredImages) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      // Save image to a persistent directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'face_${DateTime.now().millisecondsSinceEpoch}_${_capturedImages.length}.jpg';
      final savedPath = path.join(directory.path, fileName);

      await image.saveTo(savedPath);
      final savedFile = File(savedPath);

      if (await savedFile.exists()) {
        setState(() {
          _capturedImages.add(savedFile);
          _isCapturing = false;
        });
      } else {
        throw Exception(t('Failed to save captured image'));
      }

      // Haptic feedback
      // HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      _showError(
        t('Failed to capture image: {error}', params: {'error': '$e'}),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  Future<void> _submitFaces() async {
    if (_capturedImages.length < _minImages) {
      _showError(
        t(
          'Please capture at least {count} images',
          params: {'count': '$_minImages'},
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerFace(_capturedImages);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Face registered successfully!')),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showError(authProvider.error ?? 'Failed to register face');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Register Your Face')),
        automaticallyImplyLeading: false,
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
          TextButton(
            onPressed: () {
              // Skip for now
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Text(t('Skip')),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(
                      'Capture {count} images of your face from different angles',
                      params: {'count': '$_requiredImages'},
                    ),
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Camera Preview
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: _isCameraReady && _cameraController != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildCameraPreview(),
                          // Face overlay guide
                          CustomPaint(
                            size: const Size(250, 300),
                            painter: FaceOverlayPainter(),
                          ),
                          // Progress indicator
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_capturedImages.length}/$_requiredImages',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),

          // Captured Images Thumbnails
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _requiredImages,
              itemBuilder: (context, index) {
                if (index < _capturedImages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successColor,
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: FileImage(_capturedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.errorColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        color: Colors.grey.shade100,
                      ),
                      child: Icon(
                        Icons.add_a_photo,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Capture Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _capturedImages.length < _requiredImages
                        ? _captureImage
                        : null,
                    icon: _isCapturing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt),
                    label: Text(
                      _isCapturing ? t('Capturing...') : t('Capture'),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Submit Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return CustomButton(
                  text: 'Register Face',
                  isLoading: auth.isLoading,
                  onPressed: _capturedImages.length >= _minImages
                      ? _submitFaces
                      : null,
                  backgroundColor: AppTheme.successColor,
                  icon: Icons.check_circle,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
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

/// Custom painter for face overlay guide
class FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.9,
    );

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
