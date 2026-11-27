import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/planit_l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/support_config.dart';
import 'profile_widgets.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    this.supportEmail = defaultSupportEmail,
    this.launchEmail,
  });

  final String supportEmail;
  final Future<bool> Function(Uri)? launchEmail;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _opening = false;

  String get _recipient => widget.supportEmail.trim();
  bool get _configured =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_recipient);

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  bool _validate() {
    final fieldsValid = _formKey.currentState!.validate();
    // Validate controller values even if a field is scrolled out of view.
    final valid =
        _subject.text.trim().isNotEmpty &&
        _subject.text.trim().length <= 100 &&
        _message.text.trim().isNotEmpty &&
        _message.text.trim().length <= 2000;
    if (!valid) _notice(l10n(context).enterASubjectAndAMessage);
    return fieldsValid && valid;
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openMail() async {
    if (_opening || !_configured || !_validate()) return;
    final subject = l10n(context).supportEmailSubject(_subject.text.trim());
    final uri = Uri(
      scheme: 'mailto',
      path: _recipient,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(_message.text.trim())}',
    );
    setState(() => _opening = true);
    try {
      final opened = await (widget.launchEmail?.call(uri) ?? launchUrl(uri));
      if (!mounted) return;
      _notice(
        opened
            ? l10n(context).yourDraftIsOpenSendItFrom
            : l10n(context).couldNotOpenYourEmailAppPlease,
      );
    } catch (_) {
      if (mounted) _notice(l10n(context).couldNotOpenYourEmailAppPlease);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_opening,
    child: ProfilePageScaffold(
      title: l10n(context).support,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                backgroundColor: profileButton,
                radius: 27,
                child: Icon(Icons.mail_outline, color: profileBlue, size: 27),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n(context).contactSupport,
              style: TextStyle(
                color: profileInk,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n(context).tellUsYourQuestionOrReportA,
              style: TextStyle(color: Color(0xFF526A7B), height: 1.5),
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: l10n(context).writeAMessage,
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('supportSubject'),
                    controller: _subject,
                    maxLength: 100,
                    maxLengthEnforcement:
                        MaxLengthEnforcement.truncateAfterCompositionEnds,
                    enabled: !_opening,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n(context).subject,
                      hintText: l10n(context).enterASubject,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n(context).enterATitle
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('supportMessage'),
                    controller: _message,
                    maxLength: 2000,
                    maxLengthEnforcement:
                        MaxLengthEnforcement.truncateAfterCompositionEnds,
                    minLines: 6,
                    maxLines: 10,
                    enabled: !_opening,
                    decoration: InputDecoration(
                      labelText: l10n(context).message,
                      hintText: l10n(context).howCanWeHelp,
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n(context).enterAMessage
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_configured) ...[
              Text(
                l10n(context).supportRecipient(_recipient),
                style: const TextStyle(color: Color(0xFF526A7B), fontSize: 12),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Text(
                l10n(context).theSupportEmailAddressIsBeingSet,
                style: TextStyle(
                  color: Color(0xFF526A7B),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _configured && !_opening ? _openMail : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.mail_outline, size: 19),
              label: Text(
                _opening
                    ? l10n(context).openingEmailApp
                    : l10n(context).openInEmailApp,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n(context).sendTheMessageFromYourEmailApp,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7D8C98),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
