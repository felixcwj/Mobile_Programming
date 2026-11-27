import '../models/user_profile.dart';

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
