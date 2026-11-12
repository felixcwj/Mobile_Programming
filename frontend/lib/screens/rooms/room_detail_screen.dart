import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import 'ai_result_screen.dart';
import 'room_preferences_screen.dart';
import 'room_votes_screen.dart';
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
  static final Set<String> _generatingRooms = <String>{};

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
    if (room.status == RoomStatus.confirmed &&
        room.date != null &&
        (time.hour != room.date!.hour || time.minute != room.date!.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('확정된 약속은 날짜만 변경할 수 있습니다. 시각 변경은 지원되지 않습니다.')),
      );
      return;
    }
    try {
      await controller.saveRemoteSchedule(
        room.id,
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참가자 캘린더에 약속 날짜를 반영했습니다.')),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('약속 날짜를 변경하지 못했습니다: $error')),
        );
      }
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
        await controller.saveRemoteSchedule(roomId, null);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정을 해제하지 못했습니다: $error')),
          );
        }
      }
    }
  }

  Future<void> _editPreferences(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RoomPreferencesScreen(
          roomId: roomId,
          initialDate: controller.room(roomId).date,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    try {
      await controller.syncRoom(roomId);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('방 상태를 갱신하지 못했습니다: $error')));
      }
    }
  }

  Future<void> _generateAi(BuildContext context) async {
    if (!_generatingRooms.add(roomId)) return;
    try {
      await controller.generateRecommendation(roomId);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => AiResultScreen(
              roomId: roomId, controller: controller, onConfirmed: onConfirmed)));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI 추천에 실패했습니다: $error')));
      }
    } finally {
      _generatingRooms.remove(roomId);
    }
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
          actions: [
            IconButton(
              tooltip: '방 정보 새로고침',
              onPressed: () async {
                try {
                  await controller.syncRoom(roomId);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('새로고침에 실패했습니다: $error')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
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
                      if (room.date != null && room.status != RoomStatus.confirmed)
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
                          '실제 초대 코드입니다. 친구에게 전달하면 같은 방에 참여할 수 있습니다.',
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
                                      content: Text('초대 코드를 복사했어요.'),
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
                  const SizedBox(height: 24),
                  RoomAction(
                    label: '내 약속 조건 입력·수정',
                    icon: Icons.edit_note_outlined,
                    onPressed: () => _editPreferences(context),
                  ),
                  const SizedBox(height: 10),
                  RoomAction(
                    label: '변경 제안·투표 보기',
                    icon: Icons.how_to_vote_outlined,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RoomVotesScreen(roomId: roomId),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RoomAction(
                    label: 'AI 추천 생성·새로고침',
                    icon: Icons.auto_awesome_outlined,
                    onPressed: () => _generateAi(context),
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
                  else
                    const Text(
                      '참가자들의 조건을 입력한 뒤 AI 추천을 생성할 수 있습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: roomMuted, fontSize: 12),
                    ),
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
