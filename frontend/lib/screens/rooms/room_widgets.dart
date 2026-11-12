import 'package:flutter/material.dart';
import '../../models/plan_room.dart';

const roomOrange = Color(0xFFEA602E);
const roomInk = Color(0xFF25282C);
const roomMuted = Color(0xFF73777D);
const roomBackground = Color(0xFFFAF9F6);

String roomDate(DateTime? date) {
  if (date == null) return '날짜 미정';
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]}) ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class RoomPanel extends StatelessWidget {
  const RoomPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFECEBE8)),
    ),
    child: child,
  );
}

class RoomStatusBadge extends StatelessWidget {
  const RoomStatusBadge({super.key, required this.status});
  final RoomStatus status;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == RoomStatus.confirmed;
    final color = confirmed ? const Color(0xFF3A8065) : roomOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RoomDemoNotice extends StatelessWidget {
  const RoomDemoNotice({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      '미리보기 · 참여자와 코스는 예시이며, 변경사항은 앱을 종료하면 초기화돼요.',
      style: TextStyle(color: roomMuted, fontSize: 12, height: 1.5),
    ),
  );
}

class RoomAction extends StatelessWidget {
  const RoomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      backgroundColor: roomOrange,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}
