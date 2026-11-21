import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'planit_api.dart';
import 'profile_repository.dart';

/// Single source of truth: FastAPI Auth + users/{uid}. Never creates a second
/// synthetic Firebase account or writes to the legacy profiles collection.
class FirebaseAccounts {
  FirebaseAccounts({PlanitApi? api}) : _api = api ?? PlanitApi();
  final PlanitApi _api;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<ProfileRepository> register({
    required String id,
    required String email,
    required String password,
    required String nickname,
    Uint8List? photo,
  }) async {
    if (photo != null && photo.length > FirebaseProfileRepository.photoLimit) {
      throw const AccountException('프로필 사진은 250KB 이하로 선택해 주세요.');
    }
    try {
      await _api.request('POST', '/auth/signup', authenticated: false, body: {
        'id': id,
        'email': email,
        'password': password,
        'password_confirm': password,
        'nickname': nickname,
        if (photo != null) 'profile_photo': base64Encode(photo),
      });
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return FirebaseProfileRepository(_api);
    } on PlanitApiException catch (e) {
      throw AccountException(e.message);
    } on FirebaseAuthException {
      throw const AccountException('계정은 생성되었지만 자동 로그인에 실패했습니다. 로그인 화면에서 다시 시도해 주세요.');
    }
  }

  Future<ProfileRepository> signIn(String id, String password) async {
    try {
      final info = await _api.request('POST', '/auth/login',
          authenticated: false, body: {'id': id, 'password': password});
      final email = info['email'];
      if (email is! String || email.isEmpty) {
        throw const AccountException('서버에서 계정 이메일을 받지 못했습니다.');
      }
      final session = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (session.user?.uid != info['uid']) {
        await _auth.signOut();
        throw const AccountException('서버와 Firebase 계정 정보가 일치하지 않습니다.');
      }
      return FirebaseProfileRepository(_api);
    } on PlanitApiException catch (e) {
      throw AccountException(e.message);
    } on FirebaseAuthException {
      throw const AccountException('로그인하지 못했습니다. 아이디와 비밀번호를 확인해 주세요.');
    }
  }

  Future<void> signOut() => _auth.signOut();
}

class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Backend profile adapter, class name kept for existing Flutter screens.
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository(this._api);
  static const photoLimit = 250 * 1024;
  final PlanitApi _api;

  @override
  Future<UserProfile> load() async {
    final identity = await _api.request('GET', '/users/me');
    final prefs = await _api.request('GET', '/mypage/preferences');
    final fields = prefs['preferences'] is Map
        ? Map<String, dynamic>.from(prefs['preferences'] as Map)
        : prefs;
    final gender = switch (fields['gender']) {
      'female' => '여성',
      'male' => '남성',
      'other' => '기타',
      'prefer_not_to_say' => '응답하지 않음',
      _ => null,
    };
    final activity = ActivityPreference.values
        .where((x) => x.name == fields['activity_preference']).firstOrNull;
    final photoString = identity['profile_photo'];
    Uint8List? photo;
    if (photoString is String && photoString.isNotEmpty) {
      try { photo = base64Decode(photoString); } catch (_) { /* Legacy data */ }
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const AccountException('로그인이 필요합니다.');
    return UserProfile(
      userId: uid,
      loginId: (identity['id'] ?? '').toString(),
      nickname: (identity['nickname'] ?? '').toString(),
      email: (identity['email'] ?? '').toString(),
      photoBytes: photo,
      preferences: BasicPreferences(
        gender: gender,
        birthDate: DateTime.tryParse((fields['birthday'] ?? '').toString()),
        mbti: fields['mbti'] == 'unknown' ? '잘 모르겠어요' : fields['mbti'] as String?,
        activityPreference: activity,
        drinkingEnjoyment: fields['alcohol_preference'] as int?,
        livingArea: (fields['neighborhood'] ?? '').toString(),
        hasCar: fields['has_car'] as bool?,
      ),
    );
  }

  @override
  Future<void> save(UserProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || profile.userId != uid) {
      throw const AccountException('다른 사용자의 프로필을 저장할 수 없습니다.');
    }
    final original = await load();
    if (original.nickname != profile.nickname) {
      await _api.request('PUT', '/mypage/profile',
          body: {'nickname': profile.nickname});
    }
    if (!_sameBytes(original.photoBytes, profile.photoBytes)) {
      await _api.request('PUT', '/users/me/photo', body: {
        'profile_photo': profile.photoBytes == null
            ? null : base64Encode(profile.photoBytes!),
      });
    }
    final p = profile.preferences;
    final q = original.preferences;
    if (p.gender != q.gender || p.birthDate != q.birthDate ||
        p.mbti != q.mbti || p.activityPreference != q.activityPreference ||
        p.drinkingEnjoyment != q.drinkingEnjoyment ||
        p.livingArea != q.livingArea || p.hasCar != q.hasCar) {
      await _api.request('PUT', '/mypage/preferences', body: {
        'gender': switch (p.gender) {
          '여성' => 'female', '남성' => 'male', '기타' => 'other',
          '응답하지 않음' => 'prefer_not_to_say', _ => null,
        },
        'birthday': p.birthDate == null ? null :
          '${p.birthDate!.year.toString().padLeft(4, '0')}-'
          '${p.birthDate!.month.toString().padLeft(2, '0')}-'
          '${p.birthDate!.day.toString().padLeft(2, '0')}',
        'mbti': p.mbti == '잘 모르겠어요' ? 'unknown' : p.mbti,
        'activity_preference': p.activityPreference?.name,
        'alcohol_preference': p.drinkingEnjoyment,
        'neighborhood': p.livingArea,
        'has_car': p.hasCar,
      });
    }
  }

  Future<void> changeId(String password, String newId) async {
    try {
      await _api.request('PUT', '/mypage/id',
        body: {'password': password, 'new_id': newId.trim()});
    } on PlanitApiException catch (e) {
      throw AccountException(e.message);
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _api.request('POST', '/mypage/password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirm': newPassword,
      });
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, password: newPassword);
      }
    } on PlanitApiException catch (e) {
      throw AccountException(e.message);
    } on FirebaseAuthException {
      throw const AccountException('비밀번호가 변경됐습니다. 보안을 위해 다시 로그인해 주세요.');
    }
  }

  bool _sameBytes(Uint8List? a, Uint8List? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
