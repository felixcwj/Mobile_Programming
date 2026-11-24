import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../l10n/planit_l10n.dart';

import '../services/firebase_accounts.dart';
import '../services/profile_photo.dart';
import '../services/profile_repository.dart';
import 'home_screen.dart';
import 'profile/profile_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.accounts});

  final FirebaseAccounts? accounts;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final accounts = widget.accounts ?? FirebaseAccounts();
    final id = _id.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final repository = await Navigator.of(context).push<ProfileRepository>(
      MaterialPageRoute(
        builder: (_) => _SignupProfileScreen(
          register: (nickname, photo) => accounts.register(
            id: id,
            email: email,
            password: password,
            nickname: nickname,
            photo: photo,
          ),
        ),
      ),
    );
    if (!mounted || repository == null) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          loginId: id,
          profileRepository: repository,
          accounts: accounts,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => _SignupForm(
    title: l10n(context).signUp,
    formKey: _formKey,
    children: [
      _SignupField(
        label: l10n(context).username,
        controller: _id,
        hint: l10n(context).lettersNumbersOrUnderscores,
        autofillHints: const [AutofillHints.newUsername],
        validator: (value) =>
            RegExp(r'^[a-zA-Z0-9_]{4,12}$').hasMatch(value.trim())
            ? null
            : l10n(context).useLettersNumbersOrUnderscores2,
      ),
      _SignupField(
        label: l10n(context).email,
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        validator: (value) =>
            value.trim().length <= 254 &&
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
            ? null
            : l10n(context).enterAValidEmailAddress,
      ),
      _SignupField(
        label: l10n(context).password,
        controller: _password,
        hint: l10n(context).minimumPasswordLength,
        autofillHints: const [AutofillHints.newPassword],
        obscureText: !_passwordVisible,
        visibilityToggle: () =>
            setState(() => _passwordVisible = !_passwordVisible),
        validator: (value) => value.length >= 8
            ? null
            : l10n(context).yourPasswordMustBeAtLeastCharacters,
      ),
      _SignupField(
        label: l10n(context).confirmPassword,
        obscureText: !_confirmVisible,
        visibilityToggle: () =>
            setState(() => _confirmVisible = !_confirmVisible),
        validator: (value) {
          if (value.isEmpty) return l10n(context).enterYourPasswordAgain;
          if (value != _password.text) {
            return l10n(context).passwordsDoNotMatch2;
          }
          return null;
        },
      ),
      FilledButton(onPressed: _next, child: Text(l10n(context).next)),
    ],
  );
}

class _SignupProfileScreen extends StatefulWidget {
  const _SignupProfileScreen({required this.register});

  final Future<ProfileRepository> Function(String, Uint8List?) register;

  @override
  State<_SignupProfileScreen> createState() => _SignupProfileScreenState();
}

class _SignupProfileScreenState extends State<_SignupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  Uint8List? _photo;
  bool _picking = false;
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final photo = await pickProfilePhoto(
        maxBytes: FirebaseProfileRepository.photoLimit,
      );
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (mounted) _showMessage(l10n(context).couldNotOpenThePhotoChooseAn3);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _finish() async {
    if (_saving || _picking || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final repository = await widget.register(_nickname.text.trim(), _photo);
      if (!mounted) return;
      Navigator.of(context).pop(repository);
    } on AccountException catch (error) {
      if (mounted) _showMessage(displayError(context, error));
    } catch (_) {
      if (mounted) _showMessage(l10n(context).couldNotCompleteSignUpPleaseTry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: _SignupForm(
      title: l10n(context).setUpYourProfile,
      formKey: _formKey,
      children: [
        Center(child: ProfileAvatar(bytes: _photo, radius: 48)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: _saving || _picking ? null : _pickPhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _photo == null
                  ? l10n(context).chooseProfilePhoto
                  : l10n(context).changeProfilePhoto,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SignupField(
          label: l10n(context).nickname,
          controller: _nickname,
          enabled: !_saving,
          hint: l10n(context).nicknameLength,
          validator: (value) =>
              value.trim().length >= 2 && value.trim().length <= 12
              ? null
              : l10n(context).enterANicknameWithCharacters,
        ),
        FilledButton(
          onPressed: _saving || _picking ? null : _finish,
          child: Text(
            _saving ? l10n(context).saving : l10n(context).createAccount,
          ),
        ),
      ],
    ),
  );
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.title,
    required this.formKey,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), centerTitle: true),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SignupField extends StatelessWidget {
  const _SignupField({
    required this.label,
    required this.validator,
    this.controller,
    this.hint,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.visibilityToggle,
  });

  final String label;
  final String? Function(String) validator;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final VoidCallback? visibilityToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: visibilityToggle == null,
      validator: (value) => validator(value ?? ''),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: visibilityToggle == null
            ? null
            : IconButton(
                onPressed: visibilityToggle,
                tooltip: obscureText
                    ? l10n(context).showPassword
                    : l10n(context).hidePassword,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                ),
              ),
      ),
    ),
  );
}
