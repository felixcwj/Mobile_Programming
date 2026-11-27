import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';

/// Frontend form only; a verified authentication flow must supply [onSubmit].
/// Password values are never sent to the profile repository.
class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({
    super.key,
    required this.editPassword,
    this.onSubmit,
  });
  final bool editPassword;
  final Future<void> Function(String currentPassword, String newValue)?
  onSubmit;

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final submit = widget.onSubmit;
    if (submit == null || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await submit(
        _current.text,
        widget.editPassword ? _next.text : _next.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n(context).couldNotSaveChangesCheckYourEntries),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editPassword
              ? l10n(context).changePassword
              : l10n(context).changeUsername,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (widget.onSubmit == null) ...[
                      Text(
                        l10n(context).availableAfterConnectingAuthentication,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n(context).thisIsAPreviewYourUsernameAnd,
                        style: TextStyle(color: Colors.grey, height: 1.6),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n(context).currentPassword,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? l10n(context).enterYourCurrentPassword
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _next,
                      obscureText: widget.editPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: widget.editPassword ? 20 : 12,
                      decoration: InputDecoration(
                        labelText: widget.editPassword
                            ? l10n(context).newPassword
                            : l10n(context).newUsername,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (widget.editPassword) {
                          return (v?.length ?? 0) < 8
                              ? l10n(context).enterAtLeastCharacters
                              : null;
                        }
                        return RegExp(
                              r'^[a-zA-Z0-9_]{4,12}$',
                            ).hasMatch(v?.trim() ?? '')
                            ? null
                            : l10n(context).useLettersNumbersOrUnderscores;
                      },
                    ),
                    if (widget.editPassword) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: l10n(context).confirmNewPassword,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v != _next.text
                            ? l10n(context).passwordsDoNotMatch
                            : null,
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: widget.onSubmit == null || _saving
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(
                        _saving
                            ? l10n(context).savingChanges
                            : l10n(context).saveChanges,
                      ),
                    ),
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
