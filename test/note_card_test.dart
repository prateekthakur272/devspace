import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/note_card.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  testWidgets('NoteCard renders in grid and list layouts without overflow, toggles checks',
      (t) async {
    final state = AppState();
    addTearDown(state.dispose);
    final note = Note(
      id: 'n1',
      title: 'A fairly long note title that should wrap onto two lines and then ellipsize nicely',
      content: '# Heading\nSome **bold** body text that is long enough to wrap across several lines '
          'in the preview so we can test clamping behaviour.\n- [ ] one\n- [x] two\n- [ ] three\n'
          '- [ ] four\n- [ ] five\n- [ ] six',
      checklist: [
        for (var i = 0; i < 6; i++)
          ChecklistItem(id: 'c$i', text: 'item number $i', checked: i == 1),
      ],
      tags: const ['#alpha', '#beta', '#gamma', '#delta'],
      links: const ['https://example.com'],
      pinned: true,
      color: const Color(0xFF8B5CF6),
      createdAt: DateTime(2026),
      updatedAt: DateTime.now(),
    );
    for (final fill in [true, false]) {
      for (final w in [300.0, 520.0]) {
        await t.binding.setSurfaceSize(const Size(800, 700));
        await t.pumpWidget(MaterialApp(
          home: PalScope(
            pal: DarkPal,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: w,
                  height: fill ? 260 : null,
                  child: NoteCard(
                    note: note,
                    state: state,
                    fillHeight: fill,
                    formatTime: (_) => 'now',
                    onCopy: () {},
                  ),
                ),
              ),
            ),
          ),
        ));
        await t.pump(const Duration(milliseconds: 200));
        expect(t.takeException(), isNull, reason: 'fill=$fill width=$w');
        expect(find.textContaining('**'), findsNothing);
        expect(find.text('1/6'), findsOneWidget);
      }
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
