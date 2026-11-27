import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/calendar_event.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/widgets/scroll_time_picker.dart';

import 'helpers/scroll_time.dart';

void main() {
  testWidgets(
    'Selected day opens start time directly and allows a two-day event',
    (tester) async {
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
            today: DateTime(2026, 11, 16),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-17')));
      await tester.tap(find.byKey(const ValueKey('add-calendar-event')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('event-title')),
        'Two days',
      );

      await tester.tap(find.byKey(const ValueKey('event-start')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(ScrollTimePicker), findsOneWidget);
      await selectScrollTime(tester, 24, 0);
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-start')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('selected-scroll-time')))
            .data,
        '24:00',
      );
      await selectScrollTime(tester, 18, 30);
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-start')));
      await tester.pumpAndSettle();
      await selectScrollTime(tester, 20, 0);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('18:30'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('event-end')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        '11/18/2026',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await selectScrollTime(tester, 12, 0);
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-event')));
      await tester.pumpAndSettle();
      expect(calendar.events.single.start, DateTime(2026, 11, 17, 18, 30));
      expect(calendar.events.single.end, DateTime(2026, 11, 18, 12));
      expect(calendar.entriesOn(DateTime(2026, 11, 17)), hasLength(1));
      expect(calendar.entriesOn(DateTime(2026, 11, 18)), hasLength(1));
      expect(calendar.entriesOn(DateTime(2026, 11, 19)), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Time wheels support minutes, 24:00, 00:00 and cancellation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showScrollTimePicker(
                  context,
                  initialMinutes: 23 * 60 + 59,
                  title: 'Time',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('23:59'), findsOneWidget);
    await selectScrollTime(tester, 24, 0);
    expect(find.text('24:00'), findsOneWidget);
    final minuteWheel = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('time-minute-wheel')),
    );
    expect(minuteWheel.childDelegate.estimatedChildCount, 1);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(result, 1440);
    expect(
      scrollTimeOnDate(DateTime(2026, 12, 31), result!),
      DateTime(2027, 1, 1),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await selectScrollTime(tester, 0, 0);
    expect(find.text('00:00'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('time-minute-wheel')),
      const Offset(0, -40),
    );
    await tester.pumpAndSettle();
    expect(find.text('00:01'), findsOneWidget);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(result, 1);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Event end at 24:00 survives editing and excludes the next day', (
    tester,
  ) async {
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(rooms.dispose);
    addTearDown(calendar.dispose);
    calendar.save(
      CalendarEvent(
        id: 'night',
        title: 'Night',
        start: DateTime(2026, 11, 17, 23),
        end: DateTime(2026, 11, 17, 23, 30),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          controller: calendar,
          today: DateTime(2026, 11, 17),
        ),
      ),
    );
    final agenda = find.byKey(
      ValueKey('agenda-night-${DateTime(2026, 11, 17, 23).toIso8601String()}'),
    );
    await tester.ensureVisible(agenda);
    await tester.tap(agenda);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await selectScrollTime(tester, 24, 0);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(find.text('24:00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    expect(calendar.events.single.end, DateTime(2026, 11, 18));
    expect(calendar.entriesOn(DateTime(2026, 11, 18)), isEmpty);
    expect(find.text('23:00 – 24:00 · 개인'), findsOneWidget);
    await tester.tap(agenda);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-end')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      DateTime(2026, 11, 17),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('selected-scroll-time')))
          .data,
      '24:00',
    );
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-event')));
    await tester.pumpAndSettle();
    expect(calendar.events.single.end, DateTime(2026, 11, 18));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Category colors update room and personal events and survive reopening',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime(2026, 11, 17, 18);
      final rooms = RoomsController(
        rooms: [
          PlanRoom(
            id: 'work-room',
            title: 'Work room',
            date: date,
            region: '',
            inviteCode: 'WORK123',
            members: [],
            category: EventCategory.work,
          ),
        ],
      );
      final calendar = CalendarController(roomsController: rooms);
      addTearDown(rooms.dispose);
      addTearDown(calendar.dispose);
      calendar.save(
        CalendarEvent(
          id: 'work',
          title: 'Work event',
          start: date,
          end: date.add(const Duration(hours: 1)),
          category: EventCategory.work,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarScreen(controller: calendar, today: date),
        ),
      );
      expect(find.text('Planit'), findsOneWidget);
      await tester.tap(find.byTooltip('달력 설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('분류별 색상'));
      await tester.pumpAndSettle();
      final swatch = find.byTooltip('업무 빨강');
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
      expect(calendar.colorFor(EventCategory.work), 0xFFC15D5D);
      expect(
        calendar.colorFor(EventCategory.personal),
        EventCategory.personal.colorValue,
      );
      await tester.tap(find.byTooltip('색상 설정 닫기'));
      await tester.pumpAndSettle();
      for (final id in ['room-work-room', 'work']) {
        final agenda = find.byKey(
          ValueKey('agenda-$id-${date.toIso8601String()}'),
        );
        await tester.ensureVisible(agenda);
        final icon = tester.widget<Icon>(
          find.descendant(of: agenda, matching: find.byType(Icon)),
        );
        expect(icon.color, const Color(0xFFC15D5D));
      }
      rooms.setDate('work-room', DateTime(2026, 12, 1));
      expect(
        calendar.events.singleWhere((event) => event.roomId != null).category,
        EventCategory.work,
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarScreen(controller: calendar, today: date),
        ),
      );
      expect(calendar.colorFor(EventCategory.work), 0xFFC15D5D);
      expect(tester.takeException(), isNull);
    },
  );
}
