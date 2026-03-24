import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// API Service for making HTTP requests
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  String? _authToken;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConfig.connectionTimeout),
      receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors for logging and error handling
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        if (kDebugMode) {
          print('🌐 Request: ${options.method} ${options.path}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('✅ Response: ${response.statusCode} ${response.requestOptions.path}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          print('❌ Error: ${error.message}');
          print('   Response: ${error.response?.data}');
        }
        return handler.next(error);
      },
    ));
  }

  /// Set authentication token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
  }

  /// Update the base URL dynamically
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// Create a test Dio instance for trying a new URL
  Dio createTestDio(String url) {
    return Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: Duration(milliseconds: ApiConfig.connectionTimeout),
      receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
    ));
  }

  /// GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.patch(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload file(s)
  Future<Response> uploadFile(
    String path, {
    required List<MultipartFile> files,
    String fieldName = 'images',
    Map<String, dynamic>? additionalFields,
  }) async {
    try {
      final formData = FormData();
      
      // Add files
      for (var file in files) {
        formData.files.add(MapEntry(fieldName, file));
      }
      
      // Add additional fields
      if (additionalFields != null) {
        additionalFields.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }
      
      return await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload single file for attendance marking
  Future<Response> uploadSingleFile(
    String path, {
    required MultipartFile file,
    String fieldName = 'image',
    Map<String, dynamic>? additionalFields,
  }) async {
    try {
      final formData = FormData();
      formData.files.add(MapEntry(fieldName, file));
      
      // Add additional fields
      if (additionalFields != null) {
        additionalFields.forEach((key, value) {
          if (value != null) {
            formData.fields.add(MapEntry(key, value.toString()));
          }
        });
      }
      
      return await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload image for exam proctoring
  Future<Response> uploadExamProctorImage(
    String path, {
    required MultipartFile file,
    int? studentId,
    int? classId,
  }) async {
    try {
      final formData = FormData();
      formData.files.add(MapEntry('image', file));
      
      if (studentId != null) {
        formData.fields.add(MapEntry('student_id', studentId.toString()));
      }
      if (classId != null) {
        formData.fields.add(MapEntry('class_id', classId.toString()));
      }
      
      return await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors
  Exception _handleError(DioException e) {
    String message = 'An error occurred';
    
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        message = data['detail'].toString();
      } else if (e.response!.statusCode == 401) {
        message = 'Unauthorized. Please login again.';
      } else if (e.response!.statusCode == 403) {
        message = 'Access denied.';
      } else if (e.response!.statusCode == 404) {
        message = 'Resource not found.';
      } else if (e.response!.statusCode == 500) {
        message = 'Server error. Please try again later.';
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Please check your internet.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Could not connect to server. Please check your network.';
    }
    
    return Exception(message);
  }
}
