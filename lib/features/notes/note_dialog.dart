import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/notes/composer/note_composer.dart';

/// Modal note editor. Thin wrapper over the shared [NoteComposer].
class NoteDialog extends StatelessWidget {
  const NoteDialog({
    super.key,
    required this.state,
    this.existingNote,
    this.initialProjectId,
    this.initialTag,
  });

  final AppState state;
  final Note? existingNote;
  final String? initialProjectId;
  final String? initialTag;

  @override
  Widget build(BuildContext context) => NoteComposer(
    key: ValueKey(existingNote?.id ?? 'new'),
    state: state,
    existingNote: existingNote,
    initialProjectId: initialProjectId,
    initialTag: initialTag,
    dialogMode: true,
    onClose: () => state.modal = null,
  );
}
