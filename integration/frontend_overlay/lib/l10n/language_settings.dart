import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'planit_l10n.dart';

class LanguageController extends ChangeNotifier {
  LanguageController._(this._preferences)
    : _locale = Locale(
        _preferences.getString(storageKey) == 'ko' ? 'ko' : 'en',
      );

  static const storageKey = 'planit.language';
  final SharedPreferences _preferences;
  Locale _locale;
  bool _saving = false;

  Locale get locale => _locale;
  bool get saving => _saving;

  static Future<LanguageController> load() async =>
      LanguageController._(await SharedPreferences.getInstance());

  Future<void> select(Locale locale) async {
    if (_saving || locale == _locale) return;
    if (locale != const Locale('en') && locale != const Locale('ko')) {
      throw ArgumentError.value(locale, 'locale');
    }
    final previous = _locale;
    _saving = true;
    _locale = locale;
    notifyListeners();
    try {
      if (!await _preferences.setString(storageKey, locale.languageCode)) {
        throw StateError('Language preference could not be saved');
      }
    } catch (_) {
      _locale = previous;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}

class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final LanguageController controller;

  static LanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.controller;

  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      controller != oldWidget.controller;
}

Future<void> showLanguageSettings(BuildContext context) async {
  final controller = LanguageScope.maybeOf(context);
  if (controller == null || controller.saving) return;
  final selected = await showDialog<Locale>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n(context).language),
      children: [
        for (final (code, label) in [('en', 'English'), ('ko', '한국어')])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, Locale(code)),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                if (controller.locale.languageCode == code)
                  const Icon(Icons.check),
              ],
            ),
          ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  try {
    await controller.select(selected);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n(context).languageSaveFailed)));
  }
}
