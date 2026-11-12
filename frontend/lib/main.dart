
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 앱 실행
  runApp(const MeetSyncApp());
}

class MeetSyncApp extends StatelessWidget {
  const MeetSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '플랜잇',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F7CFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const LoginScreen(),
    );
  }
}
