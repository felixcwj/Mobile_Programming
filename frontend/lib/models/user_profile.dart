import 'package:flutter/foundation.dart';

enum ActivityPreference {
  outdoor('외부 활동'),
  indoor('실내 활동'),
  both('둘 다 좋아요');

  const ActivityPreference(this.label);
  final String label;
}

@immutable
class BasicPreferences {
  const BasicPreferences({
    this.gender,
    this.birthDate,
    this.mbti,
    this.activityPreference,
    this.drinkingEnjoyment,
    this.livingArea = '',
    this.hasCar,
  }) : assert(
         drinkingEnjoyment == null ||
             (drinkingEnjoyment >= 1 && drinkingEnjoyment <= 5),
       );

  final String? gender;
  final DateTime? birthDate;
  final String? mbti;
  final ActivityPreference? activityPreference;
  final int? drinkingEnjoyment;
  final String livingArea;
  final bool? hasCar;

  int? ageAt(DateTime today) {
    final birth = birthDate;
    if (birth == null) return null;
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age;
  }

  int get answeredCount => [
    gender,
    birthDate,
    mbti,
    activityPreference,
    drinkingEnjoyment,
    livingArea.trim().isEmpty ? null : livingArea,
    hasCar,
  ].where((answer) => answer != null).length;
}

@immutable
class UserProfile {
  UserProfile({
    required this.userId,
    required this.nickname,
    required this.email,
    this.loginId = '',
    this.homeAddress = '',
    Uint8List? photoBytes,
    this.preferences = const BasicPreferences(),
  }) : photoBytes = photoBytes == null
           ? null
           : Uint8List.fromList(photoBytes).asUnmodifiableView();

  final String userId;
  final String nickname;
  final String email;
  final String loginId;
  final String homeAddress;
  final Uint8List? photoBytes;
  final BasicPreferences preferences;

  // Passwords belong to the authentication service, never this profile model.
  UserProfile copyWith({
    String? nickname,
    String? loginId,
    String? homeAddress,
    Uint8List? photoBytes,
    bool removePhoto = false,
    BasicPreferences? preferences,
  }) => UserProfile(
    userId: userId,
    nickname: nickname ?? this.nickname,
    email: email,
    loginId: loginId ?? this.loginId,
    homeAddress: homeAddress ?? this.homeAddress,
    photoBytes: removePhoto ? null : photoBytes ?? this.photoBytes,
    preferences: preferences ?? this.preferences,
  );
}
