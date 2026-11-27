import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import '../../models/plan_room.dart';
import '../profile/profile_widgets.dart';

const roomBlue = profileBlue;
const roomTint = profileButton;
const roomInk = profileInk;
const roomMuted = Color(0xFF6C879A);
const roomBackground = profileSurface;

String roomDate(DateTime? date, {required BuildContext context}) {
  if (date == null) return l10n(context).dateUndecided;
  return '${planDateLabel(context, date, includeYear: false)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class RoomPanel extends StatelessWidget {
  const RoomPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDDEAF2)),
    ),
    child: child,
  );
}

class RoomStatusBadge extends StatelessWidget {
  const RoomStatusBadge({
    super.key,
    required this.status,
    this.allSubmitted = false,
  });
  final RoomStatus status;
  final bool allSubmitted;

  @override
  Widget build(BuildContext context) {
    const color = roomBlue;
    final label = switch (status) {
      RoomStatus.confirmed => l10n(context).planConfirmedBadge,
      RoomStatus.recommended => l10n(context).preferencesCollected,
      RoomStatus.collecting =>
        allSubmitted
            ? l10n(context).preferencesCollected
            : l10n(context).collectingPreferences,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RoomDemoNotice extends StatelessWidget {
  const RoomDemoNotice({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      l10n(context).previewMembersAndItinerariesAreExamplesChanges,
      style: TextStyle(color: roomMuted, fontSize: 12, height: 1.5),
    ),
  );
}

class RoomAction extends StatelessWidget {
  const RoomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: roomTint,
      foregroundColor: roomBlue,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class RoomPageScaffold extends StatelessWidget {
  const RoomPageScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

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
              color: roomBackground,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFB9E4F8), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1629ACF0),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                  child: Row(
                    children: [
                      const BackButton(color: roomInk),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: roomInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
