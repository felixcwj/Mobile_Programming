import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/screens/rooms/room_preferences_screen.dart';
import 'package:meetsync/services/planit_api.dart';

void main() {
  testWidgets('Room preferences restore saved answers and hide departure in fixed mode', (tester) async {
    final api = PlanitApi.instance;
    api.clearSession();
    final paths = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      paths.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'token', 'uid': 'tester'}), 200);
      }
      if (request.url.path == '/rooms/room1') {
        return http.Response(jsonEncode({
          'room_id': 'room1', 'meeting_mode': 'fixed', 'meeting_region': '강남역',
        }), 200);
      }
      if (request.url.path == '/rooms/room1/preferences') {
        return http.Response(jsonEncode({'members': [
          {'uid': 'tester', 'submitted': true, 'preferences': {
            'budget': 17000,
            'region': '강남역',
            'departure_location': '강남역',
            'available_date': '2026-11-21',
            'start_time': '13:00',
            'end_time': '17:00',
            'activities': ['전시', '카페'],
            'additional_notes': '조용한 곳',
          }},
        ]}), 200);
      }
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }));
    await api.login('tester', 'password123');
    addTearDown(api.clearSession);
    await tester.pumpWidget(const MaterialApp(
      home: RoomPreferencesScreen(roomId: 'room1'),
    ));
    await tester.pumpAndSettle();
    final error = find.textContaining('저장된 조건을 불러오지 못했습니다');
    if (error.evaluate().isNotEmpty) {
      fail(tester.widget<Text>(error).data ?? 'Unknown preference load error');
    }
    expect(tester.widget<TextFormField>(
      find.byKey(const ValueKey('roomBudget'))).controller!.text, '17000');
    expect(tester.widget<TextFormField>(
      find.byKey(const ValueKey('roomMeetingArea'))).controller!.text, '강남역');
    expect(find.byKey(const ValueKey('roomDeparture')), findsNothing);
    expect(paths, contains('GET /rooms/room1/preferences'));
    expect(find.text('특정 장소'), findsOneWidget);
  });

  testWidgets('Room preference retrieval failure blocks overwriting existing data', (tester) async {
    final api = PlanitApi.instance;
    api.clearSession();
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'token', 'uid': 'tester'}), 200);
      }
      return http.Response(jsonEncode({'detail': 'temporary error'}), 503);
    }));
    await api.login('tester', 'password123');
    addTearDown(api.clearSession);
    await tester.pumpWidget(const MaterialApp(
      home: RoomPreferencesScreen(roomId: 'room1'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장된 조건을 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('저장하기'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
