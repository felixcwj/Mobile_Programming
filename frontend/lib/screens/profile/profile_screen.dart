import '../../l10n/language_settings.dart';
import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import '../../config/support_config.dart';
import '../../models/user_profile.dart';
import '../../services/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'edit_preferences_screen.dart';
import 'profile_widgets.dart';
import 'appointment_history_screen.dart';
import 'support_screen.dart';
import '../../widgets/planit_notice.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    this.onLogout,
    this.supportEmail = defaultSupportEmail,
  });
  final ProfileRepository repository;
  final Future<void> Function()? onLogout;
  final String supportEmail;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _profile;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _profile = widget.repository.load();
    }
  }

  Future<void> _edit(UserProfile profile, {bool preferences = false}) async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: profileTheme(context),
          child: preferences
              ? EditPreferencesScreen(
                  profile: profile,
                  repository: widget.repository,
                )
              : EditProfileScreen(
                  profile: profile,
                  repository: widget.repository,
                ),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _profile = Future.value(updated);
    });
    showPlanitNotice(
      context,
      Text(
        preferences
            ? l10n(context).preferencesSaved
            : l10n(context).profileSaved,
      ),
    );
  }

  Future<void> _logout() async {
    final logout = widget.onLogout;
    if (logout == null || _loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n(context).signOut),
        content: Text(l10n(context).signInAgainToAccessYourPlans),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).signOut2),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await logout();
    } catch (_) {
      if (!mounted) return;
      showPlanitNotice(
        context,
        Text(l10n(context).couldNotSignOutPleaseTryAgain),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFFF0F5F9),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: profileSurface,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFD5E6EF), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1629ACF0),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<UserProfile>(
              future: _profile,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n(context).couldNotLoadYourProfile),
                        TextButton(
                          onPressed: () => setState(() {
                            _profile = widget.repository.load();
                          }),
                          child: Text(l10n(context).tryAgain),
                        ),
                      ],
                    ),
                  );
                }
                final profile = snapshot.requireData;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                  children: [
                    SizedBox(
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            l10n(context).myProfile,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (Navigator.of(context).canPop())
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: l10n(context).close,
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close, size: 22),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(bytes: profile.photoBytes, radius: 52),
                          Positioned(
                            right: -3,
                            bottom: -3,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(
                                side: BorderSide(
                                  color: Color(0xFFD9F0FB),
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                tooltip: l10n(context).editProfilePhoto,
                                onPressed: () => _edit(profile),
                                constraints: const BoxConstraints.tightFor(
                                  width: 38,
                                  height: 38,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.edit,
                                  size: 19,
                                  color: profileBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _menu(
                      label: profile.nickname,
                      icon: Icons.edit_outlined,
                      centered: true,
                      onTap: () => _edit(profile),
                    ),
                    const SizedBox(height: 32),
                    _menu(
                      label: l10n(context).editProfile,
                      icon: Icons.chevron_right,
                      onTap: () => _edit(profile),
                    ),
                    const SizedBox(height: 12),
                    _menu(
                      label: l10n(context).myPreferences,
                      icon: Icons.chevron_right,
                      onTap: () => _edit(profile, preferences: true),
                    ),
                    const SizedBox(height: 12),
                    _menu(
                      label: l10n(context).planHistory,
                      icon: Icons.chevron_right,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AppointmentHistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _menu(
                      label: l10n(context).support,
                      icon: Icons.chevron_right,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SupportScreen(supportEmail: widget.supportEmail),
                        ),
                      ),
                    ),
                    if (LanguageScope.maybeOf(context) != null) ...[
                      const SizedBox(height: 12),
                      _menu(
                        label: l10n(context).language,
                        icon: Icons.language,
                        onTap: () => showLanguageSettings(context),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Center(
                      child: TextButton.icon(
                        onPressed: widget.onLogout != null && !_loggingOut
                            ? _logout
                            : null,
                        icon: const Icon(Icons.logout, size: 16),
                        label: Text(
                          _loggingOut
                              ? l10n(context).signingOut
                              : l10n(context).signOut2,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8A898D),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _menu({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool centered = false,
  }) => Material(
    color: centered ? profileWell : profileButton,
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            if (centered) const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: centered ? 18 : 16,
                  fontWeight: FontWeight.w500,
                  color: profileInk,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 20, color: profileBlue),
          ],
        ),
      ),
    ),
  );
}
