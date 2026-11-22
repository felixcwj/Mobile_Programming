import 'package:flutter/material.dart';
import '../../services/planit_api.dart';
import '../../services/planit_server_config.dart';

/// Opens a device-local endpoint selector for classroom LAN or cloud staging.
/// No API keys, ID tokens or service account credentials are entered here.
Future<void> showPlanitServerSettings(BuildContext context) async {
  final controller = TextEditingController(text: PlanitServerConfig.url);
  bool checking = false;
  String? status;
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                controller: controller,
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
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(status!, key: const ValueKey('planit-server-status')),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: checking ? null : () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: checking ? null : () async {
                final address = controller.text.trim();
                if (!PlanitServerConfig.isValid(address)) {
                  setDialogState(() => status = 'HTTPS 주소 또는 내부망 IP 주소를 확인해 주세요.');
                  return;
                }
                setDialogState(() {
                  checking = true;
                  status = '서버 연결 확인 중…';
                });
                try {
                  final result = await PlanitApi(baseUrlOverride: address)
                      .request('GET', '/health', authenticated: false);
                  if (result['status'] != 'ok') {
                    throw const PlanitApiException('서버 상태가 정상이 아닙니다.');
                  }
                  await PlanitServerConfig.save(address);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('팀 서버 연결을 확인하고 주소를 저장했습니다.'),
                    ));
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() => status = error is PlanitApiException
                        ? error.message
                        : '서버 연결에 실패했습니다. 주소와 Wi-Fi 연결을 확인해 주세요.');
                  }
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() => checking = false);
                  }
                }
              },
              child: const Text('연결 확인 및 저장'),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}
