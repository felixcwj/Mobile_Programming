import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meetsync/l10n/language_settings.dart';
import 'package:meetsync/main.dart';
import 'package:meetsync/screens/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch uses English on a Korean device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    final language = await LanguageController.load();
    await tester.pumpWidget(MeetSyncApp(language: language));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(language.locale, const Locale('en'));
  });

  testWidgets('profile changes language immediately and persists it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final language = await LanguageController.load();
    Future<void> openProfile(String signIn, String profile) async {
      await tester.enterText(find.byType(TextField).first, 'planner');
      await tester.enterText(find.byType(TextField).last, 'preview-password');
      final button = find.widgetWithText(ElevatedButton, signIn);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(profile));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(MeetSyncApp(language: language));
    await tester.pumpAndSettle();
    await openProfile('Sign in', 'Profile');

    Future<void> choose(String menu, String option) async {
      await tester.scrollUntilVisible(find.text(menu), 180);
      await tester.tap(find.text(menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    await choose('Language', '한국어');
    expect(find.text('언어'), findsOneWidget);
    final profileContext = tester.element(find.byType(ProfileScreen));
    expect(Localizations.localeOf(profileContext), const Locale('ko'));

    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    expect(preferences.getString(LanguageController.storageKey), 'ko');
    final reloaded = await LanguageController.load();
    expect(reloaded.locale, const Locale('ko'));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MeetSyncApp(language: reloaded));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsOneWidget);
    await openProfile('로그인', '프로필');
    await choose('언어', 'English');
    expect(find.text('Language'), findsOneWidget);
    await preferences.reload();
    expect((await LanguageController.load()).locale, const Locale('en'));
  });
}
