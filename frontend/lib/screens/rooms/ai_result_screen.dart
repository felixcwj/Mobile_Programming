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
          '이 앱에서 약속을 확정해요. 약속 날짜가 정해져 있으면 앱 캘린더에 표시되며, 친구에게 공유하는 기능은 아직 준비 중이에요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('더 살펴볼게요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('약속 확정'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    if (controller.confirm(roomId)) {
      onConfirmed?.call(controller.room(roomId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('미리보기 약속을 확정했어요.')));
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
                          '코스 예시',
                          style: TextStyle(
                            color: roomOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '식사와 산책, 쉬어가는 시간을 담은 샘플 코스예요. 실제 AI 분석 결과가 아니며 장소·영업시간·비용은 아직 확인되지 않았어요.',
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
                  RoomAction(
                    label: confirmed ? '확정된 약속이에요' : '이 코스로 약속 확정',
                    icon: Icons.check,
                    onPressed:
                        !confirmed &&
                            room.allSubmitted &&
                            room.course.isNotEmpty
                        ? () => _confirm(context)
                        : null,
                  ),
                  const RoomDemoNotice(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
