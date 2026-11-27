import 'package:flutter/material.dart';
import '../l10n/planit_l10n.dart';

import '../models/calendar_event.dart';
import '../models/plan_room.dart';
import '../services/calendar_controller.dart';
import '../widgets/planit_mascot.dart';
import 'calendar/event_editor_sheet.dart';
import 'profile/profile_widgets.dart';

const _muted = Color(0xFF6C879A);

class HomePlanTask {
  const HomePlanTask({required this.room, required this.reviewCourse});
  final PlanRoom room;
  final bool reviewCourse;

  static List<HomePlanTask> forRooms(List<PlanRoom> rooms, DateTime now) {
    final tasks = <HomePlanTask>[];
    for (final room in rooms) {
      if (room.date != null &&
          calendarDay(room.date!).isBefore(calendarDay(now))) {
        continue;
      }
      // Upcoming rooms stay visible in To-do after preference submission.
      final canReview = room.status == RoomStatus.recommended &&
          room.allSubmitted &&
          room.course.isNotEmpty;
      tasks.add(HomePlanTask(room: room, reviewCourse: canReview));
    }
    tasks.sort((a, b) {
      if (a.room.date == null) return b.room.date == null ? 0 : 1;
      if (b.room.date == null) return -1;
      return a.room.date!.compareTo(b.room.date!);
    });
    return tasks;
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.controller,
    required this.now,
    required this.onOpenEntry,
    required this.onOpenTask,
    required this.onCreatePlan,
    required this.onChooseDday,
  });

  final CalendarController controller;
  final DateTime now;
  final ValueChanged<CalendarEntry> onOpenEntry;
  final ValueChanged<HomePlanTask> onOpenTask;
  final VoidCallback onCreatePlan;
  final VoidCallback onChooseDday;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final featured = controller.featuredEntry(now);
      final tasks = HomePlanTask.forRooms(
        controller.roomsController.rooms,
        now,
      );
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('home-dashboard-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeaturedPlan(
                  entry: featured,
                  pinned: controller.ddayEventId != null,
                  now: now,
                  color: featured == null
                      ? profileBlue
                      : Color(controller.colorFor(featured.event.category)),
                  onOpen: featured == null
                      ? onCreatePlan
                      : () => onOpenEntry(featured),
                  onChoose: onChooseDday,
                  compact: constraints.maxHeight < 440,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: profileBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'To do',
                        style: TextStyle(
                          color: profileInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (tasks.isNotEmpty)
                      Text(
                        '${tasks.length}',
                        style: const TextStyle(
                          color: profileBlue,
                          fontFamily: 'Fredoka',
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Material(
                  key: const ValueKey('home-tasks'),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Color(0xFFDDECF5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: tasks.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Icon(
                                Icons.done_all_rounded,
                                color: Color(0xFF69AD94),
                                size: 23,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n(context).nothingToDoRightNow,
                                      style: TextStyle(
                                        color: profileInk,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      l10n(
                                        context,
                                      ).checkWhatYourPlansStillNeedHere,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < tasks.length;
                              index++
                            ) ...[
                              if (index > 0)
                                const Divider(
                                  height: 1,
                                  indent: 18,
                                  endIndent: 18,
                                  color: Color(0xFFEAF3F9),
                                ),
                              _TaskTile(
                                task: tasks[index],
                                onTap: () => onOpenTask(tasks[index]),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FeaturedPlan extends StatelessWidget {
  const _FeaturedPlan({
    required this.entry,
    required this.pinned,
    required this.now,
    required this.color,
    required this.onOpen,
    required this.onChoose,
    required this.compact,
  });
  final CalendarEntry? entry;
  final bool pinned;
  final DateTime now;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onChoose;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home-featured-card'),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE2F3FF), Color(0xFFF1FAFF)],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFBFE3F7), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C0077CC),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(14, 6, 14, 12)
            : const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pinned
                        ? l10n(context).myCountdown
                        : l10n(context).upcomingPlans,
                    style: const TextStyle(
                      color: profileInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('home-dday-select'),
                  onPressed: onChoose,
                  style: TextButton.styleFrom(
                    foregroundColor: profileBlue,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: Icon(
                    pinned ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    pinned ? l10n(context).change : l10n(context).setCountdown,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 10),
            if (entry == null) ...[
              if (!compact)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PlanitMascot(size: 62),
                ),
              if (!compact) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n(context).readyToMakeANewPlan,
                      style: TextStyle(
                        color: profileInk,
                        fontSize: compact ? 20 : 23,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        letterSpacing: -.7,
                      ),
                    ),
                  ),
                  if (compact) const PlanitMascot(size: 48),
                ],
              ),
              SizedBox(height: compact ? 6 : 8),
              Text(
                l10n(context).planADayToLookForwardTo,
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
              SizedBox(height: compact ? 10 : 16),
              FilledButton.icon(
                key: const ValueKey('home-create-first-plan'),
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: profileBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(l10n(context).makeAPlan),
              ),
            ] else
              InkWell(
                key: const ValueKey('home-featured-event'),
                onTap: onOpen,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              calendarDdayLabel(entry!.start, now),
                              key: const ValueKey('home-dday-label'),
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                color: profileBlue,
                                fontSize: compact ? 40 : 48,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                                letterSpacing: -1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: compact ? 44 : 56,
                          height: compact ? 44 : 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Icon(
                            pinned
                                ? Icons.star_rounded
                                : Icons.event_available_outlined,
                            color: profileBlue,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    Text(
                      entry!.event.title,
                      key: const ValueKey('home-featured-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: profileInk,
                        fontSize: compact ? 19 : 21,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        letterSpacing: -.5,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: _muted,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${planCompactDate(context, entry!.start)} · ${entry!.event.allDay ? l10n(context).allDay : calendarTimeLabel(entry!.start)}',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 7, color: color),
                              const SizedBox(width: 5),
                              Text(
                                displayLabel(
                                  context,
                                  entry!.event.category.label,
                                ),
                                style: const TextStyle(
                                  color: profileInk,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          l10n(context).viewDetails,
                          style: TextStyle(
                            color: profileBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: profileBlue,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final HomePlanTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('home-task-${task.room.id}'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: profileWell,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              task.reviewCourse
                  ? Icons.auto_awesome_outlined
                  : Icons.edit_note_rounded,
              color: profileBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.reviewCourse
                      ? l10n(context).viewSuggestedItinerary
                      : task.room.status == RoomStatus.confirmed
                          ? displayLabel(context, task.room.status.label)
                          : task.room.members.any((m) => m.isSelf && m.submitted)
                              ? displayLabel(context, task.room.status.label)
                              : l10n(context).enterMyPreferences,
                  style: const TextStyle(
                    color: profileInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: profileBlue),
        ],
      ),
    ),
  );
}

Future<void> showHomeDdayPicker(
  BuildContext context, {
  required CalendarController controller,
  required VoidCallback onAddEvent,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (context) => Theme(
    data: profileTheme(context),
    child: _DdayPicker(controller: controller, onAddEvent: onAddEvent),
  ),
);

class _DdayPicker extends StatefulWidget {
  const _DdayPicker({required this.controller, required this.onAddEvent});
  final CalendarController controller;
  final VoidCallback onAddEvent;

  @override
  State<_DdayPicker> createState() => _DdayPickerState();
}

class _DdayPickerState extends State<_DdayPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Material(
      color: profileSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final now = DateTime.now();
              final entries = widget.controller
                  .ddayChoices(now)
                  .where(
                    (entry) => entry.event.title.toLowerCase().contains(
                      _query.trim().toLowerCase(),
                    ),
                  )
                  .toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n(context).setMyCountdown,
                            style: TextStyle(
                              color: profileInk,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n(context).closeCountdownSettings,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n(context).pinAnEventToYourHomeScreen,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: TextField(
                      key: const ValueKey('dday-search'),
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: l10n(context).searchEvents,
                        prefixIcon: Icon(Icons.search_rounded),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.event_note_rounded,
                                    color: profileBlue,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _query.trim().isEmpty
                                        ? l10n(context).noEventsYet
                                        : l10n(context).noMatchingEvents,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final selected =
                                  widget.controller.ddayEventId ==
                                  entry.event.id;
                              return ListTile(
                                key: ValueKey('dday-choice-${entry.event.id}'),
                                selected: selected,
                                selectedTileColor: profileButton,
                                leading: Icon(
                                  selected
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: selected
                                      ? profileBlue
                                      : Color(
                                          widget.controller.colorFor(
                                            entry.event.category,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  entry.event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: profileInk,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${planCompactDate(context, entry.start)} · ${entry.event.allDay ? l10n(context).allDay : calendarTimeLabel(entry.start)} · ${displayLabel(context, entry.event.category.label)}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Text(
                                  calendarDdayLabel(entry.start, now),
                                  style: const TextStyle(
                                    color: profileBlue,
                                    fontFamily: 'Fredoka',
                                    fontSize: 16,
                                  ),
                                ),
                                onTap: () {
                                  widget.controller.setDday(entry.event.id);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        if (widget.controller.ddayEventId != null)
                          TextButton(
                            key: const ValueKey('clear-home-dday'),
                            onPressed: () {
                              widget.controller.setDday(null);
                              Navigator.pop(context);
                            },
                            child: Text(l10n(context).unpin),
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onAddEvent();
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(
                                l10n(context).addEvent,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
