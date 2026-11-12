
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmVisible = false;

  static const _blue = Color(0xFF4F7CFF);

  @override
  void dispose() {
    _idController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkDuplicateId() {
    final id = _idController.text.trim();

    if (!RegExp(r'^[a-zA-Z0-9]{4,20}$').hasMatch(id)) {
      _showMessage('아이디는 영문과 숫자 4~20자로 입력해 주세요.');
      return;
    }

    // TODO: 백엔드의 아이디 중복 확인 API 연결
    _showMessage('아이디 중복 확인은 서버 연결 후 사용할 수 있어요.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // TODO: 서버 중복 확인 완료 여부 검증
    // TODO: Firebase 또는 백엔드 회원가입 API 연결
    _showMessage('입력 검증 완료! 실제 회원가입은 서버 연결 후 가능해요.');
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: _blue,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: const Color(0xFFF8FAFC),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'PlanIt 시작하기',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF142F5F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '함께 만드는 더 좋은 하루, 플랜잇',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 아이디 및 중복 확인
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(
                            label: '아이디',
                            hint: '영문, 숫자 4~20자',
                            controller: _idController,
                            validator: (value) {
                              if (!RegExp(r'^[a-zA-Z0-9]{4,20}$')
                                  .hasMatch(value?.trim() ?? '')) {
                                return '영문과 숫자 4~20자로 입력해 주세요.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: OutlinedButton(
                            onPressed: _checkDuplicateId,
                            child: const Text('중복 확인'),
                          ),
                        ),
                      ],
                    ),

                    _field(
                      label: '닉네임',
                      hint: '2~12자',
                      controller: _nicknameController,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 2 || text.length > 12) {
                          return '닉네임은 2~12자로 입력해 주세요.';
                        }
                        return null;
                      },
                    ),

                    _field(
                      label: '비밀번호',
                      hint: '8자 이상',
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) {
                          return '비밀번호는 8자 이상이어야 합니다.';
                        }
                        return null;
                      },
                    ),

                    _field(
                      label: '비밀번호 확인',
                      hint: '비밀번호를 다시 입력해 주세요',
                      controller: _confirmController,
                      obscureText: !_confirmVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _confirmVisible = !_confirmVisible;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        if ((value ?? '').isEmpty) {
                          return '비밀번호를 확인해 주세요.';
                        }
                        return null;
                      },
                    ),

                    _field(
                      label: '이메일',
                      hint: 'example@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return '올바른 이메일을 입력해 주세요.';
                        }
                        return null;
                      },
                    ),

                    _field(
                      label: '이름',
                      hint: '실명을 입력해 주세요',
                      controller: _nameController,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return '이름을 입력해 주세요.';
                        }
                        return null;
                      },
                    ),

                    _field(
                      label: '전화번호',
                      hint: '01012345678',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (value) {
                        if (!RegExp(r'^\d{10,11}$')
                            .hasMatch(value ?? '')) {
                          return '전화번호 10~11자리를 입력해 주세요.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('이미 계정이 있으신가요? 로그인'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
