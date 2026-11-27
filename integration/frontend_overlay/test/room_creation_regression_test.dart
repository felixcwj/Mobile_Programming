import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meetsync/l10n/generated/app_localizations.dart';
import 'package:meetsync/screens/create_room_screen.dart';
import 'package:meetsync/screens/home_screen.dart';
import 'package:meetsync/services/planit_api.dart';
import 'package:meetsync/services/rooms_controller.dart';

http.Response response(Map<String, Object?> body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

class _RoomApi extends PlanitApi {
  _RoomApi(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
  }) : super(
         baseUrlOverride: 'https://planit.example.com',
         client: MockClient(handler),
         authToken: token ?? (() async => 'test-token'),
       );

  @override
  String? get currentUserId => 'test-owner';
}

const roomName = '중앙대 AI Meeting';
final roomDate = DateTime(2031, 3, 2, 13);

http.Response roomCreated() =>
    response({'room_id': 'r1', 'invite_code': 'PLAN123'}, 201);

http.Response roomMetadata(String title) => response({
  'owner_uid': 'test-owner',
  'title': title,
  'invite_code': 'PLAN123',
  'max_members': 8,
  'members': [
    {'uid': 'test-owner', 'submitted': false},
  ],
});

Future<void> enterSchedule(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('room-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();
  final time = find.byKey(const ValueKey('room-time'));
  await tester.ensureVisible(time);
  await tester.tap(time);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();
}

Widget homeInLocale(Widget home, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> openCreation(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Add a room'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New room'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('online submission publishes the room and ignores double taps', (
    tester,
  ) async {
    const title = '중앙대학교 모임';
    final schedule = Completer<http.Response>();
    var posts = 0;
    final api = _RoomApi((request) async {
      switch (request.url.path) {
        case '/rooms':
          if (request.method == 'GET') return response({'rooms': []});
          posts++;
          expect(jsonDecode(utf8.decode(request.bodyBytes))['title'], title);
          return roomCreated();
        case '/rooms/r1/schedule':
          return schedule.future;
        case '/calendar/room-appointments':
        case '/calendar/events':
          return response({'events': []});
      }
      throw StateError('Unexpected request');
    });
    await tester.pumpWidget(
      homeInLocale(
        HomeScreen(loginId: 'preview', api: api),
        const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await openCreation(tester);
    await tester.enterText(find.byKey(const ValueKey('room-name')), title);
    await enterSchedule(tester);

    final submit = find.byKey(const ValueKey('room-create-submit'));
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(posts, 1);
    expect(find.byType(CreateRoomScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    schedule.complete(response({'schedule': {}}));
    await tester.pumpAndSettle();

    expect(find.text('Room created! 🎉'), findsOneWidget);
    expect(find.text(title), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-rooms')));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    expect(posts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeout preserves draft and repeated submit sends no second POST',
    (tester) async {
      final slowPost = Completer<http.Response>();
      var posts = 0;
      final api = _RoomApi((request) async {
        if (request.method == 'POST' && request.url.path == '/rooms') {
          posts++;
          return slowPost.future;
        }
        if (request.url.path == '/rooms') return response({'rooms': []});
        return response({'events': []});
      });
      await tester.pumpWidget(
        homeInLocale(
          HomeScreen(loginId: 'preview', api: api),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      await openCreation(tester);
      final field = find.byKey(const ValueKey('room-name'));
      await tester.enterText(field, roomName);
      await enterSchedule(tester);

      final submit = find.byKey(const ValueKey('room-create-submit'));
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not confirm whether'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, roomName);
      expect(tester.widget<IconButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(posts, 1);
      slowPost.complete(roomCreated());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('My profile'), findsOneWidget);
    },
  );

  testWidgets('English and Korean locales preserve mixed text and IME edits', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: locale,
        child: const CreateRoomScreen(),
        builder: (context, value, child) => homeInLocale(child!, value),
      ),
    );

    final field = find.byKey(const ValueKey('room-name'));
    await tester.showKeyboard(field);
    final controller = tester.widget<TextField>(field).controller!;
    const first = TextEditingValue(
      text: '중아',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    );
    tester.testTextInput.updateEditingValue(first);
    await tester.pump();
    expect(controller.value, first);

    const completed = TextEditingValue(
      text: '중앙대',
      selection: TextSelection.collapsed(offset: 3),
    );
    tester.testTextInput.updateEditingValue(completed);
    await tester.pump();
    expect(controller.text, '중앙대');
    locale.value = const Locale('ko');
    await tester.pumpAndSettle();
    expect(find.text('새 방'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(controller.value, completed);

    await tester.enterText(field, 'AI Meeting');
    expect(controller.text, 'AI Meeting');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: roomName,
        selection: TextSelection.collapsed(offset: roomName.length),
      ),
    );
    await tester.pump();
    expect(controller.text, roomName);

    final prefix = List.filled(29, '가').join();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$prefix한',
        selection: const TextSelection.collapsed(offset: 30),
        composing: const TextRange(start: 29, end: 30),
      ),
    );
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$prefix한ㄱ',
        selection: const TextSelection.collapsed(offset: 31),
        composing: const TextRange(start: 29, end: 31),
      ),
    );
    await tester.pump();
    expect(controller.value.composing, const TextRange(start: 29, end: 31));
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$prefix한글',
        selection: const TextSelection.collapsed(offset: 31),
      ),
    );
    await tester.pump();
    expect(controller.text, '$prefix한');
  });

  test(
    'definitive rejection allows retry; schedule failure keeps saved room',
    () async {
      var posts = 0;
      final controller = RoomsController(
        rooms: [],
        api: _RoomApi((request) async {
          if (request.url.path == '/rooms') {
            if (++posts == 1) return response({'detail': 'Rejected'}, 422);
            return roomCreated();
          }
          return response({'detail': 'Schedule service unavailable'}, 503);
        }),
      );
      addTearDown(controller.dispose);

      Future<RoomCreationResult> create() =>
          controller.createRemote(title: roomName, capacity: 8, date: roomDate);
      await expectLater(create(), throwsA(isA<PlanitApiException>()));
      expect(controller.rooms, isEmpty);
      final result = await create();
      expect(result.scheduleSaved, isFalse);
      expect(result.room.title, roomName);
      expect(controller.rooms.single, same(result.room));
      expect(controller.rooms.single.date, isNull);
      expect(posts, 2);
    },
  );

  test(
    'older refresh keeps the room; new login restores the Unicode name',
    () async {
      final staleAppointments = Completer<http.Response>();
      final staleStarted = Completer<void>();
      String? storedTitle;
      var appointmentReads = 0;
      final api = _RoomApi((request) async {
        switch (request.url.path) {
          case '/rooms':
            if (request.method == 'POST') {
              storedTitle =
                  jsonDecode(utf8.decode(request.bodyBytes))['title'] as String;
              return roomCreated();
            }
            return response({
              'rooms': [
                if (storedTitle != null) {'room_id': 'r1'},
              ],
            });
          case '/calendar/room-appointments':
            if (++appointmentReads == 1) {
              staleStarted.complete();
              return staleAppointments.future;
            }
            return response({
              'events': [
                {
                  'room_id': 'r1',
                  'starts_at': roomDate.toUtc().toIso8601String(),
                },
              ],
            });
          case '/rooms/r1':
            return roomMetadata(storedTitle!);
          case '/rooms/r1/recommendation':
            return response({'detail': 'No recommendation'}, 404);
        }
        return response({});
      });
      final firstSession = RoomsController(rooms: [], api: api);
      addTearDown(firstSession.dispose);
      final stale = firstSession.refresh();
      await staleStarted.future;
      final created = await firstSession.createRemote(
        title: roomName,
        capacity: 8,
        date: roomDate,
      );
      expect(created.scheduleSaved, isTrue);
      staleAppointments.complete(response({'events': []}));
      await stale;
      expect(firstSession.rooms.single.title, roomName);
      expect(firstSession.rooms.single.date, roomDate);

      final nextSession = RoomsController(rooms: [], api: api);
      addTearDown(nextSession.dispose);
      await nextSession.refresh();
      expect(nextSession.rooms.single.title, roomName);
      expect(nextSession.rooms.single.date, roomDate);
    },
  );

  test('auth deadline expires without sending room creation', () async {
    final token = Completer<String?>();
    var sent = false;
    final api = _RoomApi((_) async {
      sent = true;
      return roomCreated();
    }, token: () => token.future);
    await expectLater(
      api.createRoom(roomName, 8, timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<PlanitApiException>().having(
          (e) => e.mayHaveReachedServer,
          'mayHaveReachedServer',
          false,
        ),
      ),
    );
    token.complete('test-token');
    expect(sent, isFalse);
  });
}
