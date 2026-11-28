import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/planit_l10n.dart';
import '../../models/user_profile.dart';
import '../../services/profile_repository.dart';
import '../../services/firebase_accounts.dart';
import '../../services/planit_api.dart';
import '../../services/profile_photo.dart';
import 'account_edit_screen.dart';
import 'profile_widgets.dart';
import '../../widgets/planit_notice.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.repository,
  });
  final UserProfile profile;
  final ProfileRepository repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  Uint8List? _photo;
  bool _saving = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.profile.nickname);
    _photo = widget.profile.photoBytes;
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final firebaseProfile = widget.repository is FirebaseProfileRepository;
      final bytes = await pickProfilePhoto(
        maxBytes: firebaseProfile
            ? FirebaseProfileRepository.photoLimit
            : 5 * 1024 * 1024,
      );
      if (mounted && bytes != null) setState(() => _photo = bytes);
    } catch (_) {
      if (!mounted) return;
      showPlanitNotice(
        context,
        Text(
          widget.repository is FirebaseProfileRepository
              ? l10n(context).couldNotOpenThePhotoChooseAn
              : l10n(context).couldNotOpenThePhotoChooseAn2,
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final latest = await widget.repository.load();
      final updated = latest.copyWith(
        nickname: _nickname.text.trim(),
        photoBytes: _photo,
        removePhoto: _photo == null,
      );
      await widget.repository.save(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } on PlanitApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPlanitNotice(context, Text(displayError(context, error)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPlanitNotice(
        context,
        Text(l10n(context).couldNotSavePleaseTryAgainShortly),
      );
    }
  }

  Future<void> _account(bool password) async {
    final backend = widget.repository is FirebaseProfileRepository
        ? widget.repository as FirebaseProfileRepository
        : null;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountEditScreen(
          editPassword: password,
          onSubmit: backend == null
              ? null
              : (current, value) async {
                  if (password) {
                    await backend.changePassword(current, value);
                  } else {
                    await backend.changeId(current, value);
                  }
                },
        ),
      ),
    );
    if (changed == true && mounted && backend != null) {
      try {
        final refreshed = await backend.load();
        if (mounted) Navigator.of(context).pop(refreshed);
      } catch (_) {
        if (mounted)
          showPlanitNotice(
            context,
            Text(l10n(context).changesWereSavedSignInAgainTo),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_picking,
    child: Scaffold(
      appBar: AppBar(title: Text(l10n(context).editProfile)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AbsorbPointer(
              absorbing: _saving || _picking,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    ProfileSection(
                      title: l10n(context).profilePhoto,
                      child: Column(
                        children: [
                          ProfileAvatar(bytes: _photo, radius: 48),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              TextButton.icon(
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(
                                  _picking
                                      ? l10n(context).openingPhoto
                                      : l10n(context).editProfilePhoto,
                                ),
                              ),
                              if (_photo != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _photo = null),
                                  child: Text(l10n(context).removePhoto),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ProfileSection(
                      title: l10n(context).myProfile,
                      child: TextFormField(
                        key: const ValueKey('nickname'),
                        controller: _nickname,
                        maxLength: 12,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                        decoration: InputDecoration(
                          labelText: l10n(context).nickname,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null ||
                                v.trim().length < 2 ||
                                v.trim().length > 12
                            ? l10n(context).enterANicknameWithCharacters
                            : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ProfileSection(
                      title: l10n(context).accountInformation,
                      description: l10n(
                        context,
                      ).verifyYourAccountToChangeYourUsername,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n(context).changeUsername),
                            subtitle: Text(
                              widget.profile.loginId.isEmpty
                                  ? l10n(context).noUsernameRegisteredYet
                                  : widget.profile.loginId,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _account(false),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n(context).changePassword),
                            subtitle: Text(
                              l10n(
                                context,
                              ).verifyYourCurrentPasswordToMakeChanges,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _account(true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ProfileSaveButton(saving: _saving, onPressed: _save),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
