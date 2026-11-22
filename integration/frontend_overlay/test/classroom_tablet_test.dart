import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meetsync/main.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/login_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Android 13 Lenovo 800x1280 login and fast gestures',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MeetSyncApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('팀 서버 연결'), findsOneWidget);

    await tester.tap(find.text('팀 서버 연결'));
    await tester.pumpAndSettle();
    expect(find.text('팀 서버 연결'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('planit-server-url')),
      'http://public.example.com',
    );
    await tester.tap(find.text('연결 확인 및 저장'));
    await tester.pumpAndSettle();
    expect(find.text('HTTPS 주소 또는 내부망 IP 주소를 확인해 주세요.'),
        findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    final scroll = find.byKey(const ValueKey('login-scroll'));
    for (var i = 0; i < 20; i++) {
      await tester.fling(scroll, const Offset(0, -300), 2600);
      await tester.pump(const Duration(milliseconds: 25));
      await tester.fling(scroll, const Offset(0, 300), 2600);
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('login-id')));
    await tester.enterText(find.byKey(const ValueKey('login-id')), 'lenovo');
    await tester.enterText(
        find.byKey(const ValueKey('login-password')), 'preview-password');
    final submit = find.byKey(const ValueKey('login-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('캘린더'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('홈으로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
