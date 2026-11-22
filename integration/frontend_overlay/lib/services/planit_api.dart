import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// All application data is authoritative on FastAPI/Firebase.
class PlanitApi {
  PlanitApi({http.Client? client, String? baseUrlOverride})
      : _baseUrl = baseUrlOverride ?? baseUrl,
        _client = client ?? http.Client();

  static const baseUrl = String.fromEnvironment('PLANIT_API_BASE_URL');
  final http.Client _client;
  final String _baseUrl;

  Uri _url(String path, [Map<String, String>? query]) {
    if (_baseUrl.trim().isEmpty) {
      throw const PlanitApiException('서버 주소가 설정되지 않았습니다. PLANIT_API_BASE_URL을 확인하세요.');
    }
    final origin = Uri.tryParse(_baseUrl.trim());
    if (origin == null || !{'http', 'https'}.contains(origin.scheme) ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        origin.hasQuery || origin.hasFragment) {
      throw const PlanitApiException('서버 주소 형식이 올바르지 않습니다.');
    }
    final normalized = _baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$normalized$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw const PlanitApiException('로그인이 필요합니다.');
      final token = await user.getIdToken();
      if (token == null) throw const PlanitApiException('인증 토큰을 가져오지 못했습니다.');
      headers['Authorization'] = 'Bearer $token';
    }
    http.Response response;
    try {
      final url = _url(path, query);
      final payload = body == null ? null : jsonEncode(body);
      response = await (switch (method) {
        'GET' => _client.get(url, headers: headers),
        'POST' => _client.post(url, headers: headers, body: payload),
        'PUT' => _client.put(url, headers: headers, body: payload),
        'PATCH' => _client.patch(url, headers: headers, body: payload),
        'DELETE' => _client.delete(url, headers: headers),
        _ => throw ArgumentError.value(method),
      }).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const PlanitApiException('서버 응답이 지연되고 있습니다. 다시 시도해 주세요.');
    } on PlanitApiException {
      rethrow;
    } catch (_) {
      throw const PlanitApiException('서버에 연결할 수 없습니다. 인터넷과 서버 주소를 확인하세요.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw PlanitApiException('서버 응답이 올바르지 않습니다. (HTTP ${response.statusCode})');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = decoded is Map ? decoded : const {};
      final detail = data['detail'];
      final message = detail is String
          ? detail
          : detail is Map ? (detail['message']?.toString() ?? '요청을 처리하지 못했습니다.') : '요청을 처리하지 못했습니다.';
      throw PlanitApiException(message, statusCode: response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PlanitApiException('서버 데이터 형식이 올바르지 않습니다.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> validateRegion(String text) =>
      request('GET', '/places/validate-region', query: {'query': text});

  Future<List<Map<String, dynamic>>> searchPlaces(String text) async {
    final result = await request('GET', '/places/search', query: {'query': text});
    return (result['places'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createRoom(String title, int maxMembers) =>
      request('POST', '/rooms', body: {'title': title, 'max_members': maxMembers});

  Future<Map<String, dynamic>> joinRoom(String code) =>
      request('POST', '/rooms/join', body: {'invite_code': code});

  Future<List<Map<String, dynamic>>> listRooms() async {
    final result = await request('GET', '/rooms');
    return (result['rooms'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> getRoom(String roomId) =>
      request('GET', '/rooms/${Uri.encodeComponent(roomId)}');

  Future<Map<String, dynamic>> myRoomPreferences(String roomId) =>
      request('GET', '/rooms/${Uri.encodeComponent(roomId)}/preferences/me');
}

class PlanitApiException implements Exception {
  const PlanitApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
