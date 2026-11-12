import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/screens/login_screen.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/rooms/room_detail_screen.dart';
import 'package:meetsync/services/planit_api.dart';

Future<void> settleNetwork(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Real browser UI logs in and creates a persisted room', (tester) async {
    final unique = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final id = ('ui$unique').substring(0, 11);
    const password = 'UITest_AA12345';

    // Firebase Admin/Auth emulator creates an actual user through FastAPI.
    // Stage markers also surface in GitHub Actions Chrome test logs.
    print('E2E_STAGE: before_signup');
    await tester.runAsync(() => PlanitApi.instance.signup(
      id: id,
      nickname: 'UiTest${id.substring(id.length - 4)}',
      password: password,
      passwordConfirm: password,
      email: '$id@example.com',
      name: 'UI E2E',
      phone: '01012345678',
    ));

    print('E2E_STAGE: after_signup');
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(find.byType(TextField).at(0), id);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));

    print('E2E_STAGE: login_clicked');
    for (var attempt = 0; attempt < 20; attempt++) {
      await settleNetwork(tester);
      if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
    }
    final visibleText = tester.widgetList<Text>(find.byType(Text))
        .map((item) => item.data)
        .whereType<String>()
        .take(35)
        .toList();
    print('E2E_STAGE: after_login_wait; home=${find.byType(HomeScreen).evaluate().length}; visible=$visibleText');
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'User should reach the home screen only with a real Firebase token');

    print('E2E_STAGE: home_rendered');
    await tester.tap(find.text('약속방 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('방 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Browser E2E outing');
    await tester.tap(find.byTooltip('방 생성 완료'));
    for (var attempt = 0; attempt < 20; attempt++) {
      await settleNetwork(tester);
      if (find.text('방이 만들어졌어요! 🎉').evaluate().isNotEmpty) break;
    }
    final roomText = tester.widgetList<Text>(find.byType(Text))
        .map((item) => item.data)
        .whereType<String>()
        .take(35)
        .toList();
    print('E2E_STAGE: create_room_wait_completed; visible=$roomText');
    expect(find.text('방이 만들어졌어요! 🎉'), findsOneWidget);
    final result = await tester.runAsync(
        () => PlanitApi.instance.request('GET', '/rooms'));
    final rooms = result?['rooms'] as List<dynamic>? ?? [];
    expect(rooms.any((room) => room is Map && room['title'] == 'Browser E2E outing'), true,
        reason: 'Room creation UI must persist to the actual Firestore emulator');

    final createdRoom = rooms.firstWhere(
        (room) => room is Map && room['title'] == 'Browser E2E outing') as Map;
    final roomId = createdRoom['room_id'].toString();
    print('E2E_STAGE: before_room_schedule');
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browser E2E outing').last);
    await tester.pumpAndSettle();
    expect(find.byType(RoomDetailScreen), findsOneWidget);
    await tester.tap(find.text('약속 날짜 정하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택').last);
    for (var attempt = 0; attempt < 20; attempt++) {
      await settleNetwork(tester);
      final events = await tester.runAsync(
          () => PlanitApi.instance.request('GET', '/calendar/room-appointments'));
      if ((events?['events'] as List<dynamic>? ?? [])
          .any((event) => event is Map && event['room_id'] == roomId)) break;
    }
    final shared = await tester.runAsync(
        () => PlanitApi.instance.request('GET', '/calendar/room-appointments'));
    expect((shared?['events'] as List<dynamic>? ?? [])
        .any((event) => event is Map && event['room_id'] == roomId), true,
        reason: 'UI-picked room date must persist to official Firestore emulator');
    print('E2E_STAGE: browser_schedule_saved');
    PlanitApi.instance.clearSession();
  });
}
