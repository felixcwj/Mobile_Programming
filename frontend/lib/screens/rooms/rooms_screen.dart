import 'package:flutter/material.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import 'room_detail_screen.dart';
import 'room_widgets.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    required this.controller,
    this.onCreatePlan,
    this.onConfirmed,
  });
  final RoomsController controller;
  final VoidCallback? onCreatePlan;

  /// Called once when a room is confirmed during this local preview session.
  /// Calendar/server integration is the parent's responsibility.
  final ValueChanged<PlanRoom>? onConfirmed;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  RoomStatus? _filter;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: roomBackground,
    appBar: AppBar(
      title: const Text('내 방', style: TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: roomBackground,
      foregroundColor: roomInk,
      actions: [
        if (widget.onCreatePlan != null)
          IconButton(
            tooltip: '약속 만들기',
            onPressed: widget.onCreatePlan,
            icon: const Icon(Icons.add),
          ),
        const SizedBox(width: 12),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final rooms = widget.controller.rooms;
              final filtered =
                  rooms
                      .where(
                        (room) => _filter == null || room.status == _filter,
                      )
                      .toList()
                    ..sort((a, b) {
                      final aDate = a.date;
                      final bDate = b.date;
                      if (aDate == null) return bDate == null ? 0 : 1;
                      if (bDate == null) return -1;
                      return aDate.compareTo(bDate);
                    });
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '함께라서 더 기대되는\n우리의 다음 약속',
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: roomInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '취향을 모으고, 함께할 하루를 완성해요.',
                            style: TextStyle(color: roomMuted, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          RoomPanel(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1E9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.people_outline,
                                    color: roomOrange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    '함께 만드는 약속 ${rooms.length}개',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: roomInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _chip('전체', null),
                                ...RoomStatus.values.map(
                                  (status) => _chip(status.label, status),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                '나의 약속 방',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${filtered.length}',
                                style: const TextStyle(
                                  color: roomOrange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: RoomPanel(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 40,
                                color: roomOrange,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                rooms.isEmpty
                                    ? '아직 참여 중인 방이 없어요'
                                    : '이 상태의 약속은 아직 없어요',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '친구들과 함께할 다음 약속을 만들어 보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: roomMuted),
                              ),
                              if (widget.onCreatePlan != null) ...[
                                const SizedBox(height: 20),
                                RoomAction(
                                  label: '약속 만들기',
                                  onPressed: widget.onCreatePlan,
                                  icon: Icons.add,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _roomCard(filtered[index]),
                      ),
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

  Widget _chip(String label, RoomStatus? status) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == status,
      showCheckmark: false,
      selectedColor: const Color(0xFFFFE9DD),
      labelStyle: TextStyle(color: _filter == status ? roomOrange : roomMuted),
      side: BorderSide(
        color: _filter == status ? roomOrange : const Color(0xFFE4E2DE),
      ),
      onSelected: (_) => setState(() => _filter = status),
    ),
  );

  Widget _roomCard(PlanRoom room) => Semantics(
    button: true,
    label: '${room.title}, ${room.status.label}, 상세 보기',
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoomDetailScreen(
            roomId: room.id,
            controller: widget.controller,
            onConfirmed: widget.onConfirmed,
          ),
        ),
      ),
      child: RoomPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RoomStatusBadge(status: room.status),
                const Spacer(),
                const Icon(Icons.chevron_right, color: roomMuted, size: 22),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              room.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: roomInk,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  '◷  ${roomDate(room.date)}',
                  style: const TextStyle(color: roomMuted, fontSize: 13),
                ),
                Text(
                  '⌖  ${room.region}',
                  style: const TextStyle(color: roomMuted, fontSize: 13),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: Color(0xFFF0EEEA)),
            ),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: roomMuted),
                const SizedBox(width: 6),
                Text(
                  '${room.members.length}명',
                  style: const TextStyle(color: roomMuted, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '취향 입력 ${room.submittedCount}/${room.members.length}',
                  style: const TextStyle(
                    color: roomOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: room.members.isEmpty
                    ? 0
                    : room.submittedCount / room.members.length,
                color: roomOrange,
                backgroundColor: const Color(0xFFF4F0EC),
                minHeight: 5,
                semanticsLabel: '취향 입력 현황',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
