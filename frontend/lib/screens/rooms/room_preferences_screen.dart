import 'package:flutter/material.dart';

import '../../services/planit_api.dart';

class RoomPreferencesScreen extends StatefulWidget {
  const RoomPreferencesScreen({super.key, required this.roomId, this.initialDate});
  final String roomId;
  final DateTime? initialDate;

  @override
  State<RoomPreferencesScreen> createState() => _RoomPreferencesScreenState();
}

class _RoomPreferencesScreenState extends State<RoomPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budget = TextEditingController(text: '30000');
  final _region = TextEditingController();
  final _departure = TextEditingController();
  final _activities = TextEditingController(text: '카페, 산책');
  final _additionalNotes = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _from = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _until = const TimeOfDay(hour: 18, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) _date = widget.initialDate!;
  }

  @override
  void dispose() {
    _budget.dispose();
    _region.dispose();
    _departure.dispose();
    _activities.dispose();
    _additionalNotes.dispose();
    super.dispose();
  }

  String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _timeString(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final activities = _activities.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('활동을 하나 이상 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await PlanitApi.instance.request(
        'POST',
        '/rooms/${Uri.encodeComponent(widget.roomId)}/preferences',
        query: {'regenerate': 'false'},
        body: {
          'budget': int.parse(_budget.text),
          'region': _region.text.trim(),
          'departure_location': _departure.text.trim().isEmpty
              ? _region.text.trim()
              : _departure.text.trim(),
          'available_date': _dateString(_date),
          'start_time': _timeString(_from),
          'end_time': _timeString(_until),
          'activities': activities,
          'additional_notes': _additionalNotes.text.trim(),
        },
      );
      if (!mounted) return;
      final pending = result['proposal_created'] == true;
      Navigator.of(context).pop(pending ? '수정안이 등록됐습니다. 전원 동의 후 반영됩니다.' : '조건을 저장했습니다.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장하지 못했습니다: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
    );
    if (next != null) setState(() => _date = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('내 약속 조건')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _budget,
                decoration: const InputDecoration(labelText: '1인 예산 (원)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  return amount == null || amount < 0 || amount > 100000000
                      ? '올바른 예산을 입력해 주세요.'
                      : null;
                },
              ),
              TextFormField(
                controller: _region,
                decoration: const InputDecoration(labelText: '활동 지역'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? '활동 지역을 입력해 주세요.'
                    : null,
              ),
              TextFormField(
                controller: _departure,
                decoration: const InputDecoration(labelText: '출발 위치 (선택)'),
              ),
              ListTile(
                title: const Text('가능 날짜'),
                subtitle: Text(_dateString(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              ListTile(
                title: const Text('시작 시각'),
                subtitle: Text(_timeString(_from)),
                onTap: () async {
                  final chosen = await showTimePicker(context: context, initialTime: _from);
                  if (chosen != null) setState(() => _from = chosen);
                },
              ),
              ListTile(
                title: const Text('종료 시각'),
                subtitle: Text(_timeString(_until)),
                onTap: () async {
                  final chosen = await showTimePicker(context: context, initialTime: _until);
                  if (chosen != null) setState(() => _until = chosen);
                },
              ),
              TextFormField(
                controller: _activities,
                decoration: const InputDecoration(labelText: '희망 활동 (쉼표로 구분)'),
                maxLength: 150,
              ),
              TextFormField(
                controller: _additionalNotes,
                decoration: const InputDecoration(labelText: '기타 사항 (AI 추천에 반영)'),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중...' : '조건 저장'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
