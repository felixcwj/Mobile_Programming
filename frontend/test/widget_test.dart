import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/main.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/login_screen.dart';

Future<void> logIn(WidgetTester tester, {String id = 'planner'}) async {
  await tester.enterText(find.byType(TextField).first, id);
  await tester.enterText(find.byType(TextField).last, 'preview-password');
  final button = find.widgetWithText(ElevatedButton, '로그인');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App starts at login and rejects empty credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const MeetSyncApp());
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
    await tester.pumpWidget(const MeetSyncApp());
    await tester.pumpAndSettle();
    await logIn(tester);
    expect(find.text('내 약속방'), findsOneWidget);
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

  testWidgets('Created rooms are shared by home, room list and details', (
    tester,
  ) async {
    await tester.pumpWidget(const MeetSyncApp());
    await tester.pumpAndSettle();
    await logIn(tester);
    await tester.tap(find.byTooltip('내 방'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('약속 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '함께하는 주말');
    await tester.tap(find.byTooltip('방 생성 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('함께하는 주말'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('함께하는 주말'));
    await tester.pumpAndSettle();
    expect(find.text('친구들의 취향  0/1'), findsOneWidget);
    expect(find.text('날짜 미정 · 지역 미정'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1개의 방'), findsOneWidget);
    await tester.tap(find.text('함께하는 주말'));
    await tester.pumpAndSettle();
    expect(find.text('우리의 약속'), findsOneWidget);
    expect(find.text('함께하는 주말'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
