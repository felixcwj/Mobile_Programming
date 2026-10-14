import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/main_shell.dart';

void main() => runApp(const MeetMateApp());

class MeetMateApp extends StatelessWidget {
  const MeetMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '모여봄 | AI 약속 플래너',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: const MainShell(),
      );
}
