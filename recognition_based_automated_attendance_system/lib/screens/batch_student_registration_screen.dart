import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/app_theme.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../utils/camera_selector.dart';
import '../widgets/custom_button.dart';

/// Batch Student Registration Screen
/// Register multiple students with 5 images each
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
  final ApiService _api = ApiService();

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
  int _previewQuarterTurns = 0;

  // Images for current student
  List<File> _capturedImages = [];
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
      _totalStudents = 999; // Allow unlimited students when adding to existing class
      _currentStep = 1;
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No cameras found');
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
      _showError('Failed to initialize camera: $e');
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
      _showError('Please enter a class name');
      return;
    }

    if (studentCount <= 0 || studentCount > 200) {
      _showError('Please enter a valid number of students (1-200)');
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
        'Failed to create class: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;

    if (_capturedImages.length >= 5) {
      _showError('Already captured 5 images for this student');
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      // Save image
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'student_${_currentStudentIndex + 1}_${_capturedImages.length + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(directory.path, fileName);

      await image.saveTo(savedPath);
      final savedFile = File(savedPath);

      if (await savedFile.exists()) {
        setState(() {
          _capturedImages.add(savedFile);
          _isCapturing = false;
        });

        if (_capturedImages.length == 5) {
          _showSuccess('All 5 images captured! Enter name and click Submit.');
        } else {
          _showSuccess('Image ${_capturedImages.length}/5 captured');
        }
      } else {
        throw Exception('Failed to save image');
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      _showError('Failed to capture image: $e');
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
      _showError('Please enter student name');
      return;
    }

    if (_capturedImages.length < 5) {
      _showError('Please capture all 5 images before submitting');
      return;
    }

    if (_classId == null) {
      _showError('Class not created. Please restart registration.');
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
        final file = await MultipartFile.fromFile(
          image.path,
          filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
          'Student registered! Moving to next student (${_currentStudentIndex + 1}/$_totalStudents)',
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
        'Failed to register student: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Complete!'),
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
              'Successfully registered ${_registeredStudents.length} students in $_className',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total images captured: ${_registeredStudents.length * 5}',
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
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showAddAnotherDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student Registered!'),
        content: Text(
          'Successfully registered. Add another student to $_className?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to class students
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Another'),
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

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == 0
            ? 'Create Class'
            : widget.initialClassId != null
                ? 'Add Student'
                : 'Register Students'),
        actions: [
          if (_currentStep == 1 && _isCameraReady)
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: 'Rotate Camera',
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
                      title: const Text('Cancel Registration?'),
                      content: const Text(
                        'Progress will be lost. Are you sure?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('No'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                          ),
                          child: const Text('Yes, Cancel'),
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
          const Text(
            'Class Setup',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new class and specify the number of students to register',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),

          // Class Name
          TextField(
            controller: _classNameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              hintText: 'e.g., Class 10A, Computer Science 101',
              prefixIcon: Icon(Icons.class_),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Number of Students
          TextField(
            controller: _studentCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of Students',
              hintText: 'e.g., 30, 50, 100',
              prefixIcon: Icon(Icons.people),
              border: OutlineInputBorder(),
              helperText: 'Maximum 200 students per batch',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Class: $_className',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.initialClassId != null
                        ? 'Students added: ${_registeredStudents.length}'
                        : 'Student ${_currentStudentIndex + 1} of $_totalStudents',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Student Info Form - Name Only
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _currentStudentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Student Name',
                        hintText: 'Enter full name',
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
                            Icon(Icons.lightbulb, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Photo Capture Tips',
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
                        _buildTip('💡', 'Ensure good lighting (avoid shadows)'),
                        _buildTip('📏', 'Keep face centered in the frame'),
                        _buildTip('👀', 'Look straight at the camera'),
                        _buildTip(
                          '🚫',
                          'Remove glasses, hats, or face coverings',
                        ),
                        _buildTip(
                          '📸',
                          'Capture 5 photos from slightly different angles',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Camera Preview
                if (_isCameraReady && _cameraController != null)
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _buildCameraPreview(),
                    ),
                  )
                else
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.shade200,
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 16),

                // Capture Button
                CustomButton(
                  text: _isCapturing
                      ? 'Capturing...'
                      : 'Capture Image (${_capturedImages.length}/5)',
                  isLoading: _isCapturing,
                  onPressed: _capturedImages.length < 5 ? _captureImage : null,
                  icon: Icons.camera_alt,
                  backgroundColor: _capturedImages.length < 5
                      ? AppTheme.primaryColor
                      : Colors.grey,
                ),
                const SizedBox(height: 24),

                // Captured Images Preview
                if (_capturedImages.isNotEmpty) ...[
                  const Text(
                    'Captured Images',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                  image: FileImage(_capturedImages[index]),
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
                                  '${index + 1}/5',
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
                CustomButton(
                  text: _currentStudentIndex < _totalStudents - 1
                      ? 'Submit & Next Student'
                      : 'Submit & Finish',
                  isLoading: _isSubmitting,
                  onPressed: _capturedImages.length == 5 && !_isSubmitting
                      ? _submitStudent
                      : null,
                  icon: _currentStudentIndex < _totalStudents - 1
                      ? Icons.arrow_forward
                      : Icons.check_circle,
                  backgroundColor: _capturedImages.length == 5
                      ? AppTheme.successColor
                      : Colors.grey,
                ),
              ],
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
