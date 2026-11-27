import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/user_profile.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/screens/signup_screen.dart';
import 'package:meetsync/services/firebase_accounts.dart';
import 'package:meetsync/services/profile_repository.dart';

class _TestAccounts extends FirebaseAccounts {
  int attempts = 0;
  String? password;
  UserProfile? saved;

  @override
  Future<ProfileRepository> register({
    required String id,
    required String email,
    required String password,
    required String nickname,
    Uint8List? photo,
  }) async {
    attempts++;
    this.password = password;
    final profile = UserProfile(
      userId: 'test-uid',
      loginId: id,
      email: email,
      nickname: nickname,
      photoBytes: photo,
    );
    saved = profile;
    return MemoryProfileRepository(initialProfile: profile);
  }
}

void main() {
  testWidgets('Signup validates credentials before saving the profile', (
    tester,
  ) async {
    final accounts = _TestAccounts();
    await tester.pumpWidget(
      MaterialApp(home: SignupScreen(accounts: accounts)),
    );

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    expect(find.text('닉네임'), findsNothing);
    await tester.enterText(fields.at(0), 'Planner24');
    await tester.enterText(fields.at(1), 'planner@example.com');
    await tester.enterText(fields.at(2), 'test-password');
    await tester.enterText(fields.at(3), 'different-password');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(accounts.attempts, 0);

    await tester.enterText(fields.at(3), 'test-password');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('프로필 사진 선택'), findsOneWidget);
    expect(fields, findsOneWidget);
    expect(accounts.attempts, 0);

    await tester.tap(find.text('회원가입 완료'));
    await tester.pumpAndSettle();
    expect(find.text('닉네임은 2~12자로 입력해 주세요.'), findsOneWidget);
    expect(accounts.attempts, 0);

    await tester.enterText(fields, '테스트 플래너');
    await tester.tap(find.text('회원가입 완료'));
    await tester.pumpAndSettle();
    expect(accounts.attempts, 1);
    expect(accounts.saved?.loginId, 'Planner24');
    expect(accounts.saved?.email, 'planner@example.com');
    expect(accounts.saved?.nickname, '테스트 플래너');
    expect(accounts.password, 'test-password');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignupScreen, skipOffstage: false), findsNothing);
  });
}
