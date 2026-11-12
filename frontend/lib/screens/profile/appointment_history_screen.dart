import 'package:flutter/material.dart';

import '../../services/planit_api.dart';
import 'profile_widgets.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  State<AppointmentHistoryScreen> createState() => _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = PlanitApi.instance.request('GET', '/mypage/appointments')
        .then((result) => (result['appointments'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>().toList());
  }

  @override
  Widget build(BuildContext context) => ProfilePageScaffold(
    title: '약속 내역',
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(_reload),
              child: Text('목록을 불러오지 못했습니다: ${snapshot.error}\n다시 시도'),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('아직 약속 없음',
              style: TextStyle(color: profileInk, fontSize: 18)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final item = items[index];
            final start = DateTime.tryParse(item['starts_at']?.toString() ?? '')?.toLocal();
            final dateText = start == null
                ? (item['date']?.toString() ?? '날짜 미정')
                : '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
            final left = item['status'] == 'left';
            return ListTile(
              leading: const Icon(Icons.event_available_outlined, color: profileBlue),
              title: Text(item['title']?.toString() ?? '약속'),
              subtitle: Text('$dateText · ${left ? '참여 종료' : '참여 중'}'),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        );
      },
    ),
  );
}
