import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/features/notes/composer/note_composer.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devspace_test_note_');
    AppStore.homeOverride = tempDir.path;
  });

  tearDown(() {
    AppStore.homeOverride = null;
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  behaviorTests();
  testWidgets('composer builds, toggles checklist and find without errors', (
    t,
  ) async {
    final note = Note(
      id: 'n1',
      title: 'Hello',
      content: '# Heading\n- a\n**bold** https://example.com',
      checklist: const [
        ChecklistItem(id: 'c1', text: 'one'),
        ChecklistItem(id: 'c2', text: 'two', checked: true),
      ],
      tags: const ['#x'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final appState = AppState();
    addTearDown(appState.dispose);
    for (final dialog in [false, true]) {
      await t.binding.setSurfaceSize(const Size(1000, 800));
      await t.pumpWidget(
        MaterialApp(
          home: PalScope(
            pal: DarkPal,
            child: Scaffold(
              body: SizedBox(
                width: dialog ? 900 : 380,
                child: NoteComposer(
                  state: appState,
                  existingNote: note,
                  dialogMode: dialog,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      // No raw markdown syntax is ever visible in the editor.
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('# Heading'), findsNothing);
      expect(find.textContaining('- [ ]'), findsNothing);
      final findBtn = find
          .byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Find & replace'))
          .first;
      await t.ensureVisible(findBtn);
      await t.pump();
      await t.tap(findBtn);
      await t.pump();
      await t.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Find'), 'a');
      await t.pump();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    }
  });
}

void behaviorTests() {
  testWidgets('slash popup: arrows select, Enter applies, Esc dismisses', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(body: NoteComposer(state: appState, onClose: () {})),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byType(TextField).at(1));
    await t.pump();
    await t.enterText(find.byType(TextField).at(1), '/h');
    await t.pump();
    expect(find.text('HEADING 1'), findsNothing);
    expect(find.text('Heading 1'), findsOneWidget);
    expect(find.text('Heading 2'), findsOneWidget);
    expect(find.text('TURN INTO'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.text('TURN INTO'), findsNothing);

    await t.enterText(find.byType(TextField).at(1), '/he');
    await t.pump();
    expect(find.text('TURN INTO'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.text('TURN INTO'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Heading 2'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('typing [] makes a checkbox, Enter continues, save derives data', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    var closed = false;
    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(state: appState, onClose: () => closed = true),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));

    // Focus the first body block (second TextField after the title).
    final fields = find.byType(TextField);
    await t.tap(fields.at(1));
    await t.pump();
    await t.enterText(fields.at(1), '[] ');
    await t.pump();
    expect(find.text('[] '), findsNothing); // trigger consumed, not shown
    expect(find.byIcon(Icons.check_rounded), findsNothing); // unchecked box

    await t.enterText(find.byType(TextField).at(1), 'buy milk #home');
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.pump();
    // Enter on a checklist item starts another checklist item.
    expect(find.byType(TextField).evaluate().length, greaterThanOrEqualTo(3));

    await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await t.pump();
    expect(closed, isTrue);
    final note = appState.notes.first;
    expect(note.content, startsWith('- [ ] buy milk #home'));
    expect(note.checklist.single.text, 'buy milk #home');
    expect(note.tags, ['#home']);
    appState.deleteNote(note.id);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('closing or autosaving an empty composer does not create an empty note', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    var closed = false;

    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(state: appState, onClose: () => closed = true),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));

    // Save and close via Cmd+Enter without typing anything
    await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await t.pump();

    expect(closed, isTrue);
    expect(appState.notes, isEmpty);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('seeded project composer does not create note when no user text is typed', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    var closed = false;

    // Simulate opening with an initial project ID
    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(
            state: appState,
            initialProjectId: 'proj_demo',
            onClose: () => closed = true,
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));

    // Close without adding any content
    await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await t.pump();

    expect(closed, isTrue);
    expect(appState.notes, isEmpty);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('emptying an existing note deletes it on close', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    var closed = false;

    final existing = Note(
      id: 'existing_note',
      title: 'Original Title',
      content: 'Original Content',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    appState.addNote(existing);
    expect(appState.notes.length, equals(1));

    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(
            state: appState,
            existingNote: existing,
            onClose: () => closed = true,
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));

    // Clear the title TextField
    await t.tap(find.byType(TextField).at(0));
    await t.pump();
    await t.enterText(find.byType(TextField).at(0), '');
    await t.pump();

    // Clear the body TextField
    await t.tap(find.byType(TextField).at(1));
    await t.pump();
    await t.enterText(find.byType(TextField).at(1), '');
    await t.pump();

    // Save and close
    await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await t.pump();

    expect(closed, isTrue);
    // Emptied note must be removed
    expect(appState.notes, isEmpty);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
