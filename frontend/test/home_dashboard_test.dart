import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/calendar_event.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/screens/home_dashboard.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/rooms/ai_result_screen.dart';
import 'package:meetsync/screens/rooms/room_detail_screen.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';

CalendarEvent event(
  String id,
  DateTime start, {
  EventRepeat repeat = EventRepeat.none,
}) => CalendarEvent(
  id: id,
  title: id,
  start: start,
  end: start.add(const Duration(hours: 1)),
  repeat: repeat,
);

PlanRoom room(
  String id,
  DateTime date, {
  bool submitted = false,
  RoomStatus status = RoomStatus.collecting,
}) => PlanRoom(
  id: id,
  title: id,
  date: date,
  region: '성수',
  inviteCode: id,
  members: [RoomMember(name: '나', submitted: submitted)],
  status: status,
  course: status == RoomStatus.recommended
      ? const [CourseStop(time: '18:00', title: '카페', description: '차 한 잔')]
      : [],
);

Future<CalendarController> openHomeCalendar(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: HomeScreen(loginId: 'planner')),
  );
  await tester.tap(find.byTooltip('캘린더'));
  await tester.pumpAndSettle();
  return tester.widget<CalendarScreen>(find.byType(CalendarScreen)).controller;
}

Future<void> returnHome(WidgetTester tester) async {
  await tester.tap(find.byTooltip('홈으로 돌아가기'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'D-day uses calendar dates and follows edits, deletion and room date removal',
    () {
      final rooms = RoomsController(rooms: []);
      final calendar = CalendarController(roomsController: rooms);
      addTearDown(rooms.dispose);
      addTearDown(calendar.dispose);
      final now = DateTime(2026, 11, 17, 23, 59);
      expect(calendarDdayLabel(DateTime(2026, 11, 18, 0, 1), now), 'D-1');
      expect(calendarDdayLabel(DateTime(2026, 11, 17), now), 'D-DAY');
      expect(calendarDdayLabel(DateTime(2026, 11, 16), now), 'D+1');
      calendar.save(event('near', DateTime(2026, 11, 18, 18)));
      calendar.save(event('chosen', DateTime(2026, 12, 1)));
      expect(calendar.featuredEntry(now)!.event.id, 'near');
      calendar.setDday('chosen');
      expect(calendar.featuredEntry(now)!.event.id, 'chosen');
      calendar.save(event('chosen', DateTime(2026, 11, 16)));
      expect(calendarDdayLabel(calendar.featuredEntry(now)!.start, now), 'D+1');
      calendar.delete('chosen');
      expect(calendar.ddayEventId, isNull);
      expect(calendar.featuredEntry(now)!.event.id, 'near');
      rooms.addRoom(room('room', DateTime(2026, 12, 1)));
      calendar.setDday('room-room');
      rooms.setDate('room', DateTime(2026, 12, 3));
      expect(calendar.featuredEntry(now)!.start, DateTime(2026, 12, 3));
      rooms.setDate('room', null);
      expect(calendar.ddayEventId, isNull);
      expect(calendar.featuredEntry(now)!.event.id, 'near');
      expect(() => calendar.setDday('missing'), throwsArgumentError);
    },
  );

  test(
    'Home chooses active and next recurring occurrences including leap-century gaps',
    () {
      final monthly = event(
        'monthly',
        DateTime(2026, 1, 31, 10),
        repeat: EventRepeat.monthly,
      );
      expect(
        monthly.nextEntry(DateTime(2026, 2, 1))!.start,
        DateTime(2026, 3, 31, 10),
      );
      expect(
        monthly.nextEntry(DateTime(2026, 3, 31, 10, 30))!.start,
        DateTime(2026, 3, 31, 10),
      );
      expect(
        monthly.nextEntry(DateTime(2026, 3, 31, 11))!.start,
        DateTime(2026, 5, 31, 10),
      );
      final leap = event(
        'leap',
        DateTime(2096, 2, 29, 10),
        repeat: EventRepeat.yearly,
      );
      expect(
        leap.nextEntry(DateTime(2097, 1, 1))!.start,
        DateTime(2104, 2, 29, 10),
      );
      final rooms = RoomsController(rooms: []);
      final calendar = CalendarController(roomsController: rooms);
      addTearDown(rooms.dispose);
      addTearDown(calendar.dispose);
      calendar.save(monthly);
      calendar.setDday('monthly');
      expect(
        calendar.featuredEntry(DateTime(2026, 2, 1))!.start,
        DateTime(2026, 3, 31, 10),
      );
      expect(
        calendar.featuredEntry(DateTime(2026, 4, 1))!.start,
        DateTime(2026, 5, 31, 10),
      );
    },
  );

  testWidgets(
    'Home selects, searches, opens, changes and clears one D-day at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calendar = await openHomeCalendar(tester);
      final now = DateTime.now();
      final near = DateTime(now.year, now.month, now.day + 2, 18);
      final chosen = DateTime(now.year, now.month, now.day + 8, 9);
      calendar.save(event('nearest', near));
      calendar.save(event('chosen', chosen));
      await returnHome(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
            .data,
        'nearest',
      );
      expect(find.text('이번 주 일정'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-dday-select')),
      );
      await tester.tap(find.byKey(const ValueKey('home-dday-select')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('dday-search')),
        'chosen',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('dday-choice-chosen')),
      );
      await tester.tap(find.byKey(const ValueKey('dday-choice-chosen')));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(calendar.ddayEventId, 'chosen');
      expect(find.text('나의 D-day'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('home-dday-label'))).data,
        'D-8',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-featured-event')),
      );
      await tester.tap(find.byKey(const ValueKey('home-featured-event')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CalendarScreen>(find.byType(CalendarScreen)).initialDate,
        chosen,
      );
      await returnHome(tester);
      expect(calendar.ddayEventId, 'chosen');
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-dday-select')),
      );
      await tester.tap(find.byKey(const ValueKey('home-dday-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dday-choice-nearest')));
      await tester.pumpAndSettle();
      expect(calendar.ddayEventId, 'nearest');
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-dday-select')),
      );
      await tester.tap(find.byKey(const ValueKey('home-dday-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clear-home-dday')));
      await tester.pumpAndSettle();
      expect(calendar.ddayEventId, isNull);
      expect(find.text('다가오는 약속'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home tasks open preferences and prepared courses and update when completed',
    (tester) async {
      final calendar = await openHomeCalendar(tester);
      final date = DateTime.now().add(const Duration(days: 2));
      final rooms = calendar.roomsController;
      rooms.addRoom(room('preference', date));
      rooms.addRoom(
        room(
          'course',
          date.add(const Duration(days: 1)),
          submitted: true,
          status: RoomStatus.recommended,
        ),
      );
      rooms.addRoom(
        room('confirmed', date, submitted: true, status: RoomStatus.confirmed),
      );
      rooms.addRoom(room('past', date.subtract(const Duration(days: 10))));
      await returnHome(tester);
      expect(HomePlanTask.forRooms(rooms.rooms, DateTime.now()).length, 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-task-preference')),
      );
      await tester.tap(find.byKey(const ValueKey('home-task-preference')));
      await tester.pumpAndSettle();
      expect(find.byType(RoomDetailScreen), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('room-preference')));
      await tester.enterText(
        find.byKey(const ValueKey('room-preference')),
        '카페에서 이야기하고 싶어요',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-room-preference')),
      );
      await tester.tap(find.byKey(const ValueKey('save-room-preference')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-task-preference')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-task-course')),
      );
      await tester.tap(find.byKey(const ValueKey('home-task-course')));
      await tester.pumpAndSettle();
      expect(find.byType(AiResultScreen), findsOneWidget);
      rooms.confirm('course');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-task-course')), findsNothing);
      expect(find.text('지금은 할 일이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty D-day picker can create a calendar event and pin it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(loginId: 'planner')),
    );
    expect(
      find.byKey(const ValueKey('home-create-first-plan')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('home-dday-select')));
    await tester.pumpAndSettle();
    expect(find.text('아직 등록된 일정이 없어요.'), findsOneWidget);
    await tester.tap(find.text('새 일정 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-title')),
      'My plan',
    );
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-dday-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dday-choice-personal-0')));
    await tester.pumpAndSettle();
    expect(find.text('나의 D-day'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
          .data,
      'My plan',
    );
    expect(tester.takeException(), isNull);
  });
}
