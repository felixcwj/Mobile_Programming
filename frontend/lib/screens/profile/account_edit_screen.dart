import 'package:flutter/material.dart';

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
        const SnackBar(content: Text('변경하지 못했어요. 입력 내용을 확인하고 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.editPassword ? '비밀번호 수정' : '아이디 수정')),
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
                      const Text(
                        '인증 연결 후 사용할 수 있어요',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '지금은 화면 미리보기예요. 실제 아이디와 비밀번호는 변경되지 않아요.',
                        style: TextStyle(color: Colors.grey, height: 1.6),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: '현재 비밀번호',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? '현재 비밀번호를 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _next,
                      obscureText: widget.editPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: widget.editPassword ? 128 : 30,
                      decoration: InputDecoration(
                        labelText: widget.editPassword ? '새 비밀번호' : '새 아이디',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (widget.editPassword) {
                          return (v?.length ?? 0) < 8 ? '8자 이상 입력해 주세요.' : null;
                        }
                        return RegExp(
                              r'^[a-zA-Z0-9_]{4,30}$',
                            ).hasMatch(v?.trim() ?? '')
                            ? null
                            : '영문, 숫자, 밑줄로 4~30자 입력해 주세요.';
                      },
                    ),
                    if (widget.editPassword) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: '새 비밀번호 확인',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v != _next.text ? '비밀번호가 일치하지 않아요.' : null,
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
                      child: Text(_saving ? '변경 중…' : '변경하기'),
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
