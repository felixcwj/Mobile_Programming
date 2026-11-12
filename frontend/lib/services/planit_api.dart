import 'dart:convert';

import 'package:http/http.dart' as http;

/// Development-only API gateway. Provide the backend URL at launch with:
/// flutter run --dart-define=PLANIT_API_BASE_URL=http://localhost:8000
class PlanitApi {
  PlanitApi._();
  static final PlanitApi instance = PlanitApi._();

  static const configuredBaseUrl =
      String.fromEnvironment('PLANIT_API_BASE_URL', defaultValue: '');
  String? _accessToken;

  bool get hasSession => _accessToken != null;
  void clearSession() => _accessToken = null;

  Uri _url(String path, [Map<String, String>? query]) {
    if (configuredBaseUrl.isEmpty) {
      throw const PlanitApiException(
          '백엔드 주소가 설정되지 않았습니다. PLANIT_API_BASE_URL을 지정하세요.');
    }
    final root = Uri.tryParse(configuredBaseUrl);
    if (root == null || !root.hasScheme || root.host.isEmpty) {
      throw const PlanitApiException('백엔드 주소 형식이 올바르지 않습니다.');
    }
    return Uri.parse('${configuredBaseUrl.replaceFirst(RegExp(r"/+$"), "")}$path')
        .replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = _accessToken;
      if (token == null) throw const PlanitApiException('로그인이 필요합니다.');
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = _url(path, query);
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
        case 'POST':
          response = await http.post(uri, headers: headers,
              body: body == null ? null : jsonEncode(body));
        case 'PUT':
          response = await http.put(uri, headers: headers,
              body: body == null ? null : jsonEncode(body));
        case 'PATCH':
          response = await http.patch(uri, headers: headers,
              body: body == null ? null : jsonEncode(body));
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
        default:
          throw const PlanitApiException('지원하지 않는 HTTP 메서드입니다.');
      }
    } catch (error) {
      if (error is PlanitApiException) rethrow;
      throw PlanitApiException('서버 연결에 실패했습니다: $error');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw PlanitApiException('서버 응답을 해석할 수 없습니다. HTTP ${response.statusCode}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      final message = detail is String
          ? detail
          : detail is Map && detail['message'] is String
              ? detail['message'] as String
              : '서버 요청이 실패했습니다. HTTP ${response.statusCode}';
      throw PlanitApiException(message, statusCode: response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PlanitApiException('서버 응답 형식이 올바르지 않습니다.');
    }
    return decoded;
  }

  Future<void> login(String id, String password) async {
    final result = await request('POST', '/auth/login',
        body: {'id': id, 'password': password}, authenticated: false);
    final token = result['access_token'];
    if (token is! String || token.isEmpty) {
      throw const PlanitApiException('로그인 토큰을 받지 못했습니다.');
    }
    _accessToken = token;
  }

  Future<void> signup({
    required String id,
    required String nickname,
    required String password,
    required String passwordConfirm,
    required String email,
    required String name,
    required String phone,
  }) async {
    await request('POST', '/auth/signup', authenticated: false, body: {
      'id': id, 'nickname': nickname, 'password': password,
      'password_confirm': passwordConfirm, 'email': email,
      'name': name, 'phone': phone,
    });
  }

  Future<bool> isIdAvailable(String id) async {
    final result = await request('GET', '/auth/check-id',
        query: {'id': id}, authenticated: false);
    return result['available'] == true;
  }
}

class PlanitApiException implements Exception {
  const PlanitApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
