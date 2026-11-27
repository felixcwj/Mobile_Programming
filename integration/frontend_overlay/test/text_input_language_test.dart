import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/l10n/generated/app_localizations.dart';
import 'package:meetsync/models/user_profile.dart';
import 'package:meetsync/screens/calendar/calendar_screen.dart';
import 'package:meetsync/screens/calendar/event_editor_sheet.dart';
import 'package:meetsync/screens/profile/edit_profile_screen.dart';
import 'package:meetsync/screens/profile/profile_widgets.dart';
import 'package:meetsync/screens/rooms/room_preference_editor.dart';
import 'package:meetsync/services/calendar_controller.dart';
import 'package:meetsync/services/profile_repository.dart';
import 'package:meetsync/services/rooms_controller.dart';

Widget localized(Widget home, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('mixed nickname is saved and reopened under either UI locale', (
    tester,
  ) async {
    final profile = UserProfile(
      userId: 'test-user',
      nickname: '플래너',
      email: 'planner@example.com',
    );
    final repository = MemoryProfileRepository(initialProfile: profile);

    Future<void> openEditor(Locale locale) async {
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final latest = await repository.load();
                  if (!context.mounted) return;
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        profile: latest,
                        repository: repository,
                      ),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
    }

    await openEditor(const Locale('en'));
    final nickname = find.byKey(const ValueKey('nickname'));
    await tester.ensureVisible(nickname);
    await tester.enterText(nickname, '중앙대 AI');
    FocusManager.instance.primaryFocus?.unfocus();
    final save = find.byType(ProfileSaveButton);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect((await repository.load()).nickname, '중앙대 AI');

    await openEditor(const Locale('ko'));
    expect(tester.widget<TextFormField>(nickname).controller!.text, '중앙대 AI');
  });

  testWidgets('mixed event title, location and memo are saved and searchable', (
    tester,
  ) async {
    final rooms = RoomsController(rooms: []);
    final calendar = CalendarController(roomsController: rooms);
    addTearDown(rooms.dispose);
    addTearDown(calendar.dispose);
    final day = DateTime(2030, 3, 4);
    await tester.pumpWidget(
      localized(CalendarScreen(controller: calendar, initialDate: day)),
    );

    await tester.tap(find.byKey(const ValueKey('add-calendar-event')));
    await tester.pumpAndSettle();
    final editor = find.byType(EventEditorSheet);
    expect(editor, findsOneWidget);
    final values = <String, String>{
      'event-title': '중앙대 AI Meeting',
      'event-location': '서울 Conference Hall',
      'event-notes': '회의 자료 공유 Notes',
    };
    for (final entry in values.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    final save = find.byKey(const ValueKey('save-event'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final event = calendar.events.single;
    expect(event.title, values['event-title']);
    expect(event.location, values['event-location']);
    expect(event.notes, values['event-notes']);
    await tester.tap(find.byTooltip('Search events'));
    await tester.pumpAndSettle();

    for (final query in ['중앙대 AI', '서울 Conference', '자료 공유 Notes']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(find.text(event.title), findsOneWidget);
    }
  });

  testWidgets('a model refresh does not overwrite active Korean composition', (
    tester,
  ) async {
    final model = ValueNotifier<String>('카페');
    addTearDown(model.dispose);
    String? saved;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder(
            valueListenable: model,
            builder: (context, value, _) => RoomPreferenceEditor(
              initialText: value,
              onSave: (value) => saved = value,
            ),
          ),
        ),
      ),
    );
    final field = find.byKey(const ValueKey('room-preference'));
    await tester.showKeyboard(field);
    const composing = TextEditingValue(
      text: '카페',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    model.value = '새 서버 값';
    await tester.pump();
    expect(tester.widget<TextFormField>(field).controller!.value, composing);

    await tester.enterText(field, '카페 Tour');
    await tester.tap(find.byKey(const ValueKey('save-room-preference')));
    await tester.pumpAndSettle();
    expect(saved, '카페 Tour');
  });
}
