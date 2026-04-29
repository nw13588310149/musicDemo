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
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: _buildOptions(
          headers: <String, dynamic>{
            Headers.contentTypeHeader: Headers.multipartFormDataContentType,
            ...?headers,
          },
          timeout: timeout,
        ),
      );
      return _toApiResponse(response.data);
    } on DioException catch (error) {
      return ApiResponse.failure(_extractDioMessage(error));
    } catch (_) {
      return ApiResponse.failure('缃戠粶寮傚父锛岃绋嶅悗閲嶈瘯');
    }
  }

  Future<void> updateToken(String token) async {
    await _storage.saveToken(token);
  }

  Options _buildOptions({Map<String, dynamic>? headers, Duration? timeout}) {
    final mergedHeaders = <String, dynamic>{
      'Content-Type': 'application/json',
      'app-token': _storage.token,
      ...?headers,
    };

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
