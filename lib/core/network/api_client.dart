import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/app_storage.dart';
import 'api_response.dart';

class ApiClient {
  ApiClient({required AppStorage storage})
    : _storage = storage,
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
          contentType: Headers.jsonContentType,
        ),
      );

  final AppStorage _storage;
  final Dio _dio;

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        options: _buildOptions(headers: headers, timeout: timeout),
      );
      return _toApiResponse(response.data);
    } on DioException catch (error) {
      return ApiResponse.failure(_extractDioMessage(error));
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<ApiResponse> post(
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: _buildOptions(headers: headers, timeout: timeout),
      );
      return _toApiResponse(response.data);
    } on DioException catch (error) {
      return ApiResponse.failure(_extractDioMessage(error));
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<ApiResponse> postFormData(
    String path, {
    required FormData data,
    void Function(int sent, int total)? onSendProgress,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      // 对齐 1.0（axios + FormData）：不手动设置 Content-Type，
      // 让 Dio/浏览器自动生成带 boundary 的 multipart/form-data。
      final mergedHeaders =
          <String, dynamic>{
            'app-token': _storage.token,
            'schoolId': _storage.schoolId,
            ...?headers,
          }..removeWhere(
            (key, _) => key.toLowerCase() == Headers.contentTypeHeader,
          );
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        onSendProgress: onSendProgress,
        options: Options(
          headers: mergedHeaders,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      return _toApiResponse(response.data);
    } on DioException catch (error) {
      return ApiResponse.failure(_extractDioMessage(error));
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<Uint8List> getBytes(
    String url, {
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: _buildOptions(
        headers: headers,
        timeout: timeout,
      ).copyWith(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty response bytes');
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> updateToken(String token) async {
    await _storage.saveToken(token);
  }

  Options _buildOptions({Map<String, dynamic>? headers, Duration? timeout}) {
    final mergedHeaders = <String, dynamic>{
      'app-token': _storage.token,
      'schoolId': _storage.schoolId,
      ...?headers,
    };
    final hasContentType = mergedHeaders.keys.any(
      (key) => key.toLowerCase() == Headers.contentTypeHeader,
    );
    if (!hasContentType) {
      mergedHeaders[Headers.contentTypeHeader] = Headers.jsonContentType;
    }

    return Options(
      headers: mergedHeaders,
      sendTimeout: timeout,
      receiveTimeout: timeout,
    );
  }

  ApiResponse _toApiResponse(dynamic body) {
    if (body is Map<String, dynamic>) {
      return ApiResponse.fromJson(body);
    }
    return ApiResponse.failure('接口数据格式错误');
  }

  String _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['msg'] != null) {
      return data['msg'].toString();
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return '请求失败，请稍后重试';
  }
}
