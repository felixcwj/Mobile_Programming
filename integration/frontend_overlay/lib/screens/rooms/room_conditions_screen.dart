import 'package:flutter/material.dart';

import '../../services/planit_api.dart';
import '../../services/rooms_controller.dart';

class RoomConditionsScreen extends StatefulWidget {
  const RoomConditionsScreen({super.key, required this.controller, required this.roomId,
    required this.initialDate, required this.initialRegion});
  final RoomsController controller;
  final String roomId;
  final DateTime? initialDate;
  final String initialRegion;

  @override
  State<RoomConditionsScreen> createState() => _RoomConditionsScreenState();
}

class _RoomConditionsScreenState extends State<RoomConditionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _region = TextEditingController();
  final _budget = TextEditingController(text: '30000');
  final _activities = TextEditingController();
  final _notes = TextEditingController();
  final _start = TextEditingController(text: '13:00');
  final _end = TextEditingController(text: '18:00');
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    _region.text = widget.initialRegion == '지역 미정' ? '' : widget.initialRegion;
  }

  @override
  void dispose() {
    for (final c in [_region, _budget, _activities, _notes, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final chosen = await showDatePicker(context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first, lastDate: DateTime(today.year + 3));
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  String? _timeValidation(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(v)) {
      return '24시간 형식 HH:MM으로 입력하세요.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_start.text.compareTo(_end.text) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 합니다.')));
      return;
    }
    final activities = _activities.text.split(',')
        .map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (activities.isEmpty || activities.length > 10 ||
        activities.any((a) => a.length > 40)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('활동을 쉼표로 구분하여 1~10개 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveConditionsRemote(widget.roomId,
        region: _region.text.trim(), date: _date,
        start: _start.text.trim(), end: _end.text.trim(),
        budget: int.parse(_budget.text), activities: activities,
        notes: _notes.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PlanitApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조건을 저장하지 못했습니다. 입력을 확인해 주세요.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('약속 조건 입력')),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Form(key: _formKey, child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('활동 지역은 대한민국 내 실제 지역이어야 합니다. 저장 전에 카카오 지도로 확인합니다.'),
          const SizedBox(height: 16),
          TextFormField(controller: _region, maxLength: 100,
            decoration: const InputDecoration(labelText: '놀고 싶은 지역', hintText: '예: 성수, 잠실'),
            validator: (v) => v == null || v.trim().isEmpty ? '지역을 입력해 주세요.' : null),
          ListTile(title: const Text('약속 날짜'),
            subtitle: Text('${_date.year}-${_date.month}-${_date.day}'),
            trailing: const Icon(Icons.calendar_month), onTap: _pickDate),
          TextFormField(controller: _start,
            decoration: const InputDecoration(labelText: '시작 시각 (13:00)'),
            validator: _timeValidation),
          TextFormField(controller: _end,
            decoration: const InputDecoration(labelText: '종료 시각 (18:00)'),
            validator: _timeValidation),
          TextFormField(controller: _budget, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '1인 예산 (원)'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 0 || n > 100000000
                ? '0~1억 원 사이로 입력해 주세요.' : null;
            }),
          TextFormField(controller: _activities, maxLength: 300,
            decoration: const InputDecoration(labelText: '원하는 활동',
              hintText: '예: 카페, 전시회, 산책'),
            validator: (v) => v == null || v.trim().isEmpty
              ? '활동을 하나 이상 입력해 주세요.' : null),
          TextFormField(controller: _notes, maxLength: 1000, maxLines: 3,
            decoration: const InputDecoration(labelText: '기타 사항 (선택)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: _saving ? null : _submit,
            child: Text(_saving ? '지역 확인 및 저장 중…' : '저장하기')),
        ],
      )),
    ))),
  );
}
