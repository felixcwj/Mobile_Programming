import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/l10n/generated/app_localizations.dart';
import 'package:meetsync/screens/rooms/room_conditions_screen.dart';
import 'package:meetsync/services/planit_api.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/widgets/planit_loading.dart';

class _PreferencesApi extends PlanitApi {
  _PreferencesApi({this.fail = false});
  final bool fail;

  @override
  Future<Map<String, dynamic>> myRoomPreferences(String roomId) async {
    if (fail) throw const PlanitApiException('Unavailable');
    return {
      'submitted': true,
      'preferences': {
        'available_date': '2031-03-02',
        'region': '성수',
        'start_time': '13:05',
        'end_time': '18:25',
        'budget': 35000,
        'activities': ['카페', '전시'],
        'additional_notes': '조용한 곳',
      },
    };
  }
}

class _ConditionsController extends RoomsController {
  _ConditionsController({bool fail = false})
    : super(
        rooms: [],
        api: _PreferencesApi(fail: fail),
      );

  final saving = Completer<bool>();
  final submissions = <Map<String, Object>>[];

  @override
  Future<bool> saveConditionsRemote(
    String roomId, {
    required String region,
    required DateTime date,
    required String start,
    required String end,
    required int budget,
    required List<String> activities,
    String notes = '',
  }) {
    submissions.add({
      'roomId': roomId,
      'region': region,
      'date': date,
      'start': start,
      'end': end,
      'budget': budget,
      'activities': activities,
      'notes': notes,
    });
    return saving.future;
  }
}

void main() {
  testWidgets(
    'conditions retain saved data across language changes and submit once',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _ConditionsController();
      addTearDown(controller.dispose);
      final locale = ValueNotifier(const Locale('en'));
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RoomConditionsScreen(
                        controller: controller,
                        roomId: 'r1',
                        initialDate: DateTime(2031, 1, 1),
                        initialRegion: '잠실',
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      Future<String> field(String key, {double delta = 180}) async {
        final finder = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          finder,
          delta,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('room-conditions-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        return tester.widget<TextFormField>(finder).controller!.text;
      }

      expect(await field('condition-start'), '13:05');
      expect(await field('condition-end'), '18:25');
      expect(await field('condition-region'), '성수');
      expect(await field('condition-budget'), '35000');
      expect(await field('condition-activities'), '카페, 전시');
      expect(await field('condition-notes'), '조용한 곳');

      final notes = find.byKey(const ValueKey('condition-notes'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, '걷기 편한 곳');
      locale.value = const Locale('ko');
      await tester.pumpAndSettle();
      expect(await field('condition-notes'), '걷기 편한 곳');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('condition-save'));
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      expect(find.byType(PlanitLoading), findsOneWidget);
      expect(controller.submissions, [
        {
          'roomId': 'r1',
          'region': '성수',
          'date': DateTime(2031, 3, 2),
          'start': '13:05',
          'end': '18:25',
          'budget': 35000,
          'activities': ['카페', '전시'],
          'notes': '걷기 편한 곳',
        },
      ]);
      controller.saving.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(RoomConditionsScreen), findsNothing);
      expect(find.byType(PlanitLoading), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed preference load cannot overwrite saved conditions', (
    tester,
  ) async {
    final controller = _ConditionsController(fail: true);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RoomConditionsScreen(
          controller: controller,
          roomId: 'r1',
          initialDate: DateTime(2031, 1, 1),
          initialRegion: '성수',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('condition-save')))
          .onPressed,
      isNull,
    );
    expect(controller.submissions, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
