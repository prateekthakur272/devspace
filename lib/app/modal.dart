import 'package:devspace/core/model/models.dart';

sealed class AppModal {
  const AppModal();
}

class ModalAddProject extends AppModal {
  const ModalAddProject({this.initialWorkspaceId, this.initialPath});
  final String? initialWorkspaceId;
  final String? initialPath;
}

class ModalEditProject extends AppModal {
  const ModalEditProject(this.project);
  final Project project;
}

class ModalSettings extends AppModal {
  const ModalSettings();
}

class ModalAbout extends AppModal {
  const ModalAbout();
}

class ModalUpdateAvailable extends AppModal {
  const ModalUpdateAvailable(this.version);
  final String version;
}

class ModalGitDetails extends AppModal {
  const ModalGitDetails(this.project, this.status);
  final Project project;
  final GitRepoStatus status;
}

class ModalConfirmDelete extends AppModal {
  const ModalConfirmDelete({required this.project});
  final Project project;
}

class ModalDetectedTools extends AppModal {
  const ModalDetectedTools();
}

class ModalCreateGroup extends AppModal {
  const ModalCreateGroup();
}

class ModalEditGroup extends AppModal {
  const ModalEditGroup(this.group);
  final WorkspaceGroup group;
}

class ModalCreateNote extends AppModal {
  const ModalCreateNote({this.initialProjectId, this.initialTag});
  final String? initialProjectId;
  final String? initialTag;
}

class ModalEditNote extends AppModal {
  const ModalEditNote(this.note);
  final Note note;
}
