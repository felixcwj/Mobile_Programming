import '../models/user_profile.dart';
import 'planit_api.dart';

/// Implement with the authenticated backend before production integration.
abstract class ProfileRepository {
  Future<UserProfile> load();
  Future<void> save(UserProfile profile);
}

/// Preview storage only. Reuse the same instance across screens; data is reset
/// when the application restarts. This class does not authenticate users.
class MemoryProfileRepository implements ProfileRepository {
  MemoryProfileRepository({required UserProfile initialProfile})
    : _profile = initialProfile;

  UserProfile _profile;

  @override
  Future<UserProfile> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    if (profile.userId != _profile.userId) {
      throw ArgumentError('Cannot save a different user in this repository.');
    }
    _profile = profile;
  }
}

 
/// Firestore-backed profile/preferences adapter for the real PlanIt API.
class ServerProfileRepository implements ProfileRepository {
  ServerProfileRepository({required this.loginId});

  final String loginId;
  String? _name;
  String? _phone;
  UserProfile? _cached;

  String? _genderCode(String? gender) => switch (gender) {
    '여성' => 'female',
    '남성' => 'male',
    '기타' => 'other',
    '응답하지 않음' => 'prefer_not_to_say',
    _ => null,
  };

  String? _genderLabel(String? code) => switch (code) {
    'female' => '여성',
    'male' => '남성',
    'other' => '기타',
    'prefer_not_to_say' => '응답하지 않음',
    _ => null,
  };

  @override
  Future<UserProfile> load() async {
    final api = PlanitApi.instance;
    final profile = await api.request('GET', '/mypage/profile');
    final response = await api.request('GET', '/mypage/preferences');
    final raw = response['preferences'] as Map<String, dynamic>? ?? {};
    _name = profile['name']?.toString();
    _phone = profile['phone']?.toString();
    ActivityPreference? activity;
    for (final value in ActivityPreference.values) {
      if (value.name == raw['activity_preference']) activity = value;
    }
    final birth = DateTime.tryParse(raw['birthday']?.toString() ?? '');
    final result = UserProfile(
      userId: profile['id']?.toString() ?? loginId,
      loginId: profile['id']?.toString() ?? loginId,
      nickname: profile['nickname']?.toString() ?? '사용자',
      email: profile['email']?.toString() ?? '',
      preferences: BasicPreferences(
        gender: _genderLabel(raw['gender']?.toString()),
        birthDate: birth,
        mbti: raw['mbti']?.toString(),
        activityPreference: activity,
        drinkingEnjoyment: (raw['alcohol_preference'] as num?)?.toInt(),
        livingArea: raw['neighborhood']?.toString() ?? '',
        hasCar: raw['has_car'] as bool?,
      ),
    );
    _cached = result;
    return result;
  }

  @override
  Future<void> save(UserProfile profile) async {
    final previous = _cached ?? await load();
    if (profile.userId != previous.userId) {
      throw const PlanitApiException('다른 계정의 정보를 수정할 수 없습니다.');
    }
    if (profile.homeAddress.isNotEmpty || profile.photoBytes != null) {
      throw const PlanitApiException(
          '상세 주소·프로필 사진은 서버 저장 기능이 아직 없어 저장할 수 없습니다.');
    }
    final api = PlanitApi.instance;
    if (profile.nickname != previous.nickname) {
      final name = _name;
      final phone = _phone;
      if (name == null || phone == null) {
        throw const PlanitApiException('기본 프로필을 불러오지 못했습니다.');
      }
      await api.request('PUT', '/mypage/profile', body: {
        'nickname': profile.nickname, 'name': name, 'phone': phone,
      });
    }
    final p = profile.preferences;
    final previousP = previous.preferences;
    if (p.gender != previousP.gender ||
        p.birthDate != previousP.birthDate ||
        p.mbti != previousP.mbti ||
        p.activityPreference != previousP.activityPreference ||
        p.drinkingEnjoyment != previousP.drinkingEnjoyment ||
        p.livingArea != previousP.livingArea ||
        p.hasCar != previousP.hasCar) {
      await api.request('PUT', '/mypage/preferences', body: {
        'gender': _genderCode(p.gender),
        'birthday': p.birthDate == null
            ? null
            : '${p.birthDate!.year.toString().padLeft(4, '0')}-${p.birthDate!.month.toString().padLeft(2, '0')}-${p.birthDate!.day.toString().padLeft(2, '0')}',
        'mbti': p.mbti,
        'activity_preference': p.activityPreference?.name,
        'alcohol_preference': p.drinkingEnjoyment,
        'neighborhood': p.livingArea,
        'has_car': p.hasCar,
      });
    }
    _cached = profile;
  }
}
