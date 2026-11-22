import 'package:flutter/material.dart';
import '../../services/planit_api.dart';
import '../../services/planit_server_config.dart';

/// Only a backend URL is entered here; API keys remain in server secrets.
Future<void> showPlanitServerSettings(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const _PlanitServerSettingsDialog(),
    );

class _PlanitServerSettingsDialog extends StatefulWidget {
  const _PlanitServerSettingsDialog();

  @override
  State<_PlanitServerSettingsDialog> createState() =>
      _PlanitServerSettingsDialogState();
}

class _PlanitServerSettingsDialogState
    extends State<_PlanitServerSettingsDialog> {
  late final TextEditingController _controller;
  bool _checking = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: PlanitServerConfig.url);
  }

  @override
  void dispose() {
    // A dialog route stays alive during its exit animation. Dispose only when
    // Flutter actually removes the widget, not on Navigator.pop's Future.
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAndSave() async {
    if (_checking) return;
    final address = _controller.text.trim();
    if (!PlanitServerConfig.isValid(address)) {
      setState(() => _status = 'HTTPS 주소 또는 내부망 IP 주소를 확인해 주세요.');
      return;
    }
    setState(() {
      _checking = true;
      _status = '서버 연결 확인 중…';
    });
    try {
      final result = await PlanitApi(baseUrlOverride: address)
          .request('GET', '/health', authenticated: false);
      if (result['status'] != 'ok') {
        throw const PlanitApiException('서버 상태가 정상이 아닙니다.');
      }
      await PlanitServerConfig.save(address);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('팀 서버 연결을 확인하고 주소를 저장했습니다.'),
      ));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _status = error is PlanitApiException
            ? error.message
            : '서버 연결에 실패했습니다. 주소와 Wi-Fi 연결을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('팀 서버 연결'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('모든 팀원이 같은 서버 주소를 입력해야 방과 일정이 공유됩니다.'),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('planit-server-url'),
          controller: _controller,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '서버 주소',
            hintText: 'https://planit-team.example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '실제 태블릿은 10.0.2.2를 사용할 수 없습니다. '
          '공용 HTTPS 서버를 사용하세요. 같은 Wi-Fi 테스트는 개발용 앱에서 내부 IP로 연결할 수 있습니다.',
          style: TextStyle(fontSize: 12),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_status!, key: const ValueKey('planit-server-status')),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _checking ? null : () => Navigator.of(context).pop(),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _checking ? null : _checkAndSave,
        child: const Text('연결 확인 및 저장'),
      ),
    ],
  );
}
