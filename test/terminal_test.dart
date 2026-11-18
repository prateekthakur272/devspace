import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/terminal/ansi_parser.dart';
import 'package:devspace/core/terminal/terminal_controller.dart';
import 'package:devspace/core/terminal/terminal_session.dart';
import 'package:devspace/core/terminal/terminal_suggestions.dart';
import 'package:devspace/features/terminal/terminal_panel.dart';
import 'package:devspace/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnsiParser Tests', () {
    test('parses plain text into styled spans', () {
      const input = 'Hello World';
      final spans = AnsiParser.parse(input, DarkPal);
      expect(spans, isNotEmpty);
      expect(spans.map((s) => s.text ?? '').join(), equals(input));
    });

    test('parses standard 16-color ANSI codes', () {
      const redText = '\x1B[31mRed Alert\x1B[0m';
      final spans = AnsiParser.parse(redText, DarkPal);
      expect(spans, isNotEmpty);
      final redSpan = spans.firstWhere((s) => (s.text ?? '').contains('Red Alert'));
      expect(redSpan.style?.color, equals(DarkPal.err));
    });

    test('parses 256-color ANSI codes (38;5;N)', () {
      const code256 = '\x1B[38;5;196mBright Red\x1B[0m';
      final spans = AnsiParser.parse(code256, DarkPal);
      expect(spans, isNotEmpty);
      final match = spans.firstWhere((s) => (s.text ?? '').contains('Bright Red'));
      expect(match.style?.color, isNotNull);
    });

    test('parses 24-bit TrueColor RGB codes (38;2;R;G;B)', () {
      const trueColor = '\x1B[38;2;120;220;90mCustom Green\x1B[0m';
      final spans = AnsiParser.parse(trueColor, DarkPal);
      expect(spans, isNotEmpty);
      final match = spans.firstWhere((s) => (s.text ?? '').contains('Custom Green'));
      expect(match.style?.color, equals(const Color.fromRGBO(120, 220, 90, 1.0)));
    });

    test('parses text styles (bold, italic, underline)', () {
      const styled = '\x1B[1mBold\x1B[0m \x1B[3mItalic\x1B[0m \x1B[4mUnderline\x1B[0m';
      final spans = AnsiParser.parse(styled, DarkPal);
      expect(spans, isNotEmpty);

      final boldSpan = spans.firstWhere((s) => (s.text ?? '').contains('Bold'));
      expect(boldSpan.style?.fontWeight, equals(FontWeight.bold));

      final italicSpan = spans.firstWhere((s) => (s.text ?? '').contains('Italic'));
      expect(italicSpan.style?.fontStyle, equals(FontStyle.italic));

      final underlineSpan = spans.firstWhere((s) => (s.text ?? '').contains('Underline'));
      expect(underlineSpan.style?.decoration, equals(TextDecoration.underline));
    });

    test('colorizes diff insertions, deletions, and hunk headers in plain output', () {
      final addedSpans = AnsiParser.parse('+added line', DarkPal);
      expect(addedSpans.first.style?.color, equals(DarkPal.ok));

      final removedSpans = AnsiParser.parse('-removed line', DarkPal);
      expect(removedSpans.first.style?.color, equals(DarkPal.err));

      final hunkSpans = AnsiParser.parse('@@ -1,5 +1,6 @@', DarkPal);
      expect(hunkSpans.first.style?.color, equals(const Color(0xFF38BDF8)));
    });
  });

  group('TerminalSuggestionsEngine Tests', () {
    test('suggests git commands when input starts with git', () {
      final suggestions = TerminalSuggestionsEngine.getSuggestions(
        query: 'git c',
        cwd: io.Directory.current.path,
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.command.startsWith('git commit')), isTrue);
      expect(suggestions.any((s) => s.command.startsWith('git checkout')), isTrue);
    });

    test('suggests common developer commands on partial match', () {
      final suggestions = TerminalSuggestionsEngine.getSuggestions(
        query: 'flu',
        cwd: io.Directory.current.path,
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.command.startsWith('flutter')), isTrue);
    });

    test('returns history suggestions when matching query', () {
      final suggestions = TerminalSuggestionsEngine.getSuggestions(
        query: 'docker',
        cwd: io.Directory.current.path,
        history: ['docker compose up -d', 'npm start'],
      );
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.command == 'docker compose up -d'), isTrue);
    });
  });

  group('TerminalSession & Controller Tests', () {
    test('TerminalSession starts and handles command lifecycle', () async {
      final session = TerminalSession(
        id: 'test_session_1',
        initialCwd: io.Directory.current.path,
        title: 'Test Session',
      );

      expect(session.id, equals('test_session_1'));
      expect(session.title, equals('Test Session'));
      expect(session.lines, isNotEmpty);

      await session.execute('pwd');
      expect(session.lines.any((l) => l.text.contains(session.cwd)), isTrue);

      session.dispose();
    });

    test('TerminalController manages multiple tabs and active session', () {
      final controller = TerminalController(defaultCwd: '/tmp');
      expect(controller.sessions, isNotEmpty);

      final s1 = controller.createSession(cwd: '/tmp', title: 'Tab 1');
      expect(controller.sessions.contains(s1), isTrue);
      expect(controller.activeSession, equals(s1));

      final s2 = controller.createSession(cwd: '/tmp', title: 'Tab 2');
      expect(controller.sessions.contains(s2), isTrue);
      expect(controller.activeSession, equals(s2));

      controller.selectSession(controller.sessions.indexOf(s1));
      expect(controller.activeSession, equals(s1));

      controller.closeSession(s1.id);
      expect(controller.sessions.contains(s1), isFalse);

      controller.dispose();
    });

    test('each openDirectory click starts a new terminal session (multiple sessions)', () {
      final controller = TerminalController();
      expect(controller.sessions, isEmpty);

      // 1. First open click
      final s1 = controller.openDirectory('/tmp/project-alpha', title: 'project-alpha');
      expect(controller.sessions.length, equals(1));
      expect(controller.activeSession, equals(s1));
      expect(s1.title, equals('project-alpha'));

      // 2. Second open click on different project
      final s2 = controller.openDirectory('/tmp/project-beta', title: 'project-beta');
      expect(controller.sessions.length, equals(2));
      expect(controller.activeSession, equals(s2));
      expect(s2.title, equals('project-beta'));

      // 3. Third open click on same project again -> opens another new session
      final s3 = controller.openDirectory('/tmp/project-alpha', title: 'project-alpha (2)');
      expect(controller.sessions.length, equals(3));
      expect(controller.activeSession, equals(s3));
      expect(controller.sessions.map((s) => s.id).toSet().length, equals(3));

      controller.dispose();
    });

    test('closing last terminal session closes terminal window in AppState', () {
      final state = AppState();
      state.openIntegratedTerminal('/tmp/a', title: 'Session A');
      state.openIntegratedTerminal('/tmp/b', title: 'Session B');
      expect(state.uiState.terminalVisible, isTrue);
      expect(state.terminalController.sessions.length, equals(2));

      final idB = state.terminalController.sessions.last.id;
      final idA = state.terminalController.sessions.first.id;
      state.terminalController.closeSession(idB);
      expect(state.terminalController.sessions.length, equals(1));
      expect(state.uiState.terminalVisible, isTrue);

      state.terminalController.closeSession(idA);
      expect(state.terminalController.sessions.isEmpty, isTrue);
      expect(state.uiState.terminalVisible, isFalse);

      state.dispose();
    });

    test('typing exit in session closes session and closes window when last', () async {
      final state = AppState();
      state.openIntegratedTerminal('/tmp/single', title: 'Single Tab');
      expect(state.uiState.terminalVisible, isTrue);
      expect(state.terminalController.sessions.length, equals(1));

      await state.terminalController.activeSession.execute('exit');
      expect(state.terminalController.sessions.isEmpty, isTrue);
      expect(state.uiState.terminalVisible, isFalse);

      state.dispose();
    });
  });

  group('TerminalPanel Widget Tests', () {
    testWidgets('renders TerminalPanel with tab bar and prompt', (tester) async {
      final state = AppState();
      state.openIntegratedTerminal(io.Directory.current.path, title: 'DevSpace Shell');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PalScope(
              pal: DarkPal,
              child: SizedBox(
                height: 250,
                child: TerminalPanel(state: state),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalPanel), findsOneWidget);
      expect(find.text('TERMINAL'), findsOneWidget);
      expect(find.textContaining('DevSpace Shell'), findsOneWidget);

      state.dispose();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('typing in terminal input displays suggestions dropdown', (tester) async {
      final state = AppState();
      state.openIntegratedTerminal(io.Directory.current.path, title: 'Suggestions Test');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PalScope(
              pal: DarkPal,
              child: SizedBox(
                height: 300,
                child: TerminalPanel(state: state),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'git st');
      await tester.pumpAndSettle();

      expect(find.text('git status'), findsOneWidget);

      state.dispose();
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Default Terminal Setting Tests', () {
    test('DefaultTerminalType has correct labels, descriptions, and IDs', () {
      expect(DefaultTerminalType.integrated.id, equals('integrated'));
      expect(DefaultTerminalType.integrated.label, equals('Integrated Terminal'));
      expect(DefaultTerminalType.integrated.isIntegrated, isTrue);
      expect(DefaultTerminalType.integrated.isSystem, isFalse);

      expect(DefaultTerminalType.system.id, equals('system'));
      expect(DefaultTerminalType.system.label, equals('System Terminal'));
      expect(DefaultTerminalType.system.isSystem, isTrue);
      expect(DefaultTerminalType.system.isIntegrated, isFalse);

      expect(DefaultTerminalType.fromId('integrated'), equals(DefaultTerminalType.integrated));
      expect(DefaultTerminalType.fromId('system'), equals(DefaultTerminalType.system));
      expect(DefaultTerminalType.fromId('unknown'), equals(DefaultTerminalType.integrated));
    });

    test('AppSettings serializes and deserializes defaultTerminal correctly', () {
      const defaultSettings = AppSettings(defaultTerminal: DefaultTerminalType.integrated);
      expect(defaultSettings.defaultTerminal, equals(DefaultTerminalType.integrated));

      final jsonIntegrated = defaultSettings.toJson();
      expect(jsonIntegrated['defaultTerminal'], equals('integrated'));

      final restoredIntegrated = AppSettings.fromJson(jsonIntegrated);
      expect(restoredIntegrated.defaultTerminal, equals(DefaultTerminalType.integrated));

      final systemSettings = defaultSettings.copyWith(defaultTerminal: DefaultTerminalType.system);
      expect(systemSettings.defaultTerminal, equals(DefaultTerminalType.system));

      final jsonSystem = systemSettings.toJson();
      expect(jsonSystem['defaultTerminal'], equals('system'));

      final restoredSystem = AppSettings.fromJson(jsonSystem);
      expect(restoredSystem.defaultTerminal, equals(DefaultTerminalType.system));
    });

    test('AppState.openTerminal respects settings.defaultTerminal', () {
      final state = AppState();
      // Ensure starting in integrated mode
      state.updateSettings(state.settings.copyWith(defaultTerminal: DefaultTerminalType.integrated));
      state.toggleTerminal(false);

      expect(state.settings.defaultTerminal, equals(DefaultTerminalType.integrated));
      expect(state.uiState.terminalVisible, isFalse);

      state.openTerminal('/tmp', title: 'Project Terminal');
      expect(state.uiState.terminalVisible, isTrue);
      expect(state.terminalController.sessions, isNotEmpty);
      expect(state.terminalController.sessions.first.title, equals('Project Terminal'));

      state.toggleTerminal(false);
      expect(state.uiState.terminalVisible, isFalse);

      // 2. Change setting to system terminal
      state.updateSettings(state.settings.copyWith(defaultTerminal: DefaultTerminalType.system));
      expect(state.settings.defaultTerminal, equals(DefaultTerminalType.system));

      // Opening terminal with system setting should NOT show integrated panel
      state.openTerminal('/tmp', title: 'System Only');
      expect(state.uiState.terminalVisible, isFalse);

      state.dispose();
    });
  });
}
