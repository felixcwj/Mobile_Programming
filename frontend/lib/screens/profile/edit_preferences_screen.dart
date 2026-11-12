import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_repository.dart';
import 'profile_widgets.dart';

class EditPreferencesScreen extends StatefulWidget {
  const EditPreferencesScreen({
    super.key,
    required this.profile,
    required this.repository,
  });
  final UserProfile profile;
  final ProfileRepository repository;

  @override
  State<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends State<EditPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _birthDate;
  late final TextEditingController _livingArea;
  String? _gender;
  String? _mbti;
  ActivityPreference? _activity;
  int? _drinking;
  bool? _hasCar;
  bool _saving = false;

  static const _mbtis = [
    'ISTJ',
    'ISFJ',
    'INFJ',
    'INTJ',
    'ISTP',
    'ISFP',
    'INFP',
    'INTP',
    'ESTP',
    'ESFP',
    'ENFP',
    'ENTP',
    'ESTJ',
    'ESFJ',
    'ENFJ',
    'ENTJ',
    '잘 모르겠어요',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile.preferences;
    _gender = p.gender;
    _mbti = p.mbti;
    _activity = p.activityPreference;
    _drinking = p.drinkingEnjoyment;
    _hasCar = p.hasCar;
    final birth = p.birthDate;
    _birthDate = TextEditingController(
      text: birth == null
          ? ''
          : '${birth.year.toString().padLeft(4, '0')}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}',
    );
    _livingArea = TextEditingController(text: p.livingArea);
  }

  @override
  void dispose() {
    _birthDate.dispose();
    _livingArea.dispose();
    super.dispose();
  }

  DateTime? _parseBirth(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
    final parts = text.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.year < 1900 ||
        date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2] ||
        date.isAfter(today)) {
      return null;
    }
    return date;
  }

  Future<void> _save() async {
    final birthText = _birthDate.text.trim();
    if (birthText.isNotEmpty && _parseBirth(birthText) == null) {
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 확인해 주세요. (YYYY-MM-DD)')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final latest = await widget.repository.load();
      final updated = latest.copyWith(
        preferences: BasicPreferences(
          gender: _gender,
          birthDate: _parseBirth(_birthDate.text.trim()),
          mbti: _mbti,
          activityPreference: _activity,
          drinkingEnjoyment: _drinking,
          livingArea: _livingArea.text.trim(),
          hasCar: _hasCar,
        ),
      );
      await widget.repository.save(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Widget _question(String title, Widget child, {String? description}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: ProfileSection(
          title: title,
          description: description,
          child: child,
        ),
      );

  Widget _choices<T>(
    List<T> values,
    T? current,
    String Function(T) label,
    void Function(T?) select,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (value) => ChoiceChip(
            label: Text(label(value)),
            selected: current == value,
            onSelected: (selected) =>
                setState(() => select(selected ? value : null)),
          ),
        )
        .toList(),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('나의 기본 성향')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    const Text(
                      '어떤 사람인지 알려주세요',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '모든 질문은 선택 사항이에요. 약속마다 달라지는 조건은 내 방에서 정해요.',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    _question(
                      '성별은 무엇인가요?',
                      _choices(
                        ['여성', '남성', '기타', '응답하지 않음'],
                        _gender,
                        (v) => v,
                        (v) => _gender = v,
                      ),
                    ),
                    _question(
                      '언제 태어나셨나요?',
                      TextFormField(
                        key: const ValueKey('birthDate'),
                        controller: _birthDate,
                        maxLength: 10,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: '생년월일',
                          hintText: '2000-01-31',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null ||
                                value.trim().isEmpty ||
                                _parseBirth(value.trim()) != null
                            ? null
                            : '1900년부터 오늘까지의 실제 날짜를 입력해 주세요. (YYYY-MM-DD)',
                      ),
                      description: '태어난 연도와 생일로 만 나이와 생일을 확인해요.',
                    ),
                    _question(
                      'MBTI는 무엇인가요?',
                      _choices(_mbtis, _mbti, (v) => v, (v) => _mbti = v),
                    ),
                    _question(
                      '어떤 활동을 더 좋아하나요?',
                      _choices(
                        ActivityPreference.values,
                        _activity,
                        (v) => v.label,
                        (v) => _activity = v,
                      ),
                    ),
                    _question(
                      '음주를 얼마나 즐기시나요?',
                      _choices(
                        [1, 2, 3, 4, 5],
                        _drinking,
                        (v) => '$v',
                        (v) => _drinking = v,
                      ),
                      description: '1 전혀 즐기지 않아요 · 3 보통이에요 · 5 매우 즐겨요',
                    ),
                    _question(
                      '어느 동네에 살고 있나요?',
                      TextFormField(
                        key: const ValueKey('livingArea'),
                        controller: _livingArea,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: '사는 곳 위치',
                          hintText: '예: 서울 마포구 연남동',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      description: '이동을 고려할 수 있도록 시·구·동 정도만 알려주세요.',
                    ),
                    _question(
                      '차를 가지고 있나요?',
                      _choices(
                        [true, false],
                        _hasCar,
                        (v) => v ? '있어요' : '없어요',
                        (v) => _hasCar = v,
                      ),
                    ),
                    ProfileSaveButton(saving: _saving, onPressed: _save),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
