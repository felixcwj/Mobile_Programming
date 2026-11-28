import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/planit_l10n.dart';

import '../../services/planit_api.dart';
import '../../services/rooms_controller.dart';
import '../../widgets/numeric_date_time_formatter.dart';

class RoomConditionsScreen extends StatefulWidget {
  const RoomConditionsScreen({
    super.key,
    required this.controller,
    required this.roomId,
    required this.initialDate,
    required this.initialRegion,
  });
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
  bool _loadingSaved = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    _region.text = widget.initialRegion == '지역 미정' ? '' : widget.initialRegion;
    final scheduled = widget.initialDate;
    if (scheduled != null) {
      final startMinutes = scheduled.hour * 60 + scheduled.minute;
      _start.text = _formatMinutes(startMinutes);
      final endMinutes = (startMinutes + 180).clamp(0, 1439).toInt();
      _end.text = _formatMinutes(endMinutes);
    }
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final service = widget.controller.api;
      if (service == null) {
        throw const PlanitApiException('서버에 연결되지 않았습니다.');
      }
      final response = await service.myRoomPreferences(widget.roomId);
      if (!mounted) return;
      final raw = response['preferences'];
      if (response['submitted'] == true && raw is Map) {
        final savedDate = DateTime.tryParse((raw['available_date'] ?? '').toString());
        final activities = raw['activities'];
        setState(() {
          if (savedDate != null) _date = savedDate;
          _region.text = (raw['region'] ?? _region.text).toString();
          _start.text = (raw['start_time'] ?? _start.text).toString();
          _end.text = (raw['end_time'] ?? _end.text).toString();
          _budget.text = (raw['budget'] ?? _budget.text).toString();
          if (activities is List) {
            _activities.text = activities.map((a) => a.toString()).join(', ');
          }
          _notes.text = (raw['additional_notes'] ?? '').toString();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = '저장된 조건을 불러오지 못했습니다. 다시 열어 주세요.');
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

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
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: DateTime(today.year + 3),
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  String? _timeValidation(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(v)) {
      return l10n(context).useHourTimeHhMm;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving || _loadingSaved || _loadError != null || !_formKey.currentState!.validate()) return;
    if (_start.text.compareTo(_end.text) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).theEndTimeMustBeAfterThe)),
      );
      return;
    }
    final activities = _activities.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (activities.isEmpty ||
        activities.length > 10 ||
        activities.any((a) => a.length > 40)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).enterActivitiesSeparatedByCommas)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final proposed = await widget.controller.saveConditionsRemote(
        widget.roomId,
        region: _region.text.trim(),
        date: _date,
        start: _start.text.trim(),
        end: _end.text.trim(),
        budget: int.parse(_budget.text),
        activities: activities,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            proposed
                ? l10n(context).changeRequestSentWaitingForMembersTo
                : l10n(context).planPreferencesSaved,
          ),
        ),
      );
      Navigator.pop(context, true);
    } on PlanitApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n(context).couldNotSavePreferencesCheckYourEntries,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(l10n(context).planPreferences)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_loadingSaved) const LinearProgressIndicator(),
                if (_loadError != null) Text(_loadError!, style: const TextStyle(color: Colors.red)),
                Text(l10n(context).chooseARealLocationInSouthKorea),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _region,
                  maxLength: 100,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  decoration: InputDecoration(
                    labelText: l10n(context).preferredArea,
                    hintText: l10n(context).eGSeongsuJamsil,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n(context).enterAnArea
                      : null,
                ),
                ListTile(
                  title: Text(l10n(context).planDate),
                  subtitle: Text(planDateLabel(context, _date, weekday: false)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickDate,
                ),
                TextFormField(
                  controller: _start,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [NumericDateTimeFormatter.time()],
                  decoration: InputDecoration(
                    labelText: l10n(context).startTime2,
                  ),
                  validator: _timeValidation,
                ),
                TextFormField(
                  controller: _end,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [NumericDateTimeFormatter.time()],
                  decoration: InputDecoration(
                    labelText: l10n(context).endTime2,
                  ),
                  validator: _timeValidation,
                ),
                TextFormField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n(context).budgetPerPersonKrw,
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 0 || n > 100000000
                        ? l10n(context).enterAnAmountBetweenAnd
                        : null;
                  },
                ),
                TextFormField(
                  controller: _activities,
                  maxLength: 300,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  decoration: InputDecoration(
                    labelText: l10n(context).preferredActivities,
                    hintText: l10n(context).eGCafExhibitionWalk,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n(context).enterAtLeastOneActivity
                      : null,
                ),
                TextFormField(
                  controller: _notes,
                  maxLength: 1000,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n(context).otherDetailsOptional,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving || _loadingSaved || _loadError != null ? null : _submit,
                  child: Text(
                    _saving
                        ? l10n(context).verifyingAreaAndSaving
                        : l10n(context).save2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
