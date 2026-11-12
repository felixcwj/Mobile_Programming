import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/services/planit_api.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';

void main() {
  final api = PlanitApi.instance;
  setUp(api.clearSession);
  tearDown(api.clearSession);

  test('Closing rooms during slow server fetch does not throw', () async {
    final pending = Completer<http.Response>();
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'test-token'}), 200);
      }
      if (request.url.path == '/rooms') return pending.future;
      if (request.url.path == '/calendar/room-appointments') {
        return http.Response('{"events":[]}', 200);
      }
      return http.Response('{}', 200);
    }));
    await api.login('testuser', 'pw');
    final rooms = RoomsController(rooms: []);
    final loading = rooms.loadRemote();
    await Future<void>.delayed(Duration.zero);
    rooms.dispose();
    pending.complete(http.Response('{"rooms":[]}', 200));
    await loading;
  });

  test('Closing calendar during slow server fetch does not throw', () async {
    final pending = Completer<http.Response>();
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response('{"access_token":"test-token"}', 200);
      }
      if (request.url.path == '/calendar/events') return pending.future;
      return http.Response('{"events":[]}', 200);
    }));
    await api.login('testuser', 'pw');
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    final loading = calendar.loadRemote();
    await Future<void>.delayed(Duration.zero);
    calendar.dispose();
    rooms.dispose();
    pending.complete(http.Response('{"events":[]}', 200));
    await loading;
  });

  test('Stale calendar fetch cannot overwrite a newer result', () async {
    final oldPending = Completer<http.Response>();
    var fetches = 0;
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response('{"access_token":"test-token"}', 200);
      }
      if (request.url.path == '/calendar/events') {
        fetches++;
        if (fetches == 1) return oldPending.future;
        return http.Response(jsonEncode({'events': [{
          'id': 'latest', 'title': '최신 일정',
          'starts_at': '2026-11-12T12:00:00+09:00',
          'ends_at': '2026-11-12T13:00:00+09:00',
          'version': 1, 'category': 'personal',
        }]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{"events":[]}', 200);
    }));
    await api.login('testuser', 'pw');
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(calendar.dispose);
    addTearDown(rooms.dispose);
    final first = calendar.loadRemote();
    await Future<void>.delayed(Duration.zero);
    await calendar.loadRemote();
    oldPending.complete(http.Response('{"events":[]}', 200));
    await first;
    expect(calendar.events.single.title, '최신 일정');
  });
}
