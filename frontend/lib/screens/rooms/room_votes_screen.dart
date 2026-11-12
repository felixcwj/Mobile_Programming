import 'package:flutter/material.dart';

import '../../services/planit_api.dart';

class RoomVotesScreen extends StatefulWidget {
  const RoomVotesScreen({super.key, required this.roomId});
  final String roomId;

  @override
  State<RoomVotesScreen> createState() => _RoomVotesScreenState();
}

class _RoomVotesScreenState extends State<RoomVotesScreen> {
  late Future<List<_VoteItem>> _items;
  String? _submitting;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = _fetch();
  }

  Future<List<_VoteItem>> _fetch() async {
    final api = PlanitApi.instance;
    final id = Uri.encodeComponent(widget.roomId);
    final decisions = await api.request('GET', '/rooms/$id/decisions');
    final dates = await api.request('GET', '/rooms/$id/appointment/date-requests');
    final items = <_VoteItem>[];
    for (final item in decisions['decisions'] as List<dynamic>? ?? []) {
      if (item is Map<String, dynamic>) {
        items.add(_VoteItem(false, item));
      }
    }
    for (final item in dates['requests'] as List<dynamic>? ?? []) {
      if (item is Map<String, dynamic>) {
        items.add(_VoteItem(true, item));
      }
    }
    return items;
  }

  Future<void> _vote(_VoteItem item, bool approval) async {
    final id = item.id;
    if (id == null || _submitting != null) return;
    setState(() => _submitting = id);
    try {
      final roomId = Uri.encodeComponent(widget.roomId);
      final path = item.isDate
          ? '/rooms/$roomId/appointment/date-requests/${Uri.encodeComponent(id)}/vote'
          : '/rooms/$roomId/decisions/${Uri.encodeComponent(id)}/vote';
      await PlanitApi.instance.request('POST', path, body: {'approve': approval});
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('투표하지 못했습니다: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('변경 제안 및 동의')),
    body: FutureBuilder<List<_VoteItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: TextButton(
            onPressed: () => setState(_reload),
            child: Text('목록을 불러오지 못했습니다. 다시 시도\n${snapshot.error}'),
          ));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('진행 중인 변경 요청이 없습니다.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final pending = item.data['status'] == 'pending';
            final votes = item.data['votes'];
            final voteCount = votes is Map ? votes.values.where((v) => v == true).length : 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.isDate ? '약속 날짜 변경' : '조건·활동 변경',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(item.isDate
                        ? '새 날짜: ${item.data['date'] ?? '-'}'
                        : '수정 유형: ${item.data['change_type'] ?? '-'}'),
                    if ((item.data['additional_notes'] ?? '').toString().isNotEmpty)
                      Text('기타 사항: ${item.data['additional_notes']}'),
                    const SizedBox(height: 8),
                    Text('상태: ${item.data['status'] ?? '-'} · 찬성 $voteCount명'),
                    if (pending)
                      Row(
                        children: [
                          TextButton(
                            onPressed: _submitting == null ? () => _vote(item, false) : null,
                            child: const Text('거절'),
                          ),
                          FilledButton(
                            onPressed: _submitting == null ? () => _vote(item, true) : null,
                            child: const Text('동의'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _VoteItem {
  const _VoteItem(this.isDate, this.data);
  final bool isDate;
  final Map<String, dynamic> data;
  String? get id => (isDate ? data['request_id'] : data['decision_id'])?.toString();
}
