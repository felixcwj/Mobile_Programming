import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/planit_l10n.dart';
import '../models/calendar_event.dart';
import '../services/planit_api.dart';
import '../services/rooms_controller.dart';
import '../widgets/planit_mascot.dart';
import '../widgets/scroll_time_picker.dart';
import 'profile/profile_widgets.dart';
import '../widgets/planit_notice.dart';

class CreatedRoom {
  final String name;
  final int capacity;
  final String code;
  final DateTime date;
  final EventCategory category;

  const CreatedRoom({
    required this.name,
    this.capacity = 8,
    required this.code,
    required this.date,
    this.category = EventCategory.personal,
  });
}

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key, this.onJoin, this.onCreate});

  final VoidCallback? onJoin;
  final Future<void> Function(CreatedRoom)? onCreate;

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  DateTime? _date;
  int? _time;
  EventCategory _category = EventCategory.personal;
  bool _showScheduleError = false;
  bool _submitting = false;

  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _generateCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '#@!';
    const all = '$letters$numbers$symbols';

    final random = Random.secure();

    final chars = <String>[
      letters[random.nextInt(letters.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
      ...List.generate(4, (_) => all[random.nextInt(all.length)]),
    ];

    chars.shuffle(random);
    return chars.join();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: l10n(context).planDate,
      confirmText: l10n(context).select,
      cancelText: l10n(context).cancel,
      builder: (context, child) =>
          Theme(data: profileTheme(context), child: child!),
    );
    if (date == null || !mounted) return;
    setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final time = await showScrollTimePicker(
      context,
      initialMinutes: _time ?? 13 * 60,
      title: l10n(context).planTime,
    );
    if (time == null || !mounted) return;
    setState(() => _time = time);
  }

  Future<void> _createRoom() async {
    if (_submitting || ModalRoute.of(context)?.isCurrent != true) return;
    if (_date == null || _time == null) {
      setState(() => _showScheduleError = true);
      return;
    }
    final name = _nameController.text.trim();

    final room = CreatedRoom(
      name: name.isEmpty ? l10n(context).newPlanRoom : name,
      date: scrollTimeOnDate(_date!, _time!),
      category: _category,
      code: _generateCode(),
    );

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      logRoomCreation('creation submitted');
      await widget.onCreate?.call(room);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.pop(context, room);
    } on RoomCreationUncertain {
      if (mounted) _showError(l10n(context).roomCreationUncertain);
    } on PlanitApiException catch (error) {
      if (mounted) _showError(displayError(context, error));
    } catch (_) {
      if (mounted) _showError(l10n(context).roomCreationFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    logRoomCreation('creation form showing recoverable error');
    showPlanitNotice(context, Text(message));
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFFF0F5F9),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: profileSurface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: const Color(0xFFCAE8F7), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1429ACF0),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n(context).close,
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: profileInk,
                          fixedSize: const Size.square(48),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 26),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlanitMascot(size: 30),
                            SizedBox(width: 10),
                            Text(
                              l10n(context).newRoom,
                              style: TextStyle(
                                color: profileInk,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('room-create-submit'),
                        tooltip: l10n(context).createRoom,
                        onPressed: _submitting ? null : _createRoom,
                        style: IconButton.styleFrom(
                          backgroundColor: profileButton,
                          foregroundColor: profileBlue,
                          fixedSize: const Size.square(48),
                        ),
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 28),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const ValueKey('room-name'),
                          controller: _nameController,
                          readOnly: _submitting,
                          keyboardType: TextInputType.text,
                          maxLength: 30,
                          maxLengthEnforcement:
                              MaxLengthEnforcement.truncateAfterCompositionEnds,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: profileInk,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n(context).roomNameOptional,
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            counterText: '',
                            labelStyle: const TextStyle(
                              color: Color(0xFF8397A5),
                              fontSize: 16,
                            ),
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: Color(0xFF9CD6F4),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n(context).category,
                          style: TextStyle(
                            color: profileInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in EventCategory.selectable)
                              ChoiceChip(
                                key: ValueKey('room-category-${category.name}'),
                                label: Text(
                                  displayLabel(context, category.label),
                                ),
                                selected: _category == category,
                                onSelected: _submitting
                                    ? null
                                    : (_) =>
                                          setState(() => _category = category),
                                selectedColor: profileButton,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: _category == category
                                      ? profileBlue
                                      : const Color(0xFFD5E6EF),
                                ),
                                labelStyle: const TextStyle(color: profileInk),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n(context).dateAndTime,
                          style: TextStyle(
                            color: profileInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ScheduleField(
                          key: const ValueKey('room-date'),
                          icon: Icons.calendar_month_outlined,
                          label: _date == null
                              ? l10n(context).chooseDate
                              : planDateLabel(context, _date!, weekday: false),
                          selected: _date != null,
                          onTap: _submitting ? null : _pickDate,
                        ),
                        const SizedBox(height: 10),
                        _ScheduleField(
                          key: const ValueKey('room-time'),
                          icon: Icons.schedule_rounded,
                          label: _time == null
                              ? l10n(context).chooseTime
                              : scrollTimeLabel(_time!),
                          selected: _time != null,
                          onTap: _submitting ? null : _pickTime,
                        ),
                        const SizedBox(height: 12),
                        if (_showScheduleError &&
                            (_date == null || _time == null))
                          Text(
                            l10n(context).chooseADateAndTime,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          )
                        else
                          Text(
                            l10n(context).theSelectedDateAndTimeWillAppear,
                            style: TextStyle(
                              color: Color(0xFF6C879A),
                              fontSize: 12,
                            ),
                          ),
                        if (widget.onJoin != null) ...[
                          const SizedBox(height: 26),
                          const Divider(color: Color(0xFFDDEAF2), height: 1),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    Navigator.pop(context);
                                    widget.onJoin!();
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: profileBlue,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(
                              l10n(context).orJoinWithACode,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: selected ? const Color(0xFFB9E4F8) : const Color(0xFFE3EDF4),
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: profileBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? profileInk : const Color(0xFF8397A5),
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: profileBlue,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}
