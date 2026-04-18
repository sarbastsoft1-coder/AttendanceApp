import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../config/app_theme.dart';
import '../config/api_config.dart';
import '../localization/localization_extensions.dart';
import '../models/captured_image.dart';
import '../services/api_service.dart';
import '../utils/camera_selector.dart';
import '../utils/platform_utils.dart';
import '../widgets/custom_button.dart';

/// Batch Student Registration Screen
/// Register multiple students with 2 images each
class BatchStudentRegistrationScreen extends StatefulWidget {
  final int? initialClassId;
  final String? initialClassName;

  const BatchStudentRegistrationScreen({
    super.key,
    this.initialClassId,
    this.initialClassName,
  });

  @override
  State<BatchStudentRegistrationScreen> createState() =>
      _BatchStudentRegistrationScreenState();
}

class _BatchStudentRegistrationScreenState
    extends State<BatchStudentRegistrationScreen> {
  static const int _requiredImages = 2;

  final ApiService _api = ApiService();

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);
  String tRead(String text, {Map<String, String> params = const {}}) =>
      context.tRead(text, params: params);

  // Step 1: Class Setup
  final _classNameController = TextEditingController();
  final _studentCountController = TextEditingController();
  final _currentStudentNameController = TextEditingController();

  int _currentStep = 0; // 0: Setup, 1: Registration
  int _totalStudents = 0;
  int _currentStudentIndex = 0;
  String _className = '';
  int? _classId;

  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;
  int _previewQuarterTurns = 0;

  // Images for current student
  List<CapturedImage> _capturedImages = [];
  bool _isCapturing = false;
  bool _isSubmitting = false;

  // Results
  final List<Map<String, dynamic>> _registeredStudents = [];

  @override
  void initState() {
    super.initState();
    // If a class ID is provided, skip setup and go directly to registration
    if (widget.initialClassId != null) {
      _classId = widget.initialClassId;
      _className = widget.initialClassName ?? 'Class';
      _totalStudents =
          999; // Allow unlimited students when adding to existing class
      _currentStep = 1;
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      if (PlatformUtils.requiresSecureWebCameraContext) {
        throw Exception(PlatformUtils.webCameraContextMessage);
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = tRead('No cameras found');
        });
        _showError(tRead('No cameras found'));
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
        tRead('Failed to initialize camera: {error}', params: {'error': '$e'}),
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

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _startRegistration() async {
    final className = _classNameController.text.trim();
    final studentCount = int.tryParse(_studentCountController.text.trim()) ?? 0;

    if (className.isEmpty) {
      _showError(tRead('Please enter a class name'));
      return;
    }

    if (studentCount <= 0 || studentCount > 200) {
      _showError(tRead('Please enter a valid number of students (1-200)'));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create class in backend
      final response = await _api.post(
        ApiConfig.classes,
        data: {'name': className},
      );

      _classId = response.data['id'];

      setState(() {
        _className = className;
        _totalStudents = studentCount;
        _currentStep = 1;
        _currentStudentIndex = 0;
        _isSubmitting = false;
      });

      _initCamera();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showError(
        tRead(
          'Failed to create class: {error}',
          params: {'error': e.toString().replaceFirst('Exception: ', '')},
        ),
      );
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;

    if (_capturedImages.length >= _requiredImages) {
      _showError(
        tRead('Already captured the required images for this student'),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      final capturedImage = await CapturedImage.fromXFile(
        image,
        fallbackPrefix:
            'student_${_currentStudentIndex + 1}_${_capturedImages.length + 1}',
      );

      setState(() {
        _capturedImages.add(capturedImage);
        _isCapturing = false;
      });

      if (_capturedImages.length == _requiredImages) {
        _showSuccess(
          tRead('All required images captured! Enter name and click Submit.'),
        );
      } else {
        _showSuccess(
          tRead(
            'Image {current}/{total} captured',
            params: {
              'current': '${_capturedImages.length}',
              'total': '$_requiredImages',
            },
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      _showError(
        tRead('Failed to capture image: {error}', params: {'error': '$e'}),
      );
    }
  }

  void _deleteImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  Future<void> _submitStudent() async {
    final name = _currentStudentNameController.text.trim();

    if (name.isEmpty) {
      _showError(tRead('Please enter student name'));
      return;
    }

    if (_capturedImages.length < _requiredImages) {
      _showError(tRead('Please capture all required images before submitting'));
      return;
    }

    if (_classId == null) {
      _showError(tRead('Class not created. Please restart registration.'));
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload student with images to backend
      final formData = FormData();
      formData.fields.add(MapEntry('name', name));
      formData.fields.add(MapEntry('class_id', _classId.toString()));

      for (var image in _capturedImages) {
        final file = MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
        );
        formData.files.add(MapEntry('images', file));
      }

      await _api.post(ApiConfig.registerStudent, data: formData);

      // Save student data locally
      _registeredStudents.add({
        'name': name,
        'class': _className,
        'images': _capturedImages.length,
      });

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      // When adding to existing class, always allow more students
      if (widget.initialClassId != null) {
        // Adding to existing class — offer to add another or finish
        if (!mounted) return;
        setState(() {
          _currentStudentIndex++;
          _currentStudentNameController.clear();
          _capturedImages = [];
        });
        _showAddAnotherDialog();
      } else if (_currentStudentIndex < _totalStudents - 1) {
        // Move to next student
        if (!mounted) return;
        setState(() {
          _currentStudentIndex++;
          _currentStudentNameController.clear();
          _capturedImages = [];
        });
        _showSuccess(
          tRead(
            'Student registered! Moving to next student ({current}/{total})',
            params: {
              'current': '${_currentStudentIndex + 1}',
              'total': '$_totalStudents',
            },
          ),
        );
      } else {
        // All done
        _showCompletionDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      _showError(
        tRead(
          'Failed to register student: {error}',
          params: {'error': e.toString().replaceFirst('Exception: ', '')},
        ),
      );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tRead('Registration Complete!')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppTheme.successColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              tRead(
                'Successfully registered {count} students in {className}',
                params: {
                  'count': '${_registeredStudents.length}',
                  'className': _className,
                },
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tRead(
                'Total images captured: {count}',
                params: {
                  'count': '${_registeredStudents.length * _requiredImages}',
                },
              ),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(tRead('Done')),
          ),
        ],
      ),
    );
  }

  void _showAddAnotherDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tRead('Student Registered!')),
        content: Text(
          tRead(
            'Successfully registered. Add another student to {className}?',
            params: {'className': _className},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to class students
            },
            child: Text(tRead('Done')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tRead('Add Another')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _classNameController.dispose();
    _studentCountController.dispose();
    _currentStudentNameController.dispose();
    super.dispose();
  }

  Widget _buildTip(
    String emoji,
    String text, {
    Map<String, String> params = const {},
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t(text, params: params),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentStep == 0
              ? t('Create Class')
              : widget.initialClassId != null
              ? t('Add Student')
              : t('Register Students'),
        ),
        actions: [
          if (_currentStep == 1 && _isCameraReady)
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
        leading: _currentStep == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(t('Cancel Registration?')),
                      content: Text(t('Progress will be lost. Are you sure?')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(t('No')),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                          ),
                          child: Text(t('Yes, Cancel')),
                        ),
                      ],
                    ),
                  );
                },
              )
            : null,
      ),
      body: _currentStep == 0 ? _buildSetupStep() : _buildRegistrationStep(),
    );
  }

  Widget _buildSetupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Class Setup'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Create a new class and specify the number of students to register',
            ),
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),

          // Class Name
          TextField(
            controller: _classNameController,
            decoration: InputDecoration(
              labelText: t('Class Name'),
              hintText: t('e.g., Class 10A, Computer Science 101'),
              prefixIcon: Icon(Icons.class_),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Number of Students
          TextField(
            controller: _studentCountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: t('Number of Students'),
              hintText: t('e.g., 30, 50, 100'),
              prefixIcon: Icon(Icons.people),
              border: OutlineInputBorder(),
              helperText: t('Maximum 200 students per batch'),
            ),
          ),
          const SizedBox(height: 40),

          CustomButton(
            text: 'START REGISTRATION',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _startRegistration,
            icon: Icons.arrow_forward,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationStep() {
    return Column(
      children: [
        // Student Progress Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final progressText = widget.initialClassId != null
                      ? t(
                          'Students added: {count}',
                          params: {'count': '${_registeredStudents.length}'},
                        )
                      : t(
                          'Student {current} of {total}',
                          params: {
                            'current': '${_currentStudentIndex + 1}',
                            'total': '$_totalStudents',
                          },
                        );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Class: {name}', params: {'name': _className}),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progressText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          t('Class: {name}', params: {'name': _className}),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          progressText,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (widget.initialClassId == null)
                LinearProgressIndicator(
                  value: (_currentStudentIndex + 1) / _totalStudents,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 420 ? 12 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  children: [
                    // Student Info Form - Name Only
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _currentStudentNameController,
                          decoration: InputDecoration(
                            labelText: t('Student Name'),
                            hintText: t('Enter full name'),
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Photo Capture Tips Card
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t('Photo Capture Tips'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTip('👤', 'Face the camera directly'),
                            _buildTip(
                              '💡',
                              'Ensure good lighting (avoid shadows)',
                            ),
                            _buildTip('📏', 'Keep face centered in the frame'),
                            _buildTip('👀', 'Look straight at the camera'),
                            _buildTip(
                              '🚫',
                              'Remove glasses, hats, or face coverings',
                            ),
                            _buildTip(
                              '📸',
                              'Capture {count} photos from slightly different angles',
                              params: {'count': '$_requiredImages'},
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Camera Preview
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final previewHeight = (constraints.maxWidth * 0.76)
                                .clamp(260.0, 420.0)
                                .toDouble();

                            return Container(
                              height: previewHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 3,
                                ),
                                color: Colors.grey.shade200,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child:
                                    _isCameraReady && _cameraController != null
                                    ? _buildCameraPreview()
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: _cameraError == null
                                              ? const CircularProgressIndicator()
                                              : Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _cameraError!,
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    OutlinedButton.icon(
                                                      onPressed: _initCamera,
                                                      icon: const Icon(
                                                        Icons.refresh,
                                                      ),
                                                      label: Text(t('Retry')),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Capture Button
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: CustomButton(
                          text: _isCapturing
                              ? 'Capturing...'
                              : t(
                                  'Capture Image ({current}/{total})',
                                  params: {
                                    'current': '${_capturedImages.length}',
                                    'total': '$_requiredImages',
                                  },
                                ),
                          isLoading: _isCapturing,
                          onPressed:
                              _isCameraReady &&
                                  _capturedImages.length < _requiredImages
                              ? _captureImage
                              : null,
                          icon: Icons.camera_alt,
                          backgroundColor:
                              _capturedImages.length < _requiredImages
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Captured Images Preview
                    if (_capturedImages.isNotEmpty) ...[
                      Text(
                        t('Captured Images'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _capturedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryColor,
                                      width: 2,
                                    ),
                                    image: DecorationImage(
                                      image: MemoryImage(
                                        _capturedImages[index].bytes,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: () => _deleteImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}/$_requiredImages',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Submit Button
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: CustomButton(
                          text: _currentStudentIndex < _totalStudents - 1
                              ? 'Submit & Next Student'
                              : 'Submit & Finish',
                          isLoading: _isSubmitting,
                          onPressed:
                              _capturedImages.length == _requiredImages &&
                                  !_isSubmitting
                              ? _submitStudent
                              : null,
                          icon: _currentStudentIndex < _totalStudents - 1
                              ? Icons.arrow_forward
                              : Icons.check_circle,
                          backgroundColor:
                              _capturedImages.length == _requiredImages
                              ? AppTheme.successColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
