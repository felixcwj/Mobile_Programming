import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/services/planit_api.dart';
import 'package:meetsync/models/user_profile.dart';
import 'package:meetsync/screens/profile/profile_screen.dart';
import 'package:meetsync/screens/profile/support_screen.dart';
import 'package:meetsync/services/profile_repository.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Profile opens empty appointment history and support on a small screen',
    (tester) async {
      PlanitApi.instance.replaceHttpClientForTesting(MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response('{"access_token":"testing-id-token"}', 200);
        }
        if (request.url.path == '/mypage/appointments') {
          return http.Response('{"appointments":[],"count":0}', 200);
        }
        return http.Response('{"detail":"not found"}', 404);
      }));
      await PlanitApi.instance.login('test', 'test');
      addTearDown(PlanitApi.instance.clearSession);
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            repository: MemoryProfileRepository(
              initialProfile: UserProfile(
                userId: 'test',
                nickname: '플래너',
                email: 'preview@example.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('약속 내역'));
      await tester.tap(find.text('약속 내역'));
      await tester.pumpAndSettle();
      expect(find.text('아직 약속 없음'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('고객센터'));
      await tester.tap(find.text('고객센터'));
      await tester.pumpAndSettle();
      expect(find.text('1:1 문의'), findsOneWidget);
      await reveal(tester, find.text('메일 앱으로 보내기'));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '메일 앱으로 보내기'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('Empty inquiry never opens an email composer', (tester) async {
    var launches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SupportScreen(
          supportEmail: 'support@example.com',
          launchEmail: (_) async {
            launches++;
            return true;
          },
        ),
      ),
    );
    await reveal(tester, find.text('메일 앱으로 보내기'));
    await tester.tap(find.text('메일 앱으로 보내기'));
    await tester.pumpAndSettle();
    expect(launches, 0);
    expect(find.text('문의 제목과 내용을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets(
    'Mail URI encodes Korean and special characters; failure keeps the draft',
    (tester) async {
      Uri? uri;
      await tester.pumpWidget(
        MaterialApp(
          home: SupportScreen(
            supportEmail: 'support@example.com',
            launchEmail: (value) async {
              uri = value;
              return false;
            },
          ),
        ),
      );
      await reveal(tester, find.byKey(const ValueKey('supportSubject')));
      await tester.enterText(
        find.byKey(const ValueKey('supportSubject')),
        '문의 & 도움 + 질문',
      );
      await reveal(tester, find.byKey(const ValueKey('supportMessage')));
      await tester.enterText(
        find.byKey(const ValueKey('supportMessage')),
        '첫 줄 + 공백\n다음 줄 & 내용',
      );
      await reveal(tester, find.text('메일 앱으로 보내기'));
      await tester.tap(find.text('메일 앱으로 보내기'));
      await tester.pumpAndSettle();
      expect(uri!.scheme, 'mailto');
      expect(uri!.path, 'support@example.com');
      expect(uri!.queryParameters['subject'], '[플랜잇 1:1 문의] 문의 & 도움 + 질문');
      expect(uri!.queryParameters['body'], '첫 줄 + 공백\n다음 줄 & 내용');
      expect(find.text('메일 앱을 열지 못했어요. 메일 앱 설정을 확인해 주세요.'), findsOneWidget);
      final state = tester.state(find.byType(SupportScreen));
      expect(state.mounted, isTrue);
      await reveal(tester, find.byKey(const ValueKey('supportSubject')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('supportSubject')))
            .controller!
            .text,
        '문의 & 도움 + 질문',
      );
    },
  );

  testWidgets('Opening a composer does not report an inquiry as sent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SupportScreen(
          supportEmail: 'support@example.com',
          launchEmail: (_) async => true,
        ),
      ),
    );
    await reveal(tester, find.byKey(const ValueKey('supportSubject')));
    await tester.enterText(find.byKey(const ValueKey('supportSubject')), '문의');
    await reveal(tester, find.byKey(const ValueKey('supportMessage')));
    await tester.enterText(
      find.byKey(const ValueKey('supportMessage')),
      '확인 부탁드립니다.',
    );
    await reveal(tester, find.text('메일 앱으로 보내기'));
    await tester.tap(find.text('메일 앱으로 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('메일 작성 화면을 열었어요. 메일 앱에서 전송을 완료해 주세요.'), findsOneWidget);
  });
}
