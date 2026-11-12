import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/main.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/login_screen.dart';
import 'package:meetsync/services/planit_api.dart';

Future<void> enterCredentials(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'planner');
  await tester.enterText(find.byType(TextField).last, 'password123');
  await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
  await tester.pumpAndSettle();
}

void main() {
  final api = PlanitApi.instance;
  setUp(api.clearSession);
  tearDown(api.clearSession);

  testWidgets('App starts at login and rejects empty credentials', (tester) async {
    await tester.pumpWidget(const MeetSyncApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('아이디와 비밀번호를 입력해 주세요.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Rejected backend credentials never start a local preview session',
      (tester) async {
    api.replaceHttpClientForTesting(MockClient((request) async {
      expect(request.url.path, '/auth/login');
      return http.Response(
        jsonEncode({'detail': '아이디 또는 비밀번호가 일치하지 않습니다.'}),
        401,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
    await tester.pumpWidget(const MeetSyncApp());
    await tester.pumpAndSettle();
    await enterCredentials(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('아이디 또는 비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(api.hasSession, isFalse);
  });

  testWidgets('Successful backend login loads server rooms, not demo rooms',
      (tester) async {
    final seen = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'verified-test-token'}), 200);
      }
      expect(request.headers['authorization'], 'Bearer verified-test-token');
      if (request.url.path == '/rooms') {
        return http.Response(jsonEncode({
          'rooms': [
            {
              'room_id': 'server-room-1',
              'title': '서버에서 불러온 약속',
              'invite_code': 'AB2#C@!',
              'member_uids': ['uid-1'],
              'max_members': 4
            }
          ]
        }), 200);
      }
      if (request.url.path == '/calendar/room-appointments') {
        return http.Response(jsonEncode({'events': []}), 200);
      }
      if (request.url.path == '/calendar/events' ||
          request.url.path == '/calendar/recurring-events') {
        return http.Response(jsonEncode({'events': []}), 200);
      }
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }));
    await tester.pumpWidget(const MeetSyncApp());
    await tester.pumpAndSettle();
    await enterCredentials(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('서버에서 불러온 약속'), findsOneWidget);
    expect(find.text('우리의 느긋한 주말'), findsNothing);
    expect(seen, contains('GET /rooms'));
    expect(api.hasSession, isTrue);
  });
}
