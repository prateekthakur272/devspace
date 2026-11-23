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
  testWidgets('opening a note sinks already-checked items to the end', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    final note = Note(
      id: 'mix',
      title: 'Mixed',
      content: '- [x] done early\n- [ ] open one\n  - [x] sub done\n  - [ ] sub open\n- [ ] open two',
      checklist: const [
        ChecklistItem(id: 'a', text: 'done early', checked: true),
        ChecklistItem(id: 'b', text: 'open one'),
        ChecklistItem(id: 'c', text: 'sub done', checked: true),
        ChecklistItem(id: 'd', text: 'sub open'),
        ChecklistItem(id: 'e', text: 'open two'),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(state: appState, existingNote: note, onClose: () {}),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    final texts = [
      for (final w in t.widgetList<TextField>(find.byType(TextField)).skip(1))
        (w.controller as TextEditingController).text,
    ];
    expect(texts, ['open one', 'sub open', 'sub done', 'open two', 'done early']);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('ticking a checkbox moves the item to the end of the list', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);
    final note = Note(
      id: 'chk',
      title: 'List',
      content: '- [ ] one\n- [ ] two\n- [ ] three',
      checklist: const [
        ChecklistItem(id: 'a', text: 'one'),
        ChecklistItem(id: 'b', text: 'two'),
        ChecklistItem(id: 'c', text: 'three'),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(state: appState, existingNote: note, onClose: () {}),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));

    // Tick "one": it should drop below "two" and "three".
    final boxes = find.byType(AnimatedContainer);
    expect(boxes, findsWidgets);
    String order() => [
          for (final w in t.widgetList<TextField>(find.byType(TextField)).skip(1))
            (w.controller as TextEditingController).text,
        ].join(',');
    expect(order(), 'one,two,three');
    await t.tapAt(t.getCenter(find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.constraints?.maxWidth == 17,
    ).first));
    await t.pump(const Duration(milliseconds: 200));
    expect(order(), 'two,three,one');

    // Un-tick it again: it returns above the completed items (none left).
    await t.tapAt(t.getCenter(find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.constraints?.maxWidth == 17,
    ).last));
    await t.pump(const Duration(milliseconds: 200));
    expect(order(), 'two,three,one');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

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

  testWidgets('cursor remains visible and stable while editing checklists and mentions', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 800));
    final appState = AppState();
    addTearDown(appState.dispose);

    final note = Note(
      id: 'n_cursor_test',
      title: 'Checklist & Mentions',
      content: '- [ ] First task @DevSpace\n- [x] Done task\nPlain text',
      checklist: const [
        ChecklistItem(id: 'c1', text: 'First task @DevSpace'),
        ChecklistItem(id: 'c2', text: 'Done task', checked: true),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await t.pumpWidget(MaterialApp(
      home: PalScope(
        pal: DarkPal,
        child: Scaffold(
          body: NoteComposer(
            state: appState,
            existingNote: note,
            onClose: () {},
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));

    // Verify all body text fields have high-contrast cursor color matching pal.text
    final textFields = t.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields.length, greaterThanOrEqualTo(3)); // title + 2 todos + paragraph
    for (final tf in textFields) {
      expect(tf.cursorColor, equals(DarkPal.text));
      expect(tf.cursorWidth, equals(2.0));
      expect(tf.cursorOpacityAnimates, isTrue);
    }

    // Tap on the checklist item with the mention
    final firstTodoField = find.byType(TextField).at(1);
    await t.tap(firstTodoField);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    // Ensure the target CompositedTransformTarget does not disappear or unmount
    expect(find.byType(CompositedTransformTarget), findsWidgets);

    // Edit text inside the checklist item
    await t.enterText(firstTodoField, 'Updated task @DevSpace now');
    await t.pump();

    final updatedFields = t.widgetList<TextField>(find.byType(TextField)).toList();
    expect(updatedFields[1].cursorColor, equals(DarkPal.text));

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
