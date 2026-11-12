import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (!valid) _notice('문의 제목과 내용을 입력해 주세요.');
    return fieldsValid && valid;
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openMail() async {
    if (_opening || !_configured || !_validate()) return;
    final uri = Uri(
      scheme: 'mailto',
      path: _recipient,
      query:
          'subject=${Uri.encodeComponent('[플랜잇 1:1 문의] ${_subject.text.trim()}')}&body=${Uri.encodeComponent(_message.text.trim())}',
    );
    setState(() => _opening = true);
    try {
      final opened = await (widget.launchEmail?.call(uri) ?? launchUrl(uri));
      if (!mounted) return;
      _notice(
        opened
            ? '메일 작성 화면을 열었어요. 메일 앱에서 전송을 완료해 주세요.'
            : '메일 앱을 열지 못했어요. 문의 내용을 복사해 직접 보내주세요.',
      );
    } catch (_) {
      if (mounted) _notice('메일 앱을 열지 못했어요. 문의 내용을 복사해 직접 보내주세요.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _copy() async {
    if (!_validate()) return;
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${_configured ? '받는 사람: $_recipient\n' : ''}제목: [플랜잇 1:1 문의] ${_subject.text.trim()}\n\n${_message.text.trim()}',
        ),
      );
      if (mounted) _notice('문의 내용을 복사했어요.');
    } catch (_) {
      if (mounted) _notice('복사하지 못했어요. 작성한 내용을 직접 복사해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_opening,
    child: ProfilePageScaffold(
      title: '고객센터',
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
            const Text(
              '1:1 문의',
              style: TextStyle(
                color: profileInk,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '궁금한 점이나 불편한 점을 알려주세요.',
              style: TextStyle(color: Color(0xFF526A7B), height: 1.5),
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: '문의 작성',
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('supportSubject'),
                    controller: _subject,
                    maxLength: 100,
                    enabled: !_opening,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '문의 제목',
                      hintText: '제목을 입력해 주세요',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '제목을 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('supportMessage'),
                    controller: _message,
                    maxLength: 2000,
                    minLines: 6,
                    maxLines: 10,
                    enabled: !_opening,
                    decoration: const InputDecoration(
                      labelText: '문의 내용',
                      hintText: '어떤 도움이 필요하신가요?',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '문의 내용을 입력해 주세요.'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_configured) ...[
              Text(
                '받는 사람 · $_recipient',
                style: const TextStyle(color: Color(0xFF526A7B), fontSize: 12),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const Text(
                '고객센터 메일 주소를 준비 중이에요.\n문의 내용은 미리 작성할 수 있어요.',
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
              label: Text(_opening ? '메일 앱 여는 중…' : '메일 앱으로 보내기'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _opening ? null : _copy,
              icon: const Icon(Icons.copy_outlined, size: 17),
              label: const Text('문의 내용 복사'),
            ),
            const SizedBox(height: 6),
            const Text(
              '메일 앱에서 전송을 완료하면 문의가 전달돼요.',
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
