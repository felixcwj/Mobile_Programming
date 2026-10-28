import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthTestScreen(),
    ),
  );
}

class AuthTestScreen extends StatefulWidget {
  const AuthTestScreen({super.key});

  @override
  State<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  final _auth = AuthService();
  String _result = '버튼을 눌러보세요';

  Future<void> _run(Future<String?> Function() action, String ok) async {
    final error = await action();
    setState(() => _result = error ?? ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => _run(
                () => _auth.signUp(
                  userId: 'test01',
                  password: 'test1234',
                  nickname: '테스트',
                  email: 'test01@example.com',
                  name: '홍길동',
                  phone: '010-0000-0000',
                ),
                '회원가입 성공',
              ),
              child: const Text('회원가입 test01'),
            ),
            ElevatedButton(
              onPressed: () => _run(
                () => _auth.login(userId: 'test01', password: 'test1234'),
                '로그인 성공',
              ),
              child: const Text('로그인 test01'),
            ),
            ElevatedButton(
              onPressed: () => _run(
                () => _auth.login(userId: 'test01', password: 'wrong'),
                '이상함: 틀린 비번인데 성공',
              ),
              child: const Text('틀린 비밀번호로 로그인'),
            ),
            const SizedBox(height: 24),
            Text(_result, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
