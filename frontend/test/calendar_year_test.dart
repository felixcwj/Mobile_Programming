import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/services/planit_api.dart';

void main() {
  testWidgets('Fast year switch eventually loads the final selected year', (tester) async {
    final api = PlanitApi.instance;
    api.clearSession();
    addTearDown(api.clearSession);
    final requestedYears = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response('{"access_token":"test-calendar-token"}', 200);
      }
      if (request.url.path == '/calendar/events') {
        final from = request.url.queryParameters['starts_from'] ?? '';
        requestedYears.add(from.substring(0, 4));
        final entries = from.startsWith('2027') ? [{
          'id': 'future-appointment', 'title': '2027년 미래 일정',
          'starts_at': '2027-01-16T12:00:00+09:00',
          'ends_at': '2027-01-16T13:00:00+09:00',
          'version': 1, 'category': 'personal',
        }] : [];
        return http.Response.bytes(utf8.encode(jsonEncode({'events': entries})),
          200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{"events":[]}', 200);
    }));
    await api.login('tester', 'password');
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(calendar.dispose);
    addTearDown(rooms.dispose);
    await calendar.loadRemote(year: 2026);
    await tester.pumpWidget(MaterialApp(
      home: CalendarScreen(controller: calendar,
        today: DateTime(2026, 12, 15)),
    ));
    await tester.tap(find.byTooltip('다음 달'));
    await tester.pump();
    expect(find.text('2027년 1월'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(calendar.events.any((e) => e.title == '2027년 미래 일정'), isTrue);
    expect(requestedYears, contains('2027'));
    expect(tester.takeException(), isNull);
  });
}
