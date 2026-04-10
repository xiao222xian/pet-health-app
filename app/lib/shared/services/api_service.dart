import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class ApiService {
  static const String _baseUrl = 'https://stellar-passion-production-56af.up.railway.app/api/v1';

  static Future<Map<String, String>> _headers() async {
    final session = SupabaseService.client.auth.currentSession;
    return {
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
    } on SocketException {
      throw ApiException(code: 'NETWORK', message: '无法连接服务器，请检查网络');
    } on HttpException {
      throw ApiException(code: 'NETWORK', message: '请求失败，请重试');
    } catch (e) {
      throw ApiException(code: 'NETWORK', message: '连接超时，请重试');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(code: 'PARSE_ERROR', message: '服务器响应异常 (${response.statusCode})');
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        code: data['error']?['code'] as String? ?? 'UNKNOWN',
        message: data['error']?['message'] as String? ?? '未知错误 (${response.statusCode})',
      );
    }
    return data;
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException($code): $message';
}
