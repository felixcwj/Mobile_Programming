import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/meeting.dart';
import '../widgets/ui.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});
  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final nameController = TextEditingController();
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  int people = 4;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: '약속 날짜 선택',
    );
    if (newDate != null && mounted) setState(() => selectedDate = newDate);
  }

  void submit() {
    final title = nameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('약속 이름을 입력해 주세요.')));
      return;
    }
    Navigator.of(context).pop(Meeting(name: title, date: selectedDate, people: people));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('새 약속 만들기')),
        body: Column(children: [
          Expanded(child: PageWidth(child: ListView(padding: const EdgeInsets.fromLTRB(22, 15, 22, 28), children: [
            const PageHeader(eyebrow: 'STEP 01 / NEW MEETING', title: '어떤 약속을 만들까요?', subtitle: '약속의 기본 정보부터 알려주세요.'),
            const SizedBox(height: 29),
            const FieldTitle('약속 이름'),
            TextField(controller: nameController, maxLength: 30, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: '예: 금요일 친구 모임', prefixIcon: Icon(Icons.edit_note_rounded))),
            const SizedBox(height: 14),
            const FieldTitle('약속 날짜'),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: ListTile(
                onTap: chooseDate,
                contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
                leading: const Icon(Icons.event_rounded, color: AppColors.primary),
                title: Text('${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일', style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 25),
            const FieldTitle('참여 인원'),
            Surface(child: Row(children: [
              const IconTile(Icons.people_alt_outlined),
              const SizedBox(width: 13),
              const Expanded(child: Text('함께하는 사람', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark))),
              IconButton(tooltip: '인원 줄이기', onPressed: people > 2 ? () => setState(() => people--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
              Text('$people명', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.dark)),
              IconButton(tooltip: '인원 늘리기', onPressed: people < 20 ? () => setState(() => people++) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
            ])),
            const SizedBox(height: 17),
            const DemoNotice('초대 링크 및 참여자 초대는 이후 개발 단계에서 연결할 예정입니다.'),
          ]))),
          BottomAction(label: '약속 만들고 조건 설정하기', onPressed: submit),
        ]),
      );
}
