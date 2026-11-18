import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/git/git_service.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/features/dialogs/modals.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GitService.disableExecutionForTesting = true;
  });

  tearDown(() {
    GitService.disableExecutionForTesting = false;
  });

  testWidgets('Modal dialogs shrink-wrap their content and do not take full window height', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    final testProject = Project(
      id: 'p1',
      name: 'Test Project',
      path: '/dev/test',
      techStack: TechStack.flutter,
      createdAt: DateTime.now(),
    );

    // Set a standard desktop window size (1200 x 800)
    await tester.binding.setSurfaceSize(const Size(1200, 800));

    // 1. Confirm Delete Dialog (should be small, ~150-200px, not 800px)
    state.modal = ModalConfirmDelete(project: testProject);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalScope(
            pal: DarkPal,
            child: ListenableBuilder(
              listenable: state,
              builder: (ctx, _) => Stack(
                children: [
                  const SizedBox.expand(),
                  buildActiveModal(ctx, state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify dialog title and find the modal Container
    expect(find.text('Remove Project?'), findsOneWidget);

    // Find the Container that represents the dialog window
    final dialogFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final box = widget.decoration as BoxDecoration;
        return box.borderRadius == BorderRadius.circular(10);
      }
      return false;
    });
    expect(dialogFinder, findsOneWidget);

    final confirmDeleteSize = tester.getSize(dialogFinder);
    // Should hug content (~266px) and definitely NOT stretch to full height (800 - 48 = 752px)
    expect(confirmDeleteSize.height, lessThan(300.0));
    expect(confirmDeleteSize.height, greaterThan(150.0));

    // 2. Add Project Dialog (should be ~350-450px, not 800px)
    state.modal = const ModalAddProject();
    await tester.pump();

    expect(find.text('Add Project to DevSpace'), findsOneWidget);
    final addProjectSize = tester.getSize(dialogFinder);
    expect(addProjectSize.height, lessThan(520.0));
    expect(addProjectSize.height, greaterThan(250.0));

    // 3. Developer Dialog
    state.modal = const ModalDeveloper();
    await tester.pump();

    expect(find.text('Developer'), findsOneWidget);
    final developerDialogSize = tester.getSize(dialogFinder);
    expect(developerDialogSize.height, lessThan(700.0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
