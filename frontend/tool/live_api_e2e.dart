// Connect the actual Flutter/Dart HTTP gateway to the running FastAPI server
// backed by official Firebase Auth and Firestore emulators.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meetsync/services/planit_api.dart';

void check(bool value, String description) {
  if (!value) throw StateError('FAILED: $description');
  stdout.writeln('PASS $description');
}

Future<void> main() async {
  final baseUrl = Platform.environment['PLANIT_E2E_URL'] ?? 'http://127.0.0.1:8765';
  final client = http.Client();
  final api = PlanitApi.instance;
  api.replaceHttpClientForTesting(client, baseUrl: baseUrl);
  final id = 'dart${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  final password = 'Test_12345Aa';
  try {
    check(await api.isIdAvailable(id), 'Dart client: available ID');
    await api.signup(
      id: id,
      nickname: 'DartTester${id.substring(id.length - 4)}',
      password: password,
      passwordConfirm: password,
      email: '$id@example.com',
      name: 'Dart tester',
      phone: '01012345678',
    );
    check(!api.hasSession, 'Signup does not fake a login session');
    await api.login(id, password);
    check(api.hasSession, 'Dart client: real Firebase ID token login');
    final me = await api.request('GET', '/users/me');
    check(me['id'] == id, 'Dart token is accepted by actual FastAPI auth');

    final created = await api.request('POST', '/rooms', body: {
      'title': 'Dart API e2e room',
      'max_members': 2,
    });
    final roomId = created['room_id'].toString();
    final invite = created['invite_code'].toString();
    check(invite.length == 7 && invite.contains(RegExp(r'[#!@]')),
        'Dart client receives genuine server invite');

    final joined = await api.request('POST', '/rooms/join', body: {
      'invite_code': invite,
    });
    check(joined['joined'] == false, 'Joining an already joined room is idempotent');

    final time = DateTime(2026, 12, 12, 13).toUtc().toIso8601String();
    final scheduled = await api.request('PUT', '/rooms/$roomId/schedule', body: {
      'starts_at': time, 'version': 0,
    });
    check(scheduled['schedule']['version'] == 1, 'Shared schedule persisted over HTTP');
    final calendar = await api.request('GET', '/calendar/room-appointments');
    check((calendar['events'] as List).any((e) => e['room_id'] == roomId),
        'Room date visible via Flutter calendar API');

    final event = await api.request('POST', '/calendar/events', body: {
      'title': 'Dart private class',
      'starts_at': DateTime(2026, 12, 12, 9).toUtc().toIso8601String(),
      'ends_at': DateTime(2026, 12, 12, 10).toUtc().toIso8601String(),
      'repeat': 'weekly',
      'category': 'school',
    });
    final eventId = event['id'].toString();
    check(event['repeat'] == 'weekly', 'Recurring private event is saved in Firestore');
    final recurring = await api.request('GET', '/calendar/recurring-events');
    check((recurring['events'] as List).any((e) => e['id'] == eventId),
        'Dart client reads recurring event back');
    await api.request('DELETE', '/calendar/events/$eventId',
        query: {'version': '1'});
    final empty = await api.request('GET', '/calendar/recurring-events');
    check(!(empty['events'] as List).any((e) => e['id'] == eventId),
        'Dart client can remove private event');

    api.clearSession();
    check(!api.hasSession, 'Logout clears in-memory session');
    stdout.writeln('REAL FLUTTER/DART CLIENT -> FASTAPI -> FIREBASE EMULATOR E2E PASSED');
  } finally {
    api.clearSession();
    client.close();
  }
}
