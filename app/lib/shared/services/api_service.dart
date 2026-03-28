import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.pethealthapp.com/api/v1',
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
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        code: data['error']?['code'] ?? 'UNKNOWN',
        message: data['error']?['message'] ?? 'Unknown error',
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
