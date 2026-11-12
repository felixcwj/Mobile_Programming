import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/services/planit_api.dart';
import 'package:meetsync/services/rooms_controller.dart';

void main() {
  final api = PlanitApi.instance;

  setUp(() {
    api.clearSession();
  });

  test('signup and id availability use backend validation endpoints', () async {
    final paths = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      paths.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/check-id') {
        expect(request.url.queryParameters['id'], 'planner_1');
        return http.Response(jsonEncode({'id': 'planner_1', 'available': true}), 200);
      }
      if (request.url.path == '/auth/signup') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['id'], 'planner_1');
        expect(body['password_confirm'], body['password']);
        return http.Response(jsonEncode({'message': 'ok', 'id': 'planner_1'}), 201);
      }
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }));
    expect(await api.isIdAvailable('planner_1'), isTrue);
    await api.signup(
      id: 'planner_1',
      nickname: '플래너',
      password: 'password123',
      passwordConfirm: 'password123',
      email: 'demo@example.com',
      name: '테스트',
      phone: '01012345678',
    );
    expect(paths, ['GET /auth/check-id', 'POST /auth/signup']);
  });

  test('login token is used for room create and join operations', () async {
    final seen = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/login') {
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(jsonEncode({
          'access_token': 'example-firebase-id-token',
          'refresh_token': 'not-persisted',
          'expires_in': 3600,
          'uid': 'user1',
        }), 200);
      }
      expect(request.headers['authorization'], 'Bearer example-firebase-id-token');
      if (request.url.path == '/rooms' && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['max_members'], 3);
        return http.Response(jsonEncode({'room_id': 'server-generated-id',
          'invite_code': 'AB2#C@!'}), 201);
      }
      if (request.url.path == '/rooms/join') {
        expect((jsonDecode(request.body) as Map)['invite_code'], 'AB2#C@!');
        return http.Response(jsonEncode({'room_id': 'server-generated-id', 'joined': true}), 200);
      }
      if (request.url.path == '/rooms') {
        return http.Response(jsonEncode({'rooms': [
          {'room_id': 'server-generated-id', 'title': '나들이', 'invite_code': 'AB2#C@!',
           'member_uids': ['user1', 'user2'], 'max_members': 3}
        ]}), 200);
      }
      if (request.url.path == '/calendar/room-appointments') {
        return http.Response(jsonEncode({'events': []}), 200);
      }
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }));
    await api.login('planner', 'password123');
    final controller = RoomsController(rooms: []);
    final created = await controller.createRemoteRoom('나들이', 3);
    expect(created.id, 'server-generated-id');
    expect(created.inviteCode, 'AB2#C@!');
    await controller.joinRemoteRoom('AB2#C@!');
    expect(controller.rooms.length, 1);
    expect(controller.rooms.single.id, 'server-generated-id');
    expect(seen, containsAllInOrder([
      'POST /auth/login', 'POST /rooms', 'POST /rooms/join',
      'GET /rooms', 'GET /calendar/room-appointments'
    ]));
    controller.dispose();
    api.clearSession();
    expect(() => api.request('GET', '/rooms'), throwsA(isA<PlanitApiException>()));
  });

  test('invalid password never grants a session', () async {
    api.replaceHttpClientForTesting(MockClient((request) async {
      return http.Response(jsonEncode({'detail': '아이디 또는 비밀번호가 일치하지 않습니다.'}), 401);
    }));
    await expectLater(api.login('wrong', 'wrong'), throwsA(isA<PlanitApiException>()));
    expect(api.hasSession, isFalse);
  });
}
