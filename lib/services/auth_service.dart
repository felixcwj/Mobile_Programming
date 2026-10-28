import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<bool> isUserIdTaken(String userId) async {
    final doc = await _db.collection('usernames').doc(userId).get();
    return doc.exists;
  }

  Future<String?> signUp({
    required String userId,
    required String password,
    required String nickname,
    required String email,
    required String name,
    required String phone,
  }) async {
    try {
      if (await isUserIdTaken(userId)) return '이미 사용 중인 아이디예요';
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'userId': userId,
        'nickname': nickname,
        'email': email,
        'name': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('usernames').doc(userId).set({
        'email': email,
        'uid': uid,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e.code);
    }
  }

  Future<String?> login({
    required String userId,
    required String password,
  }) async {
    try {
      final doc = await _db.collection('usernames').doc(userId).get();
      if (!doc.exists) return '아이디 또는 비밀번호가 틀렸어요';
      final email = doc.data()!['email'] as String;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e.code);
    }
  }

  Future<void> logout() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  String _message(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 해요';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return '아이디 또는 비밀번호가 틀렸어요';
      case 'network-request-failed':
        return '인터넷 연결을 확인해주세요';
      default:
        return '오류가 발생했어요 ($code)';
    }
  }
}
