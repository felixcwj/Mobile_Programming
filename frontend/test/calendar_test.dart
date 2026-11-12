import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/calendar_event.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/screens/calendar/event_editor_sheet.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/services/planit_api.dart';

CalendarEvent sampleEvent({
  String id = 'personal-test',
  String title = '나의 일정',
  DateTime? start,
  DateTime? end,
  bool allDay = false,
  EventRepeat repeat = EventRepeat.none,
}) => CalendarEvent(
  id: id,
  title: title,
  start: start ?? DateTime(2026, 11, 12, 16),
  end: end ?? DateTime(2026, 11, 12, 17),
  allDay: allDay,
  repeat: repeat,
);

void main() {
  test(
    'Multi-day events include covered days and exclude the end boundary',
    () {
      final event = sampleEvent(
        start: DateTime(2026, 11, 12),
        end: DateTime(2026, 11, 15),
        allDay: true,
      );
      expect(event.entriesOn(DateTime(2026, 11, 11)), isEmpty);
      expect(event.entriesOn(DateTime(2026, 11, 12)), hasLength(1));
      expect(event.entriesOn(DateTime(2026, 11, 14)), hasLength(1));
      expect(event.entriesOn(DateTime(2026, 11, 15)), isEmpty);
      final overnight = sampleEvent(
        start: DateTime(2026, 11, 12, 23),
        end: DateTime(2026, 11, 13, 1),
      );
      expect(overnight.entriesOn(DateTime(2026, 11, 13)), hasLength(1));
    },
  );

  test(
    'Repeats respect start dates, weekdays, month lengths and leap years',
    () {
      final weekly = sampleEvent(repeat: EventRepeat.weekly);
      expect(weekly.entriesOn(DateTime(2026, 11, 5)), isEmpty);
      expect(
        weekly.entriesOn(DateTime(2026, 11, 19)).single.start,
        DateTime(2026, 11, 19, 16),
      );
      expect(weekly.entriesOn(DateTime(2026, 11, 20)), isEmpty);
      final monthly = sampleEvent(
        start: DateTime(2026, 1, 31, 16),
        end: DateTime(2026, 1, 31, 17),
        repeat: EventRepeat.monthly,
      );
      expect(monthly.entriesOn(DateTime(2026, 2, 28)), isEmpty);
      expect(monthly.entriesOn(DateTime(2026, 3, 31)), hasLength(1));
      final leap = sampleEvent(
        start: DateTime(2024, 2, 29, 16),
        end: DateTime(2024, 2, 29, 17),
        repeat: EventRepeat.yearly,
      );
      expect(leap.entriesOn(DateTime(2025, 2, 28)), isEmpty);
      expect(leap.entriesOn(DateTime(2028, 2, 29)), hasLength(1));
    },
  );

  test(
    'Room scheduling, rescheduling and clearing update without duplicates',
    () {
      final rooms = RoomsController.demo();
      final calendar = CalendarController(roomsController: rooms);
      addTearDown(rooms.dispose);
      addTearDown(calendar.dispose);
      final date = DateTime(2026, 11, 12, 18);
      rooms.setDate('after-work', date);
      expect(
        calendar
            .entriesOn(date)
            .where((entry) => entry.event.roomId == 'after-work'),
        hasLength(1),
      );
      expect(rooms.confirm('after-work'), isTrue);
      expect(
        calendar.events.where((event) => event.roomId == 'after-work'),
        hasLength(1),
      );
      final later = DateTime(2026, 12, 3, 18);
      rooms.setDate('after-work', later);
      expect(
        calendar
            .entriesOn(date)
            .where((entry) => entry.event.roomId == 'after-work'),
        isEmpty,
      );
      expect(
        calendar.entriesOn(later).single.event.category,
        EventCategory.appointment,
      );
      rooms.setDate('after-work', null);
      expect(
        calendar.events.where((event) => event.roomId == 'after-work'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Month navigation, today, week settings and search work at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rooms = RoomsController(rooms: []);
      final calendar = CalendarController(roomsController: rooms);
      addTearDown(rooms.dispose);
      addTearDown(calendar.dispose);
      calendar.save(sampleEvent());
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarScreen(
            controller: calendar,
            today: DateTime(2026, 11, 12),
          ),
        ),
      );
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 12월'), findsOneWidget);
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle();
      expect(find.text('2027년 1월'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-day-2027-2-6')),
        findsOneWidget,
      );
      await tester.tap(find.text('TODAY'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 11월 12일 (목)'), findsOneWidget);
      await tester.tap(find.byTooltip('달력 설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckedPopupMenuItem<String>).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('calendar-day-2026-10-26')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('일정 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '나의 일정');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '나의 일정'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selected-date')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );


  test('Personal event create, update and deletion follow server state', () async {
    final api = PlanitApi.instance;
    api.clearSession();
    Map<String, dynamic>? stored;
    var version = 0;
    final seen = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'calendar-token'}), 200);
      }
      expect(request.headers['authorization'], 'Bearer calendar-token');
      if (request.url.path == '/calendar/events' && request.method == 'POST') {
        stored = {
          ...jsonDecode(request.body) as Map<String, dynamic>,
          'id': 'remote-personal-1',
          'version': ++version,
        };
        return http.Response(jsonEncode({'event': stored}), 201);
      }
      if (request.url.path == '/calendar/events/remote-personal-1' &&
          request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['version'], version);
        stored = {...body, 'id': 'remote-personal-1', 'version': ++version};
        return http.Response(jsonEncode({'event': stored}), 200);
      }
      if (request.url.path == '/calendar/events/remote-personal-1' &&
          request.method == 'DELETE') {
        expect(request.url.queryParameters['version'], '$version');
        stored = null;
        return http.Response(jsonEncode({'deleted': true}), 200);
      }
      if (request.url.path == '/calendar/events') {
        return http.Response(jsonEncode({'events': stored == null ? [] : [stored]}), 200);
      }
      if (request.url.path == '/calendar/recurring-events' ||
          request.url.path == '/calendar/room-appointments') {
        return http.Response(jsonEncode({'events': []}), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected route'}), 404);
    }));
    await api.login('planner', 'password123');
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    try {
      await calendar.saveRemote(sampleEvent(title: '독서 모임'));
      expect(calendar.events.single.title, '독서 모임');
      expect(calendar.events.single.id, 'remote-personal-1');
      await calendar.saveRemote(sampleEvent(
        id: 'remote-personal-1',
        title: '수정한 독서 모임',
        repeat: EventRepeat.weekly,
      ));
      expect(calendar.events.single.title, '수정한 독서 모임');
      expect(calendar.entriesOn(DateTime(2026, 11, 19)), hasLength(1));
      await calendar.deleteRemote('remote-personal-1');
      expect(calendar.events, isEmpty);
      expect(seen, containsAllInOrder([
        'POST /calendar/events',
        'PUT /calendar/events/remote-personal-1',
        'DELETE /calendar/events/remote-personal-1',
      ]));
    } finally {
      calendar.dispose();
      rooms.dispose();
      api.clearSession();
    }
  });

  testWidgets('Failed server save keeps editor open and does not fake persistence',
      (tester) async {
    final api = PlanitApi.instance;
    api.clearSession();
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(rooms.dispose);
    addTearDown(calendar.dispose);
    await tester.pumpWidget(MaterialApp(
      home: CalendarScreen(
        controller: calendar,
        today: DateTime(2026, 11, 12),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('add-calendar-event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('event-title')), '저장 실패 일정');
    await tester.ensureVisible(find.byKey(const ValueKey('save-event')));
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditorSheet), findsOneWidget);
    expect(calendar.events, isEmpty);
    expect(find.textContaining('일정을 저장하지 못했습니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Room schedule updates calendar only after successful HTTP write', () async {
    final api = PlanitApi.instance;
    api.clearSession();
    var scheduleVersion = 0;
    String? scheduledAt;
    api.replaceHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'schedule-token'}), 200);
      }
      expect(request.headers['authorization'], 'Bearer schedule-token');
      if (request.url.path == '/rooms/new-room/schedule' &&
          request.method == 'GET') {
        return http.Response(jsonEncode({
          'schedule': scheduleVersion == 0
              ? null
              : {'version': scheduleVersion, 'starts_at': scheduledAt}
        }), 200);
      }
      if (request.url.path == '/rooms/new-room/schedule' &&
          request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['version'], scheduleVersion);
        scheduledAt = body['starts_at']?.toString();
        scheduleVersion++;
        return http.Response(jsonEncode({
          'schedule': {'version': scheduleVersion, 'starts_at': scheduledAt}
        }), 200);
      }
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }));
    await api.login('planner', 'password123');
    final rooms = RoomsController(rooms: [
      PlanRoom(
        id: 'new-room',
        title: '저녁 약속',
        region: '지역 미정',
        inviteCode: 'TEST123',
        members: const [RoomMember(name: '나', submitted: false)],
      ),
    ]);
    final calendar = CalendarController(roomsController: rooms);
    try {
      final date = DateTime(2026, 11, 12, 18);
      await rooms.saveRemoteSchedule('new-room', date);
      expect(calendar.entriesOn(date).single.event.roomId, 'new-room');
      await rooms.saveRemoteSchedule('new-room', null);
      expect(rooms.room('new-room').date, isNull);
      expect(calendar.events, isEmpty);
      expect(scheduleVersion, 2);
    } finally {
      calendar.dispose();
      rooms.dispose();
      api.clearSession();
    }
  });
}
