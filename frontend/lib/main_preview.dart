import 'package:flutter/material.dart';

import 'l10n/language_settings.dart';
import 'main.dart' show MeetSyncApp;
import 'screens/home_screen.dart';
import 'services/rooms_controller.dart';

/// Local UI preview with sample plans; no Firebase initialization or account.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = await LanguageController.load();
  runApp(
    MeetSyncApp(
      language: language,
      home: Banner(
        message: '미리보기',
        location: BannerLocation.topEnd,
        child: HomeScreen(
          loginId: 'preview',
          initialRooms: RoomsController.demo().rooms,
        ),
      ),
    ),
  );
}
