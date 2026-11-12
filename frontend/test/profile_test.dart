import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/user_profile.dart';
import 'package:meetsync/screens/profile/account_edit_screen.dart';
import 'package:meetsync/screens/profile/edit_preferences_screen.dart';
import 'package:meetsync/screens/profile/edit_profile_screen.dart';
import 'package:meetsync/screens/profile/profile_screen.dart';
import 'package:meetsync/services/profile_repository.dart';

UserProfile initialProfile() => UserProfile(
  userId: 'test-user',
  nickname: '플래너',
  email: 'planner@example.com',
  loginId: 'planner',
  preferences: const BasicPreferences(mbti: 'INFP'),
);

class FailingRepository implements ProfileRepository {
  bool failLoad = true;
  @override
  Future<UserProfile> load() async {
    if (failLoad) throw StateError('offline');
    return initialProfile();
  }

  @override
  Future<void> save(UserProfile profile) async => throw StateError('offline');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('Age respects birthday and unanswered values remain optional', () {
    final p = BasicPreferences(birthDate: DateTime(2000, 11, 3), hasCar: false);
    expect(p.ageAt(DateTime(2026, 11, 2)), 25);
    expect(p.ageAt(DateTime(2026, 11, 3)), 26);
    expect(p.answeredCount, 2);
    expect(const BasicPreferences().answeredCount, 0);
  });

  test('Profile photo is copied, immutable and can be cleared', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final profile = initialProfile().copyWith(photoBytes: bytes);
    bytes[0] = 9;
    expect(profile.photoBytes![0], 1);
    expect(() => profile.photoBytes![0] = 9, throwsUnsupportedError);
    expect(profile.copyWith(removePhoto: true).photoBytes, isNull);
  });

  testWidgets(
    'Personal edits preserve preferences; cancelled edits do not save',
    (tester) async {
      final repository = MemoryProfileRepository(
        initialProfile: initialProfile(),
      );
      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('나의 정보 수정'));
      expect(find.text('선호 지역'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('nickname')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const ValueKey('nickname')), '새 닉네임');
      await tapVisible(tester, find.text('저장하기'));
      final saved = await repository.load();
      expect(saved.nickname, '새 닉네임');
      expect(saved.homeAddress, isEmpty);
      expect(saved.preferences.mbti, 'INFP');
      expect(saved.loginId, 'planner');
      await tapVisible(tester, find.text('나의 정보 수정'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('nickname')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const ValueKey('nickname')), '취소할 이름');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await repository.load()).nickname, '새 닉네임');
    },
  );

  testWidgets(
    'Questionnaire rejects invalid birthdays and saves independently',
    (tester) async {
      final repository = MemoryProfileRepository(
        initialProfile: initialProfile(),
      );
      await tester.pumpWidget(
        MaterialApp(home: ProfileScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('나의 기본 성향'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '여성'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('birthDate')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('birthDate')),
        '2001-02-29',
      );
      await tapVisible(tester, find.text('저장하기'));
      expect(find.byType(EditPreferencesScreen), findsOneWidget);
      expect((await repository.load()).preferences.birthDate, isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('birthDate')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('birthDate')),
        '2000-02-29',
      );
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '외부 활동'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '4'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('livingArea')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('livingArea')),
        '서울 마포구',
      );
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '없어요'));
      await tapVisible(tester, find.text('저장하기'));
      final saved = await repository.load();
      expect(saved.preferences.gender, '여성');
      expect(saved.preferences.birthDate, DateTime(2000, 2, 29));
      expect(saved.preferences.activityPreference, ActivityPreference.outdoor);
      expect(saved.preferences.drinkingEnjoyment, 4);
      expect(saved.preferences.livingArea, '서울 마포구');
      expect(saved.preferences.hasCar, false);
      expect(saved.nickname, '플래너');
      expect(saved.homeAddress, isEmpty);
    },
  );

  testWidgets('Account forms do not pretend to change authentication', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AccountEditScreen(editPassword: true)),
    );
    expect(find.widgetWithText(TextFormField, '현재 비밀번호'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '새 비밀번호 확인'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '변경하기'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(
      const MaterialApp(home: AccountEditScreen(editPassword: false)),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '새 아이디'), findsOneWidget);
  });

  testWidgets('Load retries and save errors keep personal edits', (
    tester,
  ) async {
    final repository = FailingRepository();
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('프로필을 불러오지 못했어요.'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('나의 정보 수정'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('nickname')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const ValueKey('nickname')), '다시 저장할 이름');
    await tapVisible(tester, find.text('저장하기'));
    expect(find.text('저장하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('Failed profile load still allows logout and back navigation', (tester) async {
    var logoutCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ProfileScreen(
              repository: FailingRepository(),
              onLogout: () async { logoutCalls++; },
            )),
          ),
          child: const Text('프로필 열기'),
        ),
      )),
    ));
    await tester.tap(find.text('프로필 열기'));
    await tester.pumpAndSettle();
    expect(find.text('프로필을 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('이전 화면으로'), findsOneWidget);
    expect(find.text('로그아웃하고 다시 로그인'), findsOneWidget);
    await tester.tap(find.text('로그아웃하고 다시 로그인'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();
    expect(logoutCalls, 1);
    await tester.tap(find.text('이전 화면으로'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 열기'), findsOneWidget);
  });

  testWidgets('Logout delegates only after confirming', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: MemoryProfileRepository(initialProfile: initialProfile()),
          onLogout: () async {
            calls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('로그아웃'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
