import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/language_settings.dart';
import 'screens/login_screen.dart';
import 'services/firebase_accounts.dart';
import 'services/planit_server_config.dart';

Future<void> main() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  final language = await LanguageController.load();
  await PlanitServerConfig.load();

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 앱 실행
  runApp(MeetSyncApp(accounts: FirebaseAccounts(), language: language));
}

class MeetSyncApp extends StatelessWidget {
  const MeetSyncApp({
    super.key,
    this.accounts,
    this.language,
    this.initialLocale = const Locale('en'),
  });

  final FirebaseAccounts? accounts;
  final LanguageController? language;
  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    final controller = language;
    if (controller == null) return _app(initialLocale);
    return LanguageScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _app(controller.locale),
      ),
    );
  }

  Widget _app(Locale locale) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F7CFF)),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    ),
    home: LoginScreen(accounts: accounts),
  );
}
