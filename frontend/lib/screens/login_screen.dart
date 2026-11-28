import 'package:flutter/material.dart';
import '../l10n/planit_l10n.dart';

import '../services/firebase_accounts.dart';
import 'profile/planit_server_settings.dart';
import '../widgets/planit_mascot.dart';
import 'home_screen.dart';
import 'profile/profile_widgets.dart';
import 'signup_screen.dart';
import '../widgets/planit_notice.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.accounts});

  final FirebaseAccounts? accounts;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool _loggingIn = false;

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loggingIn) return;
    final id = idController.text.trim();
    final password = passwordController.text;
    if (id.isEmpty || password.isEmpty) {
      showPlanitNotice(
        context,
        Text(l10n(context).enterYourUsernameAndPassword),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final accounts = widget.accounts;
    if (accounts == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(loginId: id)),
      );
      return;
    }

    setState(() => _loggingIn = true);
    try {
      final repository = await accounts.signIn(id, password);
      final profile = await repository.load();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            loginId: profile.loginId,
            profileRepository: repository,
            accounts: accounts,
          ),
        ),
      );
    } catch (error) {
      await accounts.signOut();
      if (!mounted) return;
      showPlanitNotice(
        context,
        Text(
          error is AccountException
              ? displayError(context, error)
              : l10n(context).couldNotSignInCheckYourUsername,
        ),
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF90A5B5), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF6992B0), size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDDEBF4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDDEBF4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: profileBlue, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context).copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: profileBlue,
        selectionColor: profileButton,
        selectionHandleColor: profileBlue,
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF0F5F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlanitServerSettings(context),
        icon: const Icon(Icons.settings_ethernet),
        label: Text(l10n(context).teamServer),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [profileSurface, Color(0xFFF0F8FE)],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFB9E4F8), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1829ACF0),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x08073365),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 600;
                return SingleChildScrollView(
                  key: const ValueKey('login-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: compact ? 20 : 36,
                      ),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: compact ? 60 : 104,
                                height: compact ? 60 : 104,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, Color(0xFFDFF3FF)],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD3EBF9),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0E0077CC),
                                      blurRadius: 20,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: PlanitMascot(size: compact ? 50 : 86),
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 16),
                            Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Plan',
                                    style: TextStyle(color: profileInk),
                                  ),
                                  TextSpan(
                                    text: 'it',
                                    style: TextStyle(color: profileBlue),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: compact ? 36 : 46,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: compact ? 10 : 14),
                            Text(
                              l10n(context).makePlanningTogetherEasyAndFun,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: profileInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n(context).planABetterDayTogether,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6C879A),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: compact ? 20 : 32),
                            Text(
                              l10n(context).username,
                              style: TextStyle(
                                color: profileInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('login-id'),
                              controller: idController,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              autocorrect: false,
                              style: const TextStyle(
                                color: profileInk,
                                fontSize: 14,
                              ),
                              decoration: _decoration(
                                l10n(context).enterYourUsername,
                                Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n(context).password,
                              style: TextStyle(
                                color: profileInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('login-password'),
                              controller: passwordController,
                              obscureText: !isPasswordVisible,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              scrollPadding: const EdgeInsets.only(bottom: 96),
                              style: const TextStyle(
                                color: profileInk,
                                fontSize: 14,
                              ),
                              onSubmitted: (_) => _login(),
                              decoration: _decoration(
                                l10n(context).enterYourPassword,
                                Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: isPasswordVisible
                                      ? l10n(context).hidePassword
                                      : l10n(context).showPassword,
                                  icon: Icon(
                                    isPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF6992B0),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () =>
                                        isPasswordVisible = !isPasswordVisible,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 20 : 24),
                            ElevatedButton(
                              key: const ValueKey('login-submit'),
                              onPressed: _loggingIn ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: profileBlue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: profileButton,
                                minimumSize: const Size.fromHeight(52),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n(context).signIn,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 8 : 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 2,
                              children: [
                                Text(
                                  l10n(context).newToPlanit,
                                  style: TextStyle(
                                    color: Color(0xFF6C879A),
                                    fontSize: 12,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loggingIn
                                      ? null
                                      : () {
                                          FocusScope.of(context).unfocus();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SignupScreen(
                                                accounts: widget.accounts,
                                              ),
                                            ),
                                          );
                                        },
                                  style: TextButton.styleFrom(
                                    foregroundColor: profileBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: Text(
                                    l10n(context).signUp,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
