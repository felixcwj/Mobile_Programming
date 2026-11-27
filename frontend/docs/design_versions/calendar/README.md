# Calendar design versions

## ver1

Saved on 2026-11-17 (Asia/Seoul), when the user designated the current calendar as ver1.
The original files are in `ver1.zip`; paths are relative to the project root.
`manifest.json` records the base commit and SHA-256 of each saved file.
Keep this baseline immutable.

When the user asks to restore ver1, restore the calendar design from this archive.
Primary UI files:

- `lib/screens/calendar/calendar_screen.dart`
- `lib/screens/calendar/event_editor_sheet.dart`

The model, controller, calendar tests, integration documentation, `lib/main.dart`,
and `pubspec.yaml` are included as dependency and integration context.
Review current changes and restore only the necessary calendar design and dependencies,
preserving subsequent features and unrelated screen changes.
Do not extract the entire archive over the project indiscriminately.
