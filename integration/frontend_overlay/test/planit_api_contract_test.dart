import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/services/planit_api.dart';

void main() {
  test('signup fields are sent intact to the authoritative API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://planit.example.com/auth/signup');
      expect(request.headers['content-type'], 'application/json');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['id'], 'tester_1');
      expect(body['email'], 'tester@example.com');
      expect(body['nickname'], '테스터');
      expect(body['password_confirm'], body['password']);
      return http.Response('{"id":"tester_1","message":"Account created."}', 201);
    });
    final api = PlanitApi(client: client, baseUrlOverride: 'https://planit.example.com/');
    final result = await api.request('POST', '/auth/signup', authenticated: false, body: {
      'id': 'tester_1',
      'email': 'tester@example.com',
      'nickname': '테스터',
      'password': 'valid-password',
      'password_confirm': 'valid-password',
    });
    expect(result['id'], 'tester_1');
  });

  test('region lookup percent-encodes Korean input and surfaces invalid regions', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/places/validate-region');
      expect(request.url.queryParameters['query'], 'ㅁㄴㅇㄹ 해외');
      return http.Response(
        jsonEncode({'valid': false, 'message': '서비스 제공 가능 지역이 아닙니다.'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = PlanitApi(client: client, baseUrlOverride: 'https://planit.example.com');
    final response = await api.request('GET', '/places/validate-region',
        authenticated: false, query: {'query': 'ㅁㄴㅇㄹ 해외'});
    expect(response['valid'], false);
  });

  test('invite code containing #@! is JSON, never URL fragment', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rooms/join');
      expect(request.url.fragment, isEmpty);
      expect(jsonDecode(request.body)['invite_code'], 'AB2#C@!');
      return http.Response('{"joined":true}', 200);
    });
    final api = PlanitApi(client: client, baseUrlOverride: 'https://planit.example.com');
    final response = await api.request('POST', '/rooms/join',
      authenticated: false, body: {'invite_code': 'AB2#C@!'});
    expect(response['joined'], true);
  });

  test('API input validation message and status are preserved', () async {
    final api = PlanitApi(
      baseUrlOverride: 'https://planit.example.com',
      client: MockClient((_) async => http.Response(
        jsonEncode({'detail': '서비스 제공 가능 지역이 아닙니다.'}),
        422,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
    );
    await expectLater(
      api.request('GET', '/places/validate-region',
        authenticated: false, query: {'query': 'wrong'}),
      throwsA(isA<PlanitApiException>()
        .having((e) => e.statusCode, 'statusCode', 422)
        .having((e) => e.message, 'message', '서비스 제공 가능 지역이 아닙니다.')),
    );
  });

  test('structured backend error is shown without leaking raw JSON', () async {
    final api = PlanitApi(
      baseUrlOverride: 'https://planit.example.com',
      client: MockClient((_) async => http.Response(
        jsonEncode({'detail': {'message': '아직 조건을 제출하지 않은 참여자가 있습니다.'}}),
        409,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
    );
    await expectLater(
      api.request('POST', '/rooms/abc/recommend', authenticated: false),
      throwsA(isA<PlanitApiException>().having(
        (e) => e.message, 'message', '아직 조건을 제출하지 않은 참여자가 있습니다.')),
    );
  });

  test('malformed success payload is an actionable response error', () async {
    final api = PlanitApi(
      baseUrlOverride: 'https://planit.example.com',
      client: MockClient((_) async => http.Response('not-json', 200)),
    );
    await expectLater(
      api.request('GET', '/health', authenticated: false),
      throwsA(isA<PlanitApiException>().having(
        (e) => e.message, 'message', contains('서버 응답이 올바르지 않습니다.'))),
    );
  });

  test('missing or malformed URL is rejected before any network request', () async {
    for (final origin in ['', 'not a url', 'https://planit.example.com?secret=oops']) {
      final api = PlanitApi(
        baseUrlOverride: origin,
        client: MockClient((_) async => throw StateError('must not send network request')),
      );
      await expectLater(
        api.request('GET', '/health', authenticated: false),
        throwsA(isA<PlanitApiException>()),
      );
    }
  });
}
