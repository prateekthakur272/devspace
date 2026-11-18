import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/composer/note_composer.dart';

/// Side-pane note editor. Thin wrapper over the shared [NoteComposer].
class NotePaneEditor extends StatelessWidget {
  const NotePaneEditor({
    super.key,
    required this.state,
    this.existingNote,
    this.initialProjectId,
    this.initialTag,
    this.initialChecklist = false,
    required this.onClose,
  });

  final AppState state;
  final Note? existingNote;
  final String? initialProjectId;
  final String? initialTag;
  final bool initialChecklist;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => NoteComposer(
    // Re-create the composer only when a different note is opened.
    key: ValueKey(existingNote?.id ?? 'new_$initialChecklist'),
    state: state,
    existingNote: existingNote,
    initialProjectId: initialProjectId,
    initialTag: initialTag,
    initialChecklist: initialChecklist,
    onClose: onClose,
  );
}
