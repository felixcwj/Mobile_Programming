import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/main.dart';
import 'package:meetsync/models/calendar_event.dart';
import 'helpers/scroll_time.dart';
import 'package:meetsync/screens/create_room_screen.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/screens/rooms/room_detail_screen.dart';
import 'package:meetsync/screens/rooms/room_widgets.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/home_widgets.dart';
import 'package:meetsync/screens/login_screen.dart';

Future<void> logIn(WidgetTester tester, {String id = 'planner'}) async {
  await tester.enterText(find.byType(TextField).first, id);
  await tester.enterText(find.byType(TextField).last, 'preview-password');
  final button = find.widgetWithText(ElevatedButton, '로그인');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> selectRoomSchedule(WidgetTester tester, DateTime date) async {
  await tester.ensureVisible(find.byKey(const ValueKey('room-date')));
  await tester.tap(find.byKey(const ValueKey('room-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final dateField = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextField),
  );
  final material = MaterialLocalizations.of(tester.element(dateField));
  await tester.enterText(dateField, material.formatCompactDate(date));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('선택'));
  await tester.tap(find.text('선택'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('room-time')));
  await tester.tap(find.byKey(const ValueKey('room-time')));
  await tester.pumpAndSettle();
  await selectScrollTime(tester, date.hour, date.minute);
  await tester.ensureVisible(find.text('선택'));
  await tester.tap(find.text('선택'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App starts at login and rejects empty credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const MeetSyncApp(initialLocale: Locale('ko')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    final button = find.widgetWithText(ElevatedButton, '로그인');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('아이디와 비밀번호를 입력해 주세요.'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Login, profile edits and logout use the same local session', (
    tester,
  ) async {
    await tester.pumpWidget(const MeetSyncApp(initialLocale: Locale('ko')));
    await tester.pumpAndSettle();
    await logIn(tester);
    expect(find.text('Planit'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-rooms')), findsNothing);
    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('나의 정보'), findsOneWidget);
    await tester.ensureVisible(find.text('나의 정보 수정'));
    await tester.tap(find.text('나의 정보 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '수정한 플래너');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.scrollUntilVisible(
      find.text('변경사항 저장'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('수정한 플래너'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('로그아웃'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await logIn(tester, id: 'another-user');
    await tester.tap(find.byTooltip('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('플래너'), findsOneWidget);
    expect(find.text('수정한 플래너'), findsNothing);
  });

  testWidgets('Scheduled rooms appear in home, room list and calendar', (
    tester,
  ) async {
    await tester.pumpWidget(const MeetSyncApp(initialLocale: Locale('ko')));
    await tester.pumpAndSettle();
    await logIn(tester);
    await tester.tap(find.byTooltip('약속방 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 방'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('또는 코드 참가'));
    await tester.tap(find.text('또는 코드 참가'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateRoomScreen), findsNothing);
    expect(find.text('코드 참가'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('약속방 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 방'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '함께하는 주말');
    await tester.tap(find.byKey(const ValueKey('room-category-work')));
    await tester.pumpAndSettle();
    final appointment = DateTime(2026, 12, 25, 18, 30);
    await selectRoomSchedule(tester, appointment);
    await tester.tap(find.byTooltip('방 생성 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
          .data,
      '함께하는 주말',
    );
    expect(find.byKey(const ValueKey('home-rooms')), findsOneWidget);
    expect(find.text('내 약속방'), findsOneWidget);
    await tester.tap(find.byTooltip('약속방 추가'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HomeAddMenu),
        matching: find.text('내 약속방'),
      ),
      findsNothing,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-rooms')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('함께하는 주말'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('함께하는 주말'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${roomDate(appointment, context: tester.element(find.byType(RoomDetailScreen)))} · 지역 미정',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('입력 완료 0/1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('입력 완료 0/1'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Planit'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
          .data,
      '함께하는 주말',
    );
    expect(find.byKey(const ValueKey('home-rooms')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-rooms')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('함께하는 주말'));
    await tester.pumpAndSettle();
    expect(find.text('우리의 약속'), findsOneWidget);
    expect(find.text('함께하는 주말'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('캘린더'));
    await tester.pumpAndSettle();
    final calendar = tester.widget<CalendarScreen>(find.byType(CalendarScreen));
    final event = calendar.controller.events.single;
    expect(event.title, '함께하는 주말');
    expect(event.start, appointment);
    expect(event.category, EventCategory.work);
    expect(event.roomId, isNotNull);
    await tester.tap(find.byTooltip('일정 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '함께하는 주말');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '함께하는 주말'));
    await tester.pumpAndSettle();
    final agenda = find.byKey(
      ValueKey('agenda-${event.id}-${appointment.toIso8601String()}'),
    );
    await tester.ensureVisible(agenda);
    expect(find.text('18:30 · 업무'), findsOneWidget);
    await tester.tap(agenda);
    await tester.pumpAndSettle();
    final detail = tester.widget<RoomDetailScreen>(
      find.byType(RoomDetailScreen),
    );
    expect(detail.roomId, event.roomId);
    expect(detail.controller.room(detail.roomId).date, appointment);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Room creation requires a schedule and saves it at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CreatedRoom? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                created = await Navigator.of(context).push<CreatedRoom>(
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                );
              },
              child: const Text('새 방 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('새 방 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('방 생성 완료'));
    await tester.pumpAndSettle();
    expect(created, isNull);
    expect(find.text('날짜와 시간을 선택해 주세요.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('날짜 선택'), findsOneWidget);
    final appointment = DateTime(2026, 12, 25, 18, 30);
    await selectRoomSchedule(tester, appointment);
    expect(find.text('날짜와 시간을 선택해 주세요.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('room-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('18:30'), findsOneWidget);
    await tester.tap(find.byTooltip('방 생성 완료'));
    await tester.pumpAndSettle();
    expect(created?.name, '새 약속방');
    expect(created?.capacity, 8);
    expect(created?.category, EventCategory.personal);
    expect(created?.date, appointment);
    expect(created?.code.length, 7);
    expect(tester.takeException(), isNull);
  });
}
