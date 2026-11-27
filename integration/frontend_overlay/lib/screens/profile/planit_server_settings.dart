import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import '../../services/planit_api.dart';
import '../../services/planit_server_config.dart';

/// Only a backend URL is entered here; API keys remain in server secrets.
Future<void> showPlanitServerSettings(BuildContext context) => showDialog<void>(
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
      setState(
        () => _status = l10n(context).checkTheHttpsAddressOrLocalNetwork,
      );
      return;
    }
    setState(() {
      _checking = true;
      _status = l10n(context).checkingServerConnection;
    });
    try {
      final result = await PlanitApi(
        baseUrlOverride: address,
      ).request('GET', '/health', authenticated: false);
      if (result['status'] != 'ok') {
        throw const PlanitApiException('서버 상태가 정상이 아닙니다.');
      }
      await PlanitServerConfig.save(address);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n(context).serverConnectionVerifiedAndAddressSaved),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = error is PlanitApiException
              ? displayError(context, error)
              : l10n(context).couldNotConnectCheckTheServerAddress,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(l10n(context).teamServer),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n(context).teamMembersMustUseTheSameServer),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('planit-server-url'),
          controller: _controller,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n(context).serverAddress,
            hintText: 'https://planit-team.example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n(context).onAPhysicalTabletUseAPublic,
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
        child: Text(l10n(context).cancel),
      ),
      FilledButton(
        onPressed: _checking ? null : _checkAndSave,
        child: Text(l10n(context).verifyAndSave),
      ),
    ],
  );
}
