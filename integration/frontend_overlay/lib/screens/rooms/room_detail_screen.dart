import 'package:flutter/material.dart';
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
      helpText: '약속 날짜',
      confirmText: '선택',
      cancelText: '취소',
      builder: (context, child) =>
          Theme(data: profileTheme(context), child: child!),
    );
    if (date == null || !context.mounted) return;
    final time = await showScrollTimePicker(
      context,
      initialMinutes: room.date == null
          ? 13 * 60
          : room.date!.hour * 60 + room.date!.minute,
      title: '약속 시간',
    );
    if (time == null || !context.mounted) return;
    try {
      final selected = scrollTimeOnDate(date, time);
      if (controller.online) {
        await controller.setDateRemote(room.id, selected);
      } else {
        controller.setDate(room.id, selected);
      }
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약속 날짜를 저장했어요.')));
    } on PlanitApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeSchedule(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('약속 일정을 해제할까요?'),
        content: const Text('방은 유지되고 캘린더에서 일정만 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('일정 해제'),
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
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('초대 코드를 복사했어요.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코드를 길게 눌러 복사해 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final room = controller.room(roomId);
      final ownMembers = room.members.where((member) => member.name == '나');
      final me = ownMembers.isEmpty ? null : ownMembers.first;
      return RoomPageScaffold(
        title: '우리의 약속',
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
              '${roomDate(room.date)} · ${room.region}',
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
                    room.date == null ? '약속 날짜 정하기' : '약속 날짜 변경',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (room.date != null)
                  TextButton(
                    onPressed: () => _removeSchedule(context),
                    child: const Text('일정 해제', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RoomPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    '초대 코드',
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
                    tooltip: '초대 코드 복사',
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
                    onPressed: room.status == RoomStatus.confirmed ? null : () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => RoomConditionsScreen(
                            controller: controller, roomId: roomId,
                            initialDate: room.date, initialRegion: room.region))),
                    icon: const Icon(Icons.tune),
                    label: Text(me.submitted ? '나의 약속 조건 변경' : '나의 약속 조건 입력'),
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
            if (controller.online && room.allSubmitted &&
                room.status != RoomStatus.confirmed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 다시 추천받기'),
                  onPressed: () async {
                    try {
                      await controller.recommendRemote(roomId);
                    } on PlanitApiException catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.message)));
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
                const Text(
                  '참여자',
                  style: TextStyle(
                    color: roomInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '입력 완료 ${room.submittedCount}/${room.members.length}',
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
                    _member(room.members[i]),
                  ],
                ],
              ),
            ),
            if (room.course.isNotEmpty) ...[
              const SizedBox(height: 24),
              RoomAction(
                label: room.status == RoomStatus.confirmed
                    ? '확정된 코스 보기'
                    : '추천 코스 확인하기',
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
          ],
        ),
      );
    },
  );

  Widget _member(RoomMember member) => Row(
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
          member.name,
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
        member.submitted ? '입력 완료' : '대기 중',
        style: TextStyle(
          color: member.submitted ? roomBlue : roomMuted,
          fontSize: 11,
        ),
      ),
    ],
  );
}
