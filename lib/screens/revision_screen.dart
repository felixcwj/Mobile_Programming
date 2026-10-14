import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/meeting.dart';
import '../widgets/ui.dart';

class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key, required this.meeting});
  final Meeting meeting;
  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final requestController = TextEditingController(text: '친구 한 명이 7시부터 가능해요.');
  bool showExample = false;

  @override
  void dispose() {
    requestController.dispose();
    super.dispose();
  }

  void next() {
    if (!showExample) {
      if (requestController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정 요청을 입력해 주세요.')));
        return;
      }
      setState(() => showExample = true);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('일정 수정')),
        body: Column(children: [
          Expanded(child: PageWidth(child: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 27), children: [
            const PageHeader(eyebrow: 'STEP 04 / REVISE', title: '바꾸고 싶은 점이 있나요?', subtitle: '변경된 조건을 문장으로 입력해 보세요.'),
            const SizedBox(height: 28),
            const FieldTitle('일정 변경 요청'),
            TextField(controller: requestController, maxLines: 5, maxLength: 150, decoration: const InputDecoration(hintText: '예: 친구가 7시부터 참석할 수 있어요.')),
            const SizedBox(height: 9),
            const DemoNotice('이 버전은 문장을 분석하지 않습니다. 버튼을 누르면 19시 시작으로 조정하는 고정 예시를 보여줍니다.'),
            if (showExample) ...[
              const SizedBox(height: 29),
              const SectionTitle('수정된 일정 미리보기'),
              const SizedBox(height: 13),
              Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success),
                  SizedBox(width: 9),
                  Text('시연용 조정 결과', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.dark)),
                ]),
                const SizedBox(height: 16),
                const Text('19:00에 시작하는 코스로 변경', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 8),
                const Text('기존에 선택한 활동을 90분 간격으로 다시 배치합니다.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 16),
                const TinyLabel('실제 AI 분석 아님'),
              ])),
            ],
          ]))),
          BottomAction(
            label: showExample ? '수정된 일정 확인하기' : '일정 다시 추천받기 · 데모',
            icon: showExample ? Icons.check_rounded : Icons.auto_awesome_rounded,
            onPressed: next,
          ),
        ]),
      );
}
