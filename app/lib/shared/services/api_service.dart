import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pet.superstar.tots.asia/api/v1',
  );

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
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
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
      throw ApiException(
          code: 'PARSE_ERROR', message: '服务器响应异常 (${response.statusCode})');
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        code: data['error']?['code'] as String? ?? 'UNKNOWN',
        message: data['error']?['message'] as String? ??
            '未知错误 (${response.statusCode})',
      );
    }
    return data;
  }

  static Future<Map<String, dynamic>> postStream(
    String path,
    Map<String, dynamic> body, {
    void Function(String event, Map<String, dynamic> data)? onEvent,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl$path'));
      request.headers.addAll(await _headers());
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(body);

      final response =
          await client.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode >= 400) {
        final text = await response.stream.bytesToString();
        throw ApiException(
          code: 'HTTP_${response.statusCode}',
          message: text.isEmpty ? '服务器请求失败 (${response.statusCode})' : text,
        );
      }

      Map<String, dynamic>? result;
      String? eventName;
      final buffer = StringBuffer();

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          buffer.write(line.substring(5).trim());
          continue;
        }
        if (line.trim().isEmpty && eventName != null) {
          final raw = buffer.toString();
          buffer.clear();
          if (raw.isEmpty) {
            eventName = null;
            continue;
          }
          final data = jsonDecode(raw) as Map<String, dynamic>;
          onEvent?.call(eventName, data);
          if (eventName == 'result') result = data;
          if (eventName == 'error') {
            throw ApiException(
              code: data['code'] as String? ?? 'STREAM_ERROR',
              message: data['message'] as String? ?? 'AI 服务暂时不可用',
            );
          }
          eventName = null;
        }
      }

      if (result == null) {
        throw ApiException(code: 'STREAM_EMPTY', message: '服务器没有返回问诊结果');
      }
      return result;
    } on SocketException {
      throw ApiException(code: 'NETWORK', message: '无法连接服务器，请检查网络');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(code: 'NETWORK', message: '连接超时，请重试');
    } finally {
      client.close();
    }
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException($code): $message';
}
