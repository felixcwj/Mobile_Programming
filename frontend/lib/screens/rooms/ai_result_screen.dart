import 'package:flutter/material.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import 'room_widgets.dart';

class AiResultScreen extends StatelessWidget {
  const AiResultScreen({
    super.key,
    required this.roomId,
    required this.controller,
    this.onConfirmed,
  });
  final String roomId;
  final RoomsController controller;
  final ValueChanged<PlanRoom>? onConfirmed;

  Future<void> _confirm(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 코스로 약속을 확정할까요?'),
        content: const Text(
          '이 코스로 확정하면 참가자들의 공유 캘린더에 약속이 표시됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('약속 확정'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await controller.confirmRemote(roomId);
      onConfirmed?.call(controller.room(roomId));
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약속이 확정됐습니다. 약속방에서 확인하세요.')),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('약속 확정에 실패했습니다: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final room = controller.room(roomId);
      final confirmed = room.status == RoomStatus.confirmed;
      return Scaffold(
        backgroundColor: roomBackground,
        appBar: AppBar(
          title: Text(confirmed ? '확정된 코스' : 'AI 추천 결과'),
          backgroundColor: roomBackground,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: roomOrange,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    confirmed ? '함께할 하루가 정해졌어요' : '함께 즐길 수 있는 하루',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: roomInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${room.title}\n${roomDate(room.date)} · ${room.region}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: roomMuted, height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  const RoomPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 추천 코스',
                          style: TextStyle(
                            color: roomOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'AI가 제안한 코스입니다. 방문 전 운영시간과 이동시간을 직접 확인해 주세요.',
                          style: TextStyle(color: roomMuted, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  RoomPanel(
                    child: Column(
                      children: [
                        for (var i = 0; i < room.course.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFEEE4),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: roomOrange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.course[i].time,
                                      style: const TextStyle(
                                        color: roomOrange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      room.course[i].title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      room.course[i].description,
                                      style: const TextStyle(
                                        color: roomMuted,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!confirmed) ...[
                    RoomAction(
                      label: '조건 수정·다시 추천',
                      icon: Icons.edit_outlined,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  RoomAction(
                    label: confirmed ? '확정된 약속이에요' : '이 코스로 약속 확정',
                    icon: Icons.check,
                    onPressed: !confirmed && room.course.isNotEmpty
                        ? () => _confirm(context)
                        : null,
                  ),

                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
