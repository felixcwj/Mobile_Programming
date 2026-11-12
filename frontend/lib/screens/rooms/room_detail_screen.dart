import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import 'ai_result_screen.dart';
import 'room_widgets.dart';

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
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: room.date == null
          ? const TimeOfDay(hour: 13, minute: 0)
          : TimeOfDay.fromDateTime(room.date!),
      helpText: '약속 시간',
      confirmText: '선택',
      cancelText: '취소',
    );
    if (time == null || !context.mounted) return;
    controller.setDate(
      room.id,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('약속 날짜를 캘린더에 추가했어요.')));
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
    if (accepted == true) controller.setDate(roomId, null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final room = controller.room(roomId);
      return Scaffold(
        backgroundColor: roomBackground,
        appBar: AppBar(
          title: const Text('우리의 약속'),
          backgroundColor: roomBackground,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RoomStatusBadge(status: room.status),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    room.title,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: roomInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${roomDate(room.date)} · ${room.region}',
                    style: const TextStyle(color: roomMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickSchedule(context, room),
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: Text(
                          room.date == null ? '약속 날짜 정하기' : '약속 날짜 변경',
                        ),
                      ),
                      if (room.date != null)
                        TextButton(
                          onPressed: () => _removeSchedule(context),
                          child: const Text('일정 해제'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  RoomPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '친구와 함께 준비해요',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '초대 코드 미리보기예요. 실제 방 참여는 서버 연결 후 가능해요.',
                          style: TextStyle(color: roomMuted, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                room.inviteCode,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  color: roomOrange,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '초대 코드 복사',
                              icon: const Icon(Icons.copy_outlined, size: 20),
                              onPressed: () async {
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(text: room.inviteCode),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('예시 초대 코드를 복사했어요.'),
                                    ),
                                  );
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '복사하지 못했어요. 코드를 길게 눌러 복사해 주세요.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '친구들의 취향  ${room.submittedCount}/${room.members.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '모두 입력하면 각자의 취향을 모아 코스를 만들어요.',
                    style: TextStyle(color: roomMuted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  RoomPanel(
                    child: Column(
                      children: [
                        for (var i = 0; i < room.members.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                          _member(room.members[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (room.course.isNotEmpty)
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
                    )
                  else ...[
                    RoomAction(
                      label: room.allSubmitted
                          ? 'AI 코스 생성 준비 중이에요'
                          : '친구들의 취향을 기다리고 있어요',
                      onPressed: null,
                      icon: Icons.hourglass_empty,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'AI 코스 생성은 백엔드 연결 후 제공될 예정이에요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: roomMuted, fontSize: 12),
                    ),
                  ],
                  const RoomDemoNotice(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _member(RoomMember member) => Row(
    children: [
      CircleAvatar(
        radius: 21,
        backgroundColor: member.submitted
            ? const Color(0xFFFFEEE4)
            : const Color(0xFFF1F1F1),
        child: Icon(
          Icons.person_outline,
          color: member.submitted ? roomOrange : roomMuted,
          size: 22,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              member.submitted ? member.summary : '아직 취향을 입력하지 않았어요',
              style: const TextStyle(
                color: roomMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Text(
        member.submitted ? '입력 완료' : '대기 중',
        style: TextStyle(
          color: member.submitted ? roomOrange : roomMuted,
          fontSize: 12,
        ),
      ),
    ],
  );
}
