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
  bool _loading = true;
  String? _loadError;
  String _meetingMode = 'middle';

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) _date = widget.initialDate!;
    _loadExisting();
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

  Future<void> _loadExisting() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = PlanitApi.instance;
      final room = await api.request(
        'GET', '/rooms/${Uri.encodeComponent(widget.roomId)}');
      final response = await api.request(
        'GET', '/rooms/${Uri.encodeComponent(widget.roomId)}/preferences');
      final mine = (response['members'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((m) => m['uid']?.toString() == api.currentUid)
          .toList();
      if (!mounted) return;
      final pref = mine.isEmpty ? null : mine.first['preferences'];
      _meetingMode = room['meeting_mode']?.toString() == 'fixed' ? 'fixed' : 'middle';
      if (pref is Map) {
        _budget.text = pref['budget']?.toString() ?? '30000';
        _region.text = pref['region']?.toString() ?? '';
        _departure.text = pref['departure_location']?.toString() ?? '';
        _activities.text = (pref['activities'] as List<dynamic>? ?? [])
            .map((value) => value.toString()).join(', ');
        _additionalNotes.text = pref['additional_notes']?.toString() ?? '';
        final savedDate = DateTime.tryParse(pref['available_date']?.toString() ?? '');
        if (savedDate != null) _date = savedDate;
        final start = pref['start_time']?.toString().split(':');
        if (start != null && start.length >= 2) {
          _from = TimeOfDay(hour: int.tryParse(start[0]) ?? 12, minute: int.tryParse(start[1]) ?? 0);
        }
        final end = pref['end_time']?.toString().split(':');
        if (end != null && end.length >= 2) {
          _until = TimeOfDay(hour: int.tryParse(end[0]) ?? 18, minute: int.tryParse(end[1]) ?? 0);
        }
      } else if (_meetingMode == 'fixed') {
        _region.text = room['meeting_region']?.toString() ?? '';
      }
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '저장된 조건을 불러오지 못했습니다: $error';
      });
    }
  }

  Future<void> _save() async {
    if (_loading || _loadError != null || !_formKey.currentState!.validate() || _saving) return;
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
          'departure_location': _meetingMode == 'middle'
              ? (_departure.text.trim().isEmpty ? _region.text.trim() : _departure.text.trim())
              : null,
          'available_date': _dateString(_date),
          'start_time': _timeString(_from),
          'end_time': _timeString(_until),
          'activities': activities,
          'additional_notes': _additionalNotes.text.trim(),
        },
      );
      final modeResult = await PlanitApi.instance.request(
        'PATCH',
        '/rooms/${Uri.encodeComponent(widget.roomId)}/meeting',
        query: {'regenerate': 'false'},
        body: {
          'mode': _meetingMode,
          'region': _meetingMode == 'fixed' ? _region.text.trim() : null,
        },
      );
      if (!mounted) return;
      final pending = result['proposal_created'] == true ||
          modeResult['proposal_created'] == true;
      Navigator.of(context).pop(pending
          ? '변경 제안이 등록됐습니다. 참가자 동의 후 적용됩니다.'
          : '저장 완료');
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
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
          ? Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                TextButton(onPressed: _loadExisting, child: const Text('다시 시도')),
              ],
            ))
          : Center(
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
              const Text('만남 장소 결정 방식', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fixed', label: Text('특정 장소')),
                  ButtonSegment(value: 'middle', label: Text('중간 지점')),
                ],
                selected: {_meetingMode},
                onSelectionChanged: (value) => setState(() => _meetingMode = value.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _region,
                decoration: InputDecoration(
                  labelText: _meetingMode == 'fixed' ? '만날 장소' : '희망 활동 지역',
                  hintText: _meetingMode == 'fixed' ? '예: 강남역 (정확한 장소명)' : '예: 강남역',
                  helperText: '정확한 국내 장소명을 한글로 입력하세요. 예: 강남역',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return '장소를 입력해 주세요.';
                  if (!RegExp(r'[가-힣]').hasMatch(text)) return '장소명을 한글로 입력해 주세요.';
                  return null;
                },
              ),
              if (_meetingMode == 'middle')
                TextFormField(
                  controller: _departure,
                  decoration: const InputDecoration(
                    labelText: '출발 위치 (선택)',
                    hintText: '예: 홍대입구역',
                    helperText: '비워 두면 희망 활동 지역을 출발지로 사용합니다.',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    return text.isNotEmpty && !RegExp(r'[가-힣]').hasMatch(text)
                        ? '국내 출발 장소를 한글로 입력해 주세요.'
                        : null;
                  },
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
                child: Text(_saving ? '저장 중...' : '저장하기'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
