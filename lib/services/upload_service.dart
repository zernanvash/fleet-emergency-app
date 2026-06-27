import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uploads a single photo [File] to the SCM BFF, which proxies it to Directus
/// /files. Returns the Directus file UUID string on success.
class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  static const _uploadPath =
      '/api/scm/fleet-management/emergency-management/reports/upload';

  late final Dio _dio = _buildDio();

  Dio _buildDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('vos_access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Cookie'] = 'vos_access_token=$token';
        }
        return handler.next(options);
      },
    ));
    return dio;
  }

  /// [baseUrl] — the current BFF base URL (from ApiService.baseUrl).
  Future<String> uploadPhoto(File file, String baseUrl) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    final response = await _dio.post(
      '$baseUrl$_uploadPath',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    final id = response.data?['data']?['id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('Upload succeeded but returned no file ID.');
    }
    return id;
  }
}
