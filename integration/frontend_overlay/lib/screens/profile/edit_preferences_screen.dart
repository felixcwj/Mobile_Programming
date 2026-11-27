import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/planit_l10n.dart';
import '../../models/user_profile.dart';
import '../../services/profile_repository.dart';
import 'profile_widgets.dart';
import '../../widgets/numeric_date_time_formatter.dart';

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
        SnackBar(content: Text(l10n(context).checkYourDateOfBirthYyyyMm)),
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
        SnackBar(
          content: Text(l10n(context).couldNotSavePleaseTryAgainShortly),
        ),
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
      appBar: AppBar(title: Text(l10n(context).myPreferences)),
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
                    Text(
                      l10n(context).tellUsAboutYourself,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n(context).allQuestionsAreOptionalSetPlanSpecific,
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    _question(
                      l10n(context).whatIsYourGender,
                      _choices(
                        ['여성', '남성', '기타', '응답하지 않음'],
                        _gender,
                        (v) => displayLabel(context, v),
                        (v) => _gender = v,
                      ),
                    ),
                    _question(
                      l10n(context).whenWereYouBorn,
                      TextFormField(
                        key: const ValueKey('birthDate'),
                        controller: _birthDate,
                        inputFormatters: const [NumericDateTimeFormatter.date()],
                        maxLength: 10,
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          labelText: l10n(context).dateOfBirth,
                          hintText: '2000-01-31',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null ||
                                value.trim().isEmpty ||
                                _parseBirth(value.trim()) != null
                            ? null
                            : l10n(context).enterAValidDateFromThroughToday,
                      ),
                      description: l10n(context).weUseYourBirthDateToDetermine,
                    ),
                    _question(
                      l10n(context).whatIsYourMbtiType,
                      _choices(
                        _mbtis,
                        _mbti,
                        (v) => displayLabel(context, v),
                        (v) => _mbti = v,
                      ),
                    ),
                    _question(
                      l10n(context).whichActivitiesDoYouPrefer,
                      _choices(
                        ActivityPreference.values,
                        _activity,
                        (v) => displayLabel(context, v.label),
                        (v) => _activity = v,
                      ),
                    ),
                    _question(
                      l10n(context).howMuchDoYouEnjoyDrinking,
                      _choices(
                        [1, 2, 3, 4, 5],
                        _drinking,
                        (v) => '$v',
                        (v) => _drinking = v,
                      ),
                      description: l10n(context).notAtAllNeutralVeryMuch,
                    ),
                    _question(
                      l10n(context).whatNeighborhoodDoYouLiveIn,
                      TextFormField(
                        key: const ValueKey('livingArea'),
                        controller: _livingArea,
                        maxLength: 60,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                        decoration: InputDecoration(
                          labelText: l10n(context).neighborhood,
                          hintText: l10n(context).eGYeonnamDongMapoGuSeoul,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      description: l10n(
                        context,
                      ).enterYourCityDistrictOrNeighborhoodSo,
                    ),
                    _question(
                      l10n(context).doYouHaveACar,
                      _choices(
                        [true, false],
                        _hasCar,
                        (v) => v ? l10n(context).yes : l10n(context).no,
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
