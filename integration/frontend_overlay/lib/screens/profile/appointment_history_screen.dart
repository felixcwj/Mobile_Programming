import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import 'profile_widgets.dart';

class AppointmentHistoryScreen extends StatelessWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => ProfilePageScaffold(
    title: l10n(context).planHistory,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: profileButton,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_note_outlined,
                size: 38,
                color: profileBlue,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n(context).noPlansYet,
              style: TextStyle(
                color: profileInk,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
