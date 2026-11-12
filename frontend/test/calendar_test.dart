import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/calendar_event.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/screens/calendar/event_editor_sheet.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/rooms/room_detail_screen.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';

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

  testWidgets('Personal events validate, save, repeat, edit and delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(rooms.dispose);
    addTearDown(calendar.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          controller: calendar,
          today: DateTime(2026, 11, 12),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('add-calendar-event')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    expect(find.text('제목을 입력해 주세요.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('event-title')), '독서 모임');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('save-event')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-all-day')));
    await tester.tap(find.byTooltip('반복 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매주'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('캘린더 분류'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대학'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('알림 시간 설정'));
    await tester.tap(find.byTooltip('알림 시간 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30분 전'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    expect(calendar.events.single.allDay, isTrue);
    expect(calendar.events.single.category, EventCategory.school);
    expect(calendar.events.single.reminderMinutes, 30);
    expect(calendar.entriesOn(DateTime(2026, 11, 19)), hasLength(1));
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, '독서 모임'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, '독서 모임'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-title')),
      '수정한 독서 모임',
    );
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    expect(calendar.events.single.title, '수정한 독서 모임');
    await tester.tap(find.widgetWithText(ListTile, '수정한 독서 모임'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('일정 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(calendar.events, isEmpty);
    expect(find.byType(EventEditorSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home calendar button retains personal events across routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(loginId: 'planner')),
    );
    await tester.tap(find.byTooltip('캘린더'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-calendar-event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('event-title')), '개인 일정');
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('홈으로 돌아가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('캘린더'));
    await tester.pumpAndSettle();
    expect(find.text('개인 일정'), findsWidgets);
  });

  testWidgets('Room date controls add and remove the linked calendar event', (
    tester,
  ) async {
    final rooms = RoomsController(
      rooms: [
        PlanRoom(
          id: 'new-room',
          title: '저녁 약속',
          region: '지역 미정',
          inviteCode: 'TEST123',
          members: const [RoomMember(name: '나', submitted: false)],
        ),
      ],
    );
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(rooms.dispose);
    addTearDown(calendar.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RoomDetailScreen(roomId: 'new-room', controller: rooms),
      ),
    );
    expect(calendar.events, isEmpty);
    await tester.tap(find.text('약속 날짜 정하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    final date = rooms.room('new-room').date!;
    expect(calendar.entriesOn(date).single.event.roomId, 'new-room');
    expect(find.text('약속 날짜 변경'), findsOneWidget);
    await tester.tap(find.text('일정 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '일정 해제'));
    await tester.pumpAndSettle();
    expect(calendar.events, isEmpty);
    expect(rooms.room('new-room').date, isNull);
    expect(tester.takeException(), isNull);
  });
}
