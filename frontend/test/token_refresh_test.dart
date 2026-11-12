import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/services/planit_api.dart';

void main() {
  final api = PlanitApi.instance;
  setUp(api.clearSession);
  tearDown(api.clearSession);

  test('A 401 refreshes an expired ID token and retries once', () async {
    var refreshCalls = 0;
    var protectedCalls = 0;
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({
          'access_token': 'expired-id-token', 'refresh_token': 'refresh-A',
          'uid': 'tester', 'expires_in': 3600,
        }), 200);
      }
      if (request.url.path == '/auth/refresh') {
        refreshCalls++;
        expect(request.headers.containsKey('authorization'), isFalse);
        final payload = jsonDecode(request.body);
        expect(payload['refresh_token'], 'refresh-A');
        return http.Response(jsonEncode({
          'access_token': 'new-id-token', 'refresh_token': 'refresh-B',
          'uid': 'tester', 'expires_in': 3600,
        }), 200);
      }
      if (request.url.path == '/rooms') {
        protectedCalls++;
        if (request.headers['authorization'] == 'Bearer expired-id-token') {
          return http.Response(jsonEncode({'detail': 'expired'}), 401);
        }
        expect(request.headers['authorization'], 'Bearer new-id-token');
        return http.Response(jsonEncode({'rooms': []}), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 404);
    }));
    await api.login('tester', 'password123');
    final result = await api.request('GET', '/rooms');
    expect(result['rooms'], isEmpty);
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
    expect(api.hasSession, isTrue);
  });

  test('Multiple expired requests share the same refresh', () async {
    var refreshCalls = 0;
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({
          'access_token': 'expired', 'refresh_token': 'refresh-A',
          'uid': 'tester',
        }), 200);
      }
      if (request.url.path == '/auth/refresh') {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(jsonEncode({
          'access_token': 'renewed', 'refresh_token': 'refresh-B', 'uid': 'tester',
        }), 200);
      }
      if (request.headers['authorization'] == 'Bearer expired') {
        return http.Response(jsonEncode({'detail': 'expired'}), 401);
      }
      expect(request.headers['authorization'], 'Bearer renewed');
      return http.Response(jsonEncode({'value': true}), 200);
    }));
    await api.login('tester', 'password123');
    final responses = await Future.wait([
      api.request('GET', '/a'),
      api.request('GET', '/b'),
      api.request('GET', '/c'),
    ]);
    expect(responses.every((r) => r['value'] == true), isTrue);
    expect(refreshCalls, 1);
  });

  test('Rejected refresh ends the session instead of looping', () async {
    var refreshCalls = 0;
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({
          'access_token': 'expired', 'refresh_token': 'revoked',
          'uid': 'tester',
        }), 200);
      }
      if (request.url.path == '/auth/refresh') {
        refreshCalls++;
        return http.Response(jsonEncode({'detail': 'refresh revoked'}), 401);
      }
      return http.Response(jsonEncode({'detail': 'expired'}), 401);
    }));
    await api.login('tester', 'password123');
    await expectLater(
      api.request('GET', '/rooms'),
      throwsA(isA<PlanitApiException>()),
    );
    expect(refreshCalls, 1);
    expect(api.hasSession, isFalse);
  });
}
