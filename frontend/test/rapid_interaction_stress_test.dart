import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/models/calendar_event.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/screens/rooms/rooms_screen.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';

void main() {
  testWidgets('Rapid scrolling through 160 rooms never throws or loses cards',
      (tester) async {
    final rooms = RoomsController(rooms: [
      for (var i = 0; i < 160; i++)
        PlanRoom(
          id: 'stress-$i',
          title: '빠른 스크롤 테스트 $i',
          inviteCode: 'TEST-$i',
          region: '강남',
          members: const [RoomMember(name: 'tester', submitted: true)],
        ),
    ]);
    addTearDown(rooms.dispose);
    await tester.pumpWidget(MaterialApp(
      home: RoomsScreen(controller: rooms),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.fling(
        find.byType(CustomScrollView), const Offset(0, -1600), 6000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(rooms.rooms, hasLength(160));
    await tester.fling(
      find.byType(CustomScrollView), const Offset(0, 3000), 7000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rapid calendar swipes and month controls do not crash',
      (tester) async {
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(calendar.dispose);
    addTearDown(rooms.dispose);
    for (var i = 0; i < 100; i++) {
      calendar.save(CalendarEvent(
        id: 'stress-$i',
        title: '일정 $i',
        start: DateTime(2026, 11, i + 1, 10),
        end: DateTime(2026, 11, i + 1, 11),
        repeat: i.isEven ? EventRepeat.weekly : EventRepeat.none,
      ));
    }
    await tester.pumpWidget(MaterialApp(
      home: CalendarScreen(
        controller: calendar, today: DateTime(2026, 11, 12)),
    ));
    for (var i = 0; i < 25; i++) {
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    for (var i = 0; i < 25; i++) {
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('2026년 11월'), findsOneWidget);
    final scrollable = find.byType(SingleChildScrollView);
    if (scrollable.evaluate().isNotEmpty) {
      for (var i = 0; i < 10; i++) {
        await tester.fling(
          scrollable.first, const Offset(0, -950), 4000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
