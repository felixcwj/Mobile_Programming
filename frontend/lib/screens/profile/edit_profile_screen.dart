import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_profile.dart';
import '../../services/profile_repository.dart';
import 'account_edit_screen.dart';
import 'profile_widgets.dart';

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
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw StateError('Image exceeds 5 MB');
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 열지 못했어요. 5MB 이하의 이미지로 다시 선택해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_nickname.text.trim().isEmpty || _nickname.text.trim().length > 20) {
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임은 1~20자로 입력해 주세요.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  void _account(bool password) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AccountEditScreen(editPassword: password),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_picking,
    child: Scaffold(
      appBar: AppBar(title: const Text('나의 정보 수정')),
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
                      title: '프로필 사진',
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
                                  _picking ? '사진 여는 중…' : '프로필 사진 수정',
                                ),
                              ),
                              if (_photo != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _photo = null),
                                  child: const Text('사진 삭제'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ProfileSection(
                      title: '나의 정보',
                      child: Column(
                        children: [
                          TextFormField(
                            key: const ValueKey('nickname'),
                            controller: _nickname,
                            maxLength: 20,
                            decoration: const InputDecoration(
                              labelText: '닉네임',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? '닉네임을 입력해 주세요.'
                                : null,
                          ),

                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ProfileSection(
                      title: '계정 정보',
                      description: '아이디와 비밀번호 변경에는 계정 인증이 필요해요.',
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('아이디 수정'),
                            subtitle: Text(
                              widget.profile.loginId.isEmpty
                                  ? '아직 등록된 아이디가 없어요'
                                  : widget.profile.loginId,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _account(false),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('비밀번호 수정'),
                            subtitle: const Text('현재 비밀번호 확인 후 변경'),
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
