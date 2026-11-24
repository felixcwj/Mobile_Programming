import 'package:flutter/material.dart';
import '../l10n/planit_l10n.dart';
import 'package:flutter/services.dart';
import 'profile/profile_widgets.dart';
import '../widgets/planit_mascot.dart';

class JoinRoomDialog extends StatefulWidget {
  const JoinRoomDialog({super.key});

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.pop(context, _controller.text.trim().toUpperCase());

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context),
    child: AlertDialog(
      backgroundColor: profileSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(l10n(context).joinWithACode),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 7,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9#@!]')),
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n(context).inviteCode,
          hintText: l10n(context).enterTheCharacterCode,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n(context).cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n(context).join)),
      ],
    ),
  );
}

class HomeWordmark extends StatelessWidget {
  const HomeWordmark({super.key});

  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
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
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 36,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            height: 1.15,
          ),
        ),
        SizedBox(width: 8),
        PlanitMascot(size: 34),
      ],
    ),
  );
}

class HomeAddMenu extends StatelessWidget {
  const HomeAddMenu({super.key, required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF1F9FE)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFCAE8F7), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2029ACF0),
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCE3EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n(context).startANewPlan,
                  style: TextStyle(
                    color: profileInk,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n(context).planADayWithFriends,
                  style: TextStyle(
                    color: Color(0xFF6C879A),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _AddMenuCard(
                  title: l10n(context).newRoom,
                  subtitle: l10n(context).createANewRoom,
                  icon: Icons.add_home_outlined,
                  highlighted: true,
                  onTap: onCreate,
                ),
                const SizedBox(height: 12),
                _AddMenuCard(
                  title: l10n(context).joinWithACode,
                  subtitle: l10n(context).joinWithAnInviteCode,
                  icon: Icons.key_rounded,
                  onTap: onJoin,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AddMenuCard extends StatelessWidget {
  const _AddMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: highlighted ? const Color(0xFFE7F5FE) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: highlighted ? const Color(0xFFBAE1F8) : const Color(0xFFE1EDF5),
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: highlighted ? Colors.white : profileButton,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: profileBlue, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: profileInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF668399),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: profileBlue,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
