import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import 'package:flutter/services.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import '../../widgets/scroll_time_picker.dart';
import 'ai_result_screen.dart';
import 'room_widgets.dart';
import 'room_preference_editor.dart';
import 'room_conditions_screen.dart';
import '../../services/planit_api.dart';
import '../profile/profile_widgets.dart';

class RoomDetailScreen extends StatelessWidget {
  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.controller,
    this.onConfirmed,
  });
  final String roomId;
  final RoomsController controller;
  final ValueChanged<PlanRoom>? onConfirmed;

  Future<void> _pickSchedule(BuildContext context, PlanRoom room) async {
    final date = await showDatePicker(
      context: context,
      initialDate: room.date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: l10n(context).planDate,
      confirmText: l10n(context).select,
      cancelText: l10n(context).cancel,
      builder: (context, child) =>
          Theme(data: profileTheme(context), child: child!),
    );
    if (date == null || !context.mounted) return;
    if (controller.online && room.status == RoomStatus.confirmed) {
      try {
        final proposed = await controller.changeConfirmedDateRemote(
          room.id,
          date,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              proposed
                  ? l10n(context).dateChangeRequestedTheDateWillChange
                  : l10n(context).confirmedPlanDateChanged,
            ),
          ),
        );
      } on PlanitApiException catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
      }
      return;
    }
    final time = await showScrollTimePicker(
      context,
      initialMinutes: room.date == null
          ? 13 * 60
          : room.date!.hour * 60 + room.date!.minute,
      title: l10n(context).planTime,
    );
    if (time == null || !context.mounted) return;
    try {
      final selected = scrollTimeOnDate(date, time);
      if (controller.online) {
        await controller.setDateRemote(room.id, selected);
      } else {
        controller.setDate(room.id, selected);
      }
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n(context).planDateSaved)));
    } on PlanitApiException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
    }
  }

  Future<void> _removeSchedule(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n(context).removeTheScheduledDate),
        content: Text(l10n(context).theRoomStaysOpenTheEventWill),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).removeDate),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        if (controller.online) {
          await controller.setDateRemote(roomId, null);
        } else {
          controller.setDate(roomId, null);
        }
      } on PlanitApiException catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
      }
    }
  }

  Future<void> _leaveRoom(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n(context).leaveThisRoom),
        content: Text(l10n(context).otherMembersWillKeepThePlanAnd),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n(context).leave),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      if (controller.online) {
        await controller.leaveRemote(roomId);
      } else {
        throw const PlanitApiException('서버 연결 후 방에서 나갈 수 있습니다.');
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n(context).youLeftTheRoom)));
    } on PlanitApiException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
    }
  }

  Future<void> _vote(
    BuildContext context,
    String decisionId,
    bool approve, {
    required bool dateRequest,
  }) async {
    try {
      await controller.voteRemote(
        roomId,
        decisionId,
        approve,
        dateRequest: dateRequest,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? l10n(context).approvalSubmitted
                : l10n(context).changeRequestDeclined,
          ),
        ),
      );
    } on PlanitApiException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
    }
  }

  Widget _pendingVoteCard(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool dateRequest,
  }) {
    final id =
        (dateRequest ? item['request_id'] : item['decision_id'])?.toString() ??
        '';
    final title = dateRequest
        ? l10n(context).dateChangeRequest(item['date']?.toString() ?? '')
        : item['change_type'] == 'preference_update'
        ? l10n(context).requestToChangeMemberPreferences
        : item['change_type'] == 'meeting_update'
        ? l10n(context).requestToChangeTheMeetingArea
        : l10n(context).requestToChangeTheItinerary;
    final busy = controller.isVoting('${roomId}:$id');
    final canVote = controller.canVote(item) && !busy && id.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (!canVote && !busy)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(l10n(context).alreadyVotedOrWaitingForOtherMembers),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: canVote
                      ? () => _vote(context, id, true, dateRequest: dateRequest)
                      : null,
                  child: Text(l10n(context).approve),
                ),
                TextButton(
                  onPressed: canVote
                      ? () =>
                            _vote(context, id, false, dateRequest: dateRequest)
                      : null,
                  child: Text(l10n(context).decline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n(context).inviteCodeCopied)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).pressAndHoldTheCodeToCopy)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.rooms.any((r) => r.id == roomId)) {
        return const SizedBox.shrink();
      }
      final room = controller.room(roomId);
      final ownMembers = room.members.where((member) => member.name == '나');
      final me = ownMembers.isEmpty ? null : ownMembers.first;
      return RoomPageScaffold(
        title: l10n(context).ourPlan,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RoomStatusBadge(
                status: room.status,
                allSubmitted: room.allSubmitted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              room.title,
              style: const TextStyle(
                fontSize: 24,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: roomInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${roomDate(room.date, context: context)} · ${room.region == '지역 미정' ? l10n(context).areaUndecided : room.region}',
              style: const TextStyle(
                color: roomMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _pickSchedule(context, room),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(
                    room.date == null
                        ? l10n(context).setPlanDate
                        : l10n(context).changePlanDate,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (room.date != null && room.status != RoomStatus.confirmed)
                  TextButton(
                    onPressed: () => _removeSchedule(context),
                    child: Text(
                      l10n(context).removeDate,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RoomPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n(context).inviteCode,
                    style: TextStyle(color: roomMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      room.inviteCode,
                      style: const TextStyle(
                        color: roomBlue,
                        fontSize: 13,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n(context).copyInviteCode,
                    onPressed: () => _copyCode(context, room.inviteCode),
                    icon: const Icon(
                      Icons.copy_outlined,
                      size: 17,
                      color: roomBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (me != null) ...[
              if (controller.online)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilledButton.icon(
                    onPressed: room.status == RoomStatus.confirmed
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RoomConditionsScreen(
                                controller: controller,
                                roomId: roomId,
                                initialDate: room.date,
                                initialRegion: room.region,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.tune),
                    label: Text(
                      me.submitted
                          ? l10n(context).editMyPlanPreferences
                          : l10n(context).enterMyPlanPreferences,
                    ),
                  ),
                )
              else
                RoomPreferenceEditor(
                  key: ValueKey('room-preferences-$roomId'),
                  initialText: me.summary,
                  readOnly: room.status == RoomStatus.confirmed,
                  onSave: (text) => controller.saveMyPreference(roomId, text),
                ),
              const SizedBox(height: 24),
            ],
            if (controller.online) ...[
              for (final request in controller.pendingDateRequests(roomId))
                _pendingVoteCard(context, request, dateRequest: true),
              for (final decision in controller.pendingDecisions(roomId))
                _pendingVoteCard(context, decision, dateRequest: false),
            ],
            if (controller.online &&
                room.allSubmitted &&
                room.status != RoomStatus.confirmed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    controller.isRecommending(roomId)
                        ? l10n(context).generatingAiRecommendations
                        : l10n(context).regenerateAiRecommendations,
                  ),
                  onPressed: controller.isRecommending(roomId)
                      ? null
                      : () async {
                          try {
                            await controller.recommendRemote(roomId);
                          } on PlanitApiException catch (e) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(displayError(context, e)),
                                ),
                              );
                          }
                        },
                ),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  l10n(context).members,
                  style: TextStyle(
                    color: roomInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n(
                    context,
                  ).submittedCount(room.submittedCount, room.members.length),
                  style: const TextStyle(color: roomMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RoomPanel(
              child: Column(
                children: [
                  for (var i = 0; i < room.members.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE6EFF5)),
                      ),
                    _member(context, room.members[i]),
                  ],
                ],
              ),
            ),
            if (room.course.isNotEmpty) ...[
              const SizedBox(height: 24),
              RoomAction(
                label: room.status == RoomStatus.confirmed
                    ? l10n(context).viewConfirmedItinerary
                    : l10n(context).viewSuggestedItinerary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiResultScreen(
                      roomId: roomId,
                      controller: controller,
                      onConfirmed: onConfirmed,
                    ),
                  ),
                ),
              ),
            ],
            if (controller.online) ...[
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _leaveRoom(context),
                  icon: const Icon(Icons.exit_to_app, size: 18),
                  label: Text(l10n(context).leaveRoom),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _member(BuildContext context, RoomMember member) => Row(
    key: ValueKey('room-member-${member.name}'),
    children: [
      const CircleAvatar(
        radius: 18,
        backgroundColor: roomTint,
        child: Icon(Icons.person_outline_rounded, color: roomBlue, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          switch ((member.isSelf, member.displayNumber)) {
            (true, _) => l10n(context).me,
            (false, final number?) => l10n(context).numberedMember(number),
            _ => member.name,
          },
          style: const TextStyle(
            color: roomInk,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Icon(
        member.submitted
            ? Icons.check_circle_outline_rounded
            : Icons.circle_outlined,
        color: member.submitted ? roomBlue : roomMuted,
        size: 15,
      ),
      const SizedBox(width: 5),
      Text(
        member.submitted ? l10n(context).submitted : l10n(context).pending,
        style: TextStyle(
          color: member.submitted ? roomBlue : roomMuted,
          fontSize: 11,
        ),
      ),
    ],
  );
}
