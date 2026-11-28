import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/planit_l10n.dart';

import '../../services/planit_api.dart';
import '../../widgets/planit_loading.dart';
import '../../services/rooms_controller.dart';
import '../../widgets/numeric_date_time_formatter.dart';
import '../profile/profile_widgets.dart';
import 'room_widgets.dart';
import '../../widgets/planit_notice.dart';

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
        final savedDate = DateTime.tryParse(
          (raw['available_date'] ?? '').toString(),
        );
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
      builder: (context, child) =>
          Theme(data: profileTheme(context), child: child!),
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
    if (_saving ||
        _loadingSaved ||
        _loadError != null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    if (_start.text.compareTo(_end.text) >= 0) {
      showPlanitNotice(context, Text(l10n(context).theEndTimeMustBeAfterThe));
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
      showPlanitNotice(
        context,
        Text(l10n(context).enterActivitiesSeparatedByCommas),
      );
      return;
    }
    FocusScope.of(context).unfocus();
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
      showPlanitNotice(
        context,
        Text(
          proposed
              ? l10n(context).changeRequestSentWaitingForMembersTo
              : l10n(context).planPreferencesSaved,
        ),
      );
      Navigator.pop(context, true);
    } on PlanitApiException catch (e) {
      if (mounted) {
        showPlanitNotice(context, Text(displayError(context, e)));
      }
    } catch (_) {
      if (mounted) {
        showPlanitNotice(
          context,
          Text(l10n(context).couldNotSavePreferencesCheckYourEntries),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String? label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: roomMuted, fontSize: 13),
        prefixIcon: icon == null ? null : Icon(icon, color: roomBlue, size: 20),
        filled: true,
        fillColor: profileWell,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        alignLabelWithHint: true,
      );

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) => RoomPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: roomTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: roomBlue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: roomInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );

  Widget _timeField(
    TextEditingController controller,
    String label,
    String key,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(color: roomMuted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 8),
      Semantics(
        label: label,
        child: TextFormField(
          key: ValueKey(key),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: const [NumericDateTimeFormatter.time()],
          decoration: _decoration(null, icon: Icons.schedule_rounded),
          validator: _timeValidation,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: RoomPageScaffold(
      title: l10n(context).planPreferences,
      child: PlanitLoadingOverlay(
        loading: _saving,
        message: l10n(context).verifyingAreaAndSaving,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: _saving || _loadingSaved,
                  child: ListView(
                    key: const ValueKey('room-conditions-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      if (_loadingSaved) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 16),
                      ],
                      if (_loadError != null) ...[
                        RoomPanel(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _loadError!,
                                  style: const TextStyle(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _section(
                        icon: Icons.calendar_month_outlined,
                        title: l10n(context).planDate,
                        children: [
                          Material(
                            color: profileWell,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              key: const ValueKey('condition-date'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              title: Text(
                                planDateLabel(context, _date, weekday: false),
                                style: const TextStyle(
                                  color: roomInk,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: roomBlue,
                              ),
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final start = _timeField(
                                _start,
                                l10n(context).startTime,
                                'condition-start',
                              );
                              final end = _timeField(
                                _end,
                                l10n(context).endTime,
                                'condition-end',
                              );
                              if (constraints.maxWidth < 280) {
                                return Column(
                                  children: [
                                    start,
                                    const SizedBox(height: 16),
                                    end,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: start),
                                  const SizedBox(width: 12),
                                  Expanded(child: end),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.place_outlined,
                        title: l10n(context).preferredArea,
                        children: [
                          Text(
                            l10n(context).chooseARealLocationInSouthKorea,
                            style: const TextStyle(
                              color: roomMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('condition-region'),
                            controller: _region,
                            maxLength: 100,
                            maxLengthEnforcement: MaxLengthEnforcement
                                .truncateAfterCompositionEnds,
                            decoration: _decoration(
                              l10n(context).preferredArea,
                              hint: l10n(context).eGSeongsuJamsil,
                              icon: Icons.search_rounded,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? l10n(context).enterAnArea
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('condition-budget'),
                            controller: _budget,
                            keyboardType: TextInputType.number,
                            decoration: _decoration(
                              l10n(context).budgetPerPersonKrw,
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 0 || n > 100000000
                                  ? l10n(context).enterAnAmountBetweenAnd
                                  : null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _section(
                        icon: Icons.favorite_border_rounded,
                        title: l10n(context).preferredActivities,
                        children: [
                          TextFormField(
                            key: const ValueKey('condition-activities'),
                            controller: _activities,
                            maxLength: 300,
                            maxLengthEnforcement: MaxLengthEnforcement
                                .truncateAfterCompositionEnds,
                            minLines: 2,
                            maxLines: 4,
                            decoration: _decoration(
                              l10n(context).preferredActivities,
                              hint: l10n(context).eGCafExhibitionWalk,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? l10n(context).enterAtLeastOneActivity
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('condition-notes'),
                            controller: _notes,
                            maxLength: 1000,
                            maxLengthEnforcement: MaxLengthEnforcement
                                .truncateAfterCompositionEnds,
                            minLines: 3,
                            maxLines: 5,
                            decoration: _decoration(
                              l10n(context).otherDetailsOptional,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('condition-save'),
                    onPressed: _saving || _loadingSaved || _loadError != null
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: roomBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      _saving
                          ? l10n(context).verifyingAreaAndSaving
                          : l10n(context).save2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
