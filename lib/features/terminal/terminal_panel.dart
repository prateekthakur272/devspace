import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/drag_devices.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/terminal/ansi_parser.dart';
import 'package:devspace/core/terminal/terminal_controller.dart';
import 'package:devspace/core/terminal/terminal_session.dart';
import 'package:devspace/core/terminal/terminal_suggestions.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

/// VS Code-style integrated terminal panel with tabbed sessions,
/// ANSI color formatting, real-time command suggestions, and quick actions.
class TerminalPanel extends StatefulWidget {
  const TerminalPanel({
    super.key,
    required this.state,
    this.onToggleMaximize,
    this.isMaximized = false,
  });

  final AppState state;
  final VoidCallback? onToggleMaximize;
  final bool isMaximized;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final TextEditingController _cmdCtrl = TextEditingController();
  final FocusNode _cmdFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  bool _userScrolledUp = false;
  List<TerminalSuggestion> _activeSuggestions = [];
  int _selectedSuggestionIndex = -1;
  bool _showSuggestionsPopup = false;

  TerminalController get _controller => widget.state.terminalController;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _cmdCtrl.addListener(_onInputChanged);
    _cmdFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _cmdCtrl.removeListener(_onInputChanged);
    _cmdFocus.removeListener(_onFocusChanged);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _cmdCtrl.dispose();
    _cmdFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_cmdFocus.hasFocus && _showSuggestionsPopup) {
      setState(() => _showSuggestionsPopup = false);
    }
  }

  void _onInputChanged() {
    final query = _cmdCtrl.text;
    final session = _controller.activeSession;
    final list = TerminalSuggestionsEngine.getSuggestions(
      query: query,
      cwd: session.cwd,
      history: session.history,
      limit: 7,
    );
    setState(() {
      _activeSuggestions = list;
      _showSuggestionsPopup = query.trim().isNotEmpty && list.isNotEmpty;
      if (_selectedSuggestionIndex >= list.length) {
        _selectedSuggestionIndex = -1;
      }
    });
  }

  String get _ghostSuffix {
    if (_cmdCtrl.text.isEmpty || _activeSuggestions.isEmpty) return '';
    final top = _activeSuggestions.first.command;
    if (top.toLowerCase().startsWith(_cmdCtrl.text.toLowerCase()) &&
        top.length > _cmdCtrl.text.length) {
      return top.substring(_cmdCtrl.text.length);
    }
    return '';
  }

  void _applySuggestion(TerminalSuggestion s, {bool execute = false}) {
    _cmdCtrl.text = s.command;
    _cmdCtrl.selection = TextSelection.collapsed(offset: s.command.length);
    setState(() {
      _showSuggestionsPopup = false;
      _selectedSuggestionIndex = -1;
    });
    if (execute) {
      _submitCommand();
    } else {
      _cmdFocus.requestFocus();
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.offset;
    // If user scrolled up more than 40px away from bottom, pause auto-scroll
    _userScrolledUp = (maxScroll - currentScroll) > 40;
  }

  void _scrollToBottom() {
    if (_userScrolledUp || !_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _submitCommand([String? overrideText]) {
    final text = overrideText ?? _cmdCtrl.text;
    _cmdCtrl.clear();
    _userScrolledUp = false;
    setState(() {
      _showSuggestionsPopup = false;
      _selectedSuggestionIndex = -1;
    });
    _controller.activeSession.execute(text);
    _cmdFocus.requestFocus();
    _scrollToBottom();
  }

  void _handleHistoryUp() {
    final prev = _controller.activeSession.historyPrevious();
    if (prev != null) {
      _cmdCtrl.text = prev;
      _cmdCtrl.selection = TextSelection.collapsed(offset: prev.length);
    }
  }

  void _handleHistoryDown() {
    final next = _controller.activeSession.historyNext();
    if (next != null) {
      _cmdCtrl.text = next;
      _cmdCtrl.selection = TextSelection.collapsed(offset: next.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;

    // Listen to session changes to auto-scroll on new output
    _scrollToBottom();

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.sessions.isEmpty) {
          return const SizedBox.shrink();
        }
        final currentSession = _controller.activeSession;

        return Container(
          decoration: BoxDecoration(
            color: p.dark ? const Color(0xFF14161B) : const Color(0xFFF0F2F5),
            border: Border(
              top: BorderSide(color: p.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              // 1. VS Code-Style Header Bar with Tabs & Controls
              _buildHeader(context, p),

              // 2. Terminal Output Stream
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _cmdFocus.requestFocus(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      physics: const ClampingScrollPhysics(),
                      child: SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final line in currentSession.lines)
                              _buildTerminalLine(line, p),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Interactive Bottom CLI Prompt Bar with Suggestions
              _buildPrompt(context, p, currentSession),
            ],
          ),
        );
      },
    );
  }

  /// Top VS Code-style tabs header with session controls.
  Widget _buildHeader(BuildContext context, Pal p) {
    final sessions = _controller.sessions;
    final activeIndex = _controller.activeIndex;
    final current = _controller.activeSession;

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.sidebar,
        border: Border(
          bottom: BorderSide(color: p.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Section Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.terminal, size: 14, color: p.accent),
              const SizedBox(width: 6),
              const T('TERMINAL', size: 11, weight: FontWeight.w700),
            ],
          ),
          const SizedBox(width: 14),

          // Session Tabs (like VS Code)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < sessions.length; i++) ...[
                    _buildTab(sessions[i], i == activeIndex, i, p),
                    const SizedBox(width: 4),
                  ],
                  // New Tab (+) Button
                  IconBtn(
                    icon: AppIcons.add,
                    size: 24,
                    iconSize: 13,
                    tooltip: 'New Terminal Session',
                    onClick: () => _controller.createSession(
                      cwd: current.cwd,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Working Directory Badge
          Tooltip(
            message: 'Working Directory: ${current.cwd}\nClick to reveal in Finder/Explorer',
            child: ClickableNoRipple(
              onClick: () => Platform.reveal(current.cwd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.folder, size: 11, color: p.muted),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: T(
                        current.displayCwd,
                        size: 11,
                        color: p.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Stop / Terminate Process
          if (current.isExecuting) ...[
            IconBtn(
              icon: Icons.stop_rounded,
              size: 24,
              iconSize: 14,
              color: p.err,
              tooltip: 'Terminate Process (^C)',
              onClick: () => current.kill(),
            ),
            const SizedBox(width: 4),
          ],

          // Clear Output
          IconBtn(
            icon: Icons.delete_sweep_rounded,
            size: 24,
            iconSize: 14,
            tooltip: 'Clear Output (⌘K / Ctrl+L)',
            onClick: () => current.clear(),
          ),

          // Open in System Terminal
          IconBtn(
            icon: Icons.open_in_new_rounded,
            size: 24,
            iconSize: 13,
            tooltip: 'Open in System Terminal',
            onClick: () => Platform.openInTerminal(current.cwd),
          ),

          // Maximize / Restore Toggle
          if (widget.onToggleMaximize != null)
            IconBtn(
              icon: widget.isMaximized
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: 24,
              iconSize: 14,
              tooltip: widget.isMaximized ? 'Restore Size' : 'Maximize Panel',
              onClick: widget.onToggleMaximize,
            ),

          // Close Panel (Cmd + `)
          IconBtn(
            icon: AppIcons.close,
            size: 24,
            iconSize: 13,
            tooltip: 'Close Terminal Panel (${Platform.isMac ? "⌘`" : "Ctrl+`"})',
            onClick: () => widget.state.toggleTerminal(),
          ),
        ],
      ),
    );
  }

  /// Individual Session Tab (e.g. `1: devspace`, `2: server`).
  Widget _buildTab(TerminalSession session, bool isActive, int index, Pal p) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () => _controller.selectSession(index),
      builder: (context, hovered) {
        return Container(
          height: 25,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (p.dark ? const Color(0xFF232730) : const Color(0xFFFFFFFF))
                : (hovered ? p.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? p.accent.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Running dot indicator
              if (session.isExecuting) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: p.ok,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              T(
                '${index + 1}: ${session.title}',
                size: 11,
                weight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? p.text : p.muted,
              ),
              const SizedBox(width: 4),
              IconBtn(
                icon: AppIcons.close,
                size: 18,
                iconSize: 10,
                color: p.muted,
                tooltip: 'Close Session',
                onClick: () => _controller.closeSession(session.id),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders a single terminal output line with rich color formatting.
  Widget _buildTerminalLine(TerminalLine line, Pal p) {
    switch (line.type) {
      case TerminalLineType.prompt:
        return _buildPromptLine(line, p);

      case TerminalLineType.system:
        return _buildSystemLine(line, p);

      case TerminalLineType.error:
        return _buildErrorLine(line, p);

      case TerminalLineType.stderr:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 0.5),
          padding: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: p.err.withOpacity(0.4), width: 2)),
          ),
          child: Text.rich(
            TextSpan(children: AnsiParser.parse(line.text, p, fontSize: 12.0)),
            style: const TextStyle(
              fontFamily: 'Menlo, Monaco, monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        );

      case TerminalLineType.stdout:
        final spans = AnsiParser.parse(line.text, p, fontSize: 12.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text.rich(
            TextSpan(children: spans),
            style: const TextStyle(
              fontFamily: 'Menlo, Monaco, monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        );
    }
  }

  Widget _buildPromptLine(TerminalLine line, Pal p) {
    final text = line.text;
    String location = '';
    String command = text;

    if (text.contains(' ❯ ')) {
      final parts = text.split(' ❯ ');
      location = parts[0];
      command = parts.sublist(1).join(' ❯ ');
    } else if (text.startsWith('❯ ')) {
      command = text.substring(2);
    }

    String pathPart = location;
    String? branchPart;
    if (location.contains(' [') && location.endsWith(']')) {
      final bIdx = location.lastIndexOf(' [');
      pathPart = location.substring(0, bIdx);
      branchPart = location.substring(bIdx + 2, location.length - 1);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (pathPart.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: p.dark ? const Color(0xFF0369A1).withOpacity(0.2) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.folder, size: 10, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  Text(
                    pathPart,
                    style: const TextStyle(
                      fontFamily: 'Menlo, Monaco, monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (branchPart != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: p.dark ? const Color(0xFF7C3AED).withOpacity(0.2) : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.branch, size: 10, color: Color(0xFFC084FC)),
                  const SizedBox(width: 3),
                  Text(
                    branchPart,
                    style: const TextStyle(
                      fontFamily: 'Menlo, Monaco, monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC084FC),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '❯ ',
            style: TextStyle(
              fontFamily: 'Menlo, Monaco, monospace',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: p.accent,
            ),
          ),
          Expanded(
            child: _formatCommandText(command, p),
          ),
        ],
      ),
    );
  }

  Widget _formatCommandText(String command, Pal p) {
    if (command.trim().isEmpty) {
      return Text(
        command,
        style: TextStyle(
          fontFamily: 'Menlo, Monaco, monospace',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
      );
    }

    final parts = command.trim().split(RegExp(r'\s+'));
    final spans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final isFirst = i == 0;
      final isFlag = part.startsWith('-');
      final isString = (part.startsWith('"') && part.endsWith('"')) ||
          (part.startsWith("'") && part.endsWith("'"));

      Color color = p.text;
      FontWeight weight = FontWeight.w500;

      if (isFirst) {
        color = const Color(0xFF38BDF8); // Executable in cyan
        weight = FontWeight.w700;
      } else if (isFlag) {
        color = const Color(0xFFC084FC); // Flags in purple
        weight = FontWeight.w600;
      } else if (isString) {
        color = p.ok; // Strings in green
        weight = FontWeight.w500;
      } else if (i == 1 && !isFlag) {
        color = p.text; // Subcommand in crisp text
        weight = FontWeight.w600;
      }

      spans.add(TextSpan(
        text: part,
        style: TextStyle(
          color: color,
          fontWeight: weight,
        ),
      ));

      if (i < parts.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontFamily: 'Menlo, Monaco, monospace',
        fontSize: 12,
      ),
    );
  }

  Widget _buildSystemLine(TerminalLine line, Pal p) {
    final text = line.text;

    if (text == 'Process exited with code 0') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.ok.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.ok.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: p.ok),
            const SizedBox(width: 6),
            T('Process exited successfully (code 0)', size: 11, weight: FontWeight.w500, color: p.ok),
          ],
        ),
      );
    }

    if (text.startsWith('Process exited with code')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.err.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.err.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: p.err),
            const SizedBox(width: 6),
            T(text, size: 11, weight: FontWeight.w600, color: p.err),
          ],
        ),
      );
    }

    if (text.startsWith('^C')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.warn.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.warn.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 12, color: p.warn),
            const SizedBox(width: 6),
            T(text, size: 11, weight: FontWeight.w500, color: p.warn),
          ],
        ),
      );
    }

    if (text.startsWith('DevSpace Integrated Terminal')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.terminal, size: 13, color: p.accent),
            const SizedBox(width: 7),
            const T('DevSpace Integrated Terminal', size: 11, weight: FontWeight.w600),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: p.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: T(Platform.isMac ? 'zsh -l' : (Platform.isWindows ? 'cmd.exe' : 'bash -l'), size: 10, color: p.muted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line.text,
        style: TextStyle(
          fontFamily: 'Menlo, Monaco, monospace',
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: p.muted,
        ),
      ),
    );
  }

  Widget _buildErrorLine(TerminalLine line, Pal p) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.err.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: p.err, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 6),
            child: Icon(Icons.error_outline_rounded, size: 13, color: p.err),
          ),
          Expanded(
            child: Text(
              line.text,
              style: TextStyle(
                fontFamily: 'Menlo, Monaco, monospace',
                fontSize: 12,
                color: p.err,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom interactive prompt bar with command suggestions.
  Widget _buildPrompt(BuildContext context, Pal p, TerminalSession session) {
    final suggestions = _quickSuggestions(session);
    final branch = session.branch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(
          top: BorderSide(color: p.border.withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Suggestions Dropdown Popup (shows when typing matching commands)
          if (_showSuggestionsPopup && _activeSuggestions.isNotEmpty && !session.isExecuting)
            _buildSuggestionsPopup(p, session),

          // Contextual Suggestions Quick Pills
          if (suggestions.isNotEmpty && !session.isExecuting && !_showSuggestionsPopup) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: [
                    for (final s in suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: HoverBuilder(
                          cursor: SystemMouseCursors.click,
                          onTap: () {
                            _cmdCtrl.text = s;
                            _submitCommand();
                          },
                          builder: (context, hovered) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: hovered ? p.hover : p.field,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: hovered ? p.accent.withOpacity(0.5) : p.border,
                                width: 1,
                              ),
                            ),
                            child: T(
                              s,
                              size: 11,
                              weight: FontWeight.w500,
                              color: hovered ? p.accent : p.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Interactive CLI Input Row with Path, Branch & Ghost Completion
          Row(
            children: [
              // Working directory badge in cyan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: p.dark ? const Color(0xFF0369A1).withOpacity(0.2) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.folder, size: 10, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 4),
                    Text(
                      session.shortCwd,
                      style: const TextStyle(
                        fontFamily: 'Menlo, Monaco, monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
              ),

              // Git branch badge in purple (if inside git repo)
              if (branch != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.dark ? const Color(0xFF7C3AED).withOpacity(0.2) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.branch, size: 10, color: Color(0xFFC084FC)),
                      const SizedBox(width: 3),
                      Text(
                        branch,
                        style: const TextStyle(
                          fontFamily: 'Menlo, Monaco, monospace',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC084FC),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Accent Chevron
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '❯',
                  style: TextStyle(
                    fontFamily: 'Menlo, Monaco, monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: p.accent,
                  ),
                ),
              ),

              // Text Field with Ghost Completion
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      // 1. Suggestions popup keyboard navigation
                      if (_showSuggestionsPopup && _activeSuggestions.isNotEmpty) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(() {
                            _selectedSuggestionIndex =
                                (_selectedSuggestionIndex + 1).clamp(0, _activeSuggestions.length - 1);
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(() {
                            _selectedSuggestionIndex =
                                (_selectedSuggestionIndex - 1).clamp(-1, _activeSuggestions.length - 1);
                            if (_selectedSuggestionIndex == -1) {
                              _showSuggestionsPopup = false;
                            }
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.tab) {
                          final chosen = _selectedSuggestionIndex >= 0
                              ? _activeSuggestions[_selectedSuggestionIndex]
                              : _activeSuggestions.first;
                          _applySuggestion(chosen, execute: false);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          setState(() => _showSuggestionsPopup = false);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter && _selectedSuggestionIndex >= 0) {
                          final chosen = _activeSuggestions[_selectedSuggestionIndex];
                          _applySuggestion(chosen, execute: true);
                          return KeyEventResult.handled;
                        }
                      }

                      // 2. Tab or Right Arrow with Ghost Suffix
                      if (event.logicalKey == LogicalKeyboardKey.tab && _ghostSuffix.isNotEmpty) {
                        final chosen = _activeSuggestions.first;
                        _applySuggestion(chosen, execute: false);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                          _ghostSuffix.isNotEmpty &&
                          _cmdCtrl.selection.baseOffset == _cmdCtrl.text.length) {
                        final chosen = _activeSuggestions.first;
                        _applySuggestion(chosen, execute: false);
                        return KeyEventResult.handled;
                      }

                      // 3. Normal History Navigation
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        _handleHistoryUp();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        _handleHistoryDown();
                        return KeyEventResult.handled;
                      }

                      // Ctrl+C terminates running process or clears input
                      if (event.logicalKey == LogicalKeyboardKey.keyC &&
                          HardwareKeyboard.instance.isControlPressed) {
                        if (session.isExecuting) {
                          session.kill();
                        } else {
                          _cmdCtrl.clear();
                          setState(() => _showSuggestionsPopup = false);
                        }
                        return KeyEventResult.handled;
                      }

                      // Ctrl+L or Cmd+K clears terminal
                      if ((event.logicalKey == LogicalKeyboardKey.keyL &&
                              HardwareKeyboard.instance.isControlPressed) ||
                          (event.logicalKey == LogicalKeyboardKey.keyK &&
                              HardwareKeyboard.instance.isMetaPressed)) {
                        session.clear();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Inline Ghost Completion text
                      if (_ghostSuffix.isNotEmpty && !session.isExecuting)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                _cmdCtrl.text,
                                style: const TextStyle(
                                  fontFamily: 'Menlo, Monaco, monospace',
                                  fontSize: 12.5,
                                  color: Colors.transparent,
                                ),
                              ),
                              Text(
                                _ghostSuffix,
                                style: TextStyle(
                                  fontFamily: 'Menlo, Monaco, monospace',
                                  fontSize: 12.5,
                                  color: p.muted.withOpacity(0.45),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Command Input TextField
                      TextField(
                        controller: _cmdCtrl,
                        focusNode: _cmdFocus,
                        autofocus: true,
                        style: TextStyle(
                          fontFamily: 'Menlo, Monaco, monospace',
                          fontSize: 12.5,
                          color: p.text,
                        ),
                        cursorColor: p.accent,
                        cursorWidth: 2,
                        cursorHeight: 14,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none,
                          hintText: session.isExecuting
                              ? 'Process running… Press Ctrl+C or Stop to abort'
                              : 'Type a command… (Tab/↑/↓ for suggestions)',
                          hintStyle: TextStyle(
                            fontFamily: 'Menlo, Monaco, monospace',
                            fontSize: 11.5,
                            color: p.muted.withOpacity(0.55),
                          ),
                        ),
                        onSubmitted: (_) => _submitCommand(),
                      ),
                    ],
                  ),
                ),
              ),

              if (session.isExecuting)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.accent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Suggestions Dropdown Popup.
  Widget _buildSuggestionsPopup(Pal p, TerminalSession session) {
    if (_activeSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 185),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: p.dark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.dark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.dark ? const Color(0xFF171A21) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              border: Border(bottom: BorderSide(color: p.border, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 12, color: p.accent),
                const SizedBox(width: 6),
                const T('COMMAND SUGGESTIONS', size: 10, weight: FontWeight.w700),
                const Spacer(),
                T('Tab to accept · ↑/↓ to choose · Esc to dismiss', size: 9.5, color: p.muted),
              ],
            ),
          ),
          // Suggestions List
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int idx = 0; idx < _activeSuggestions.length; idx++)
                    _buildSuggestionRow(_activeSuggestions[idx], idx == _selectedSuggestionIndex, p),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(TerminalSuggestion s, bool isSelected, Pal p) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () => _applySuggestion(s, execute: false),
      builder: (context, hovered) {
        final active = isSelected || hovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: active
              ? (p.dark ? const Color(0xFF282D37) : const Color(0xFFEEF2F6))
              : Colors.transparent,
          child: Row(
            children: [
              Icon(s.category.icon, size: 13, color: active ? p.accent : p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    _highlightMatchingText(s.command, _cmdCtrl.text, p, active),
                    const SizedBox(width: 8),
                    Flexible(
                      child: T(
                        s.description,
                        size: 11,
                        color: p.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.dark ? const Color(0xFF333842) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: T(s.badge!, size: 9, weight: FontWeight.w700, color: p.muted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _highlightMatchingText(String command, String query, Pal p, bool active) {
    final q = query.trim().toLowerCase();
    final lowerCmd = command.toLowerCase();

    if (q.isEmpty || !lowerCmd.startsWith(q)) {
      return Text(
        command,
        style: TextStyle(
          fontFamily: 'Menlo, Monaco, monospace',
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          color: active ? p.accent : p.text,
        ),
      );
    }

    final matched = command.substring(0, q.length);
    final rest = command.substring(q.length);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: matched,
            style: TextStyle(
              color: p.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: rest,
            style: TextStyle(
              color: active ? p.text : p.text.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: const TextStyle(
        fontFamily: 'Menlo, Monaco, monospace',
        fontSize: 12,
      ),
    );
  }

  /// Dynamic suggestions based on files in working directory (git, flutter, npm, cargo).
  List<String> _quickSuggestions(TerminalSession session) {
    final list = <String>['git status', 'git pull', 'ls -la'];
    try {
      final dir = session.cwd;
      if (io.File(p.join(dir, 'pubspec.yaml')).existsSync()) {
        list.insert(0, 'flutter test');
        list.insert(0, 'flutter run');
      } else if (io.File(p.join(dir, 'package.json')).existsSync()) {
        list.insert(0, 'npm test');
        list.insert(0, 'npm run dev');
      } else if (io.File(p.join(dir, 'Cargo.toml')).existsSync()) {
        list.insert(0, 'cargo test');
        list.insert(0, 'cargo run');
      }
    } catch (_) {}
    return list;
  }
}

/// Draggable horizontal splitter separating catalog/editor view from bottom terminal.
class TerminalSplitter extends StatelessWidget {
  const TerminalSplitter({
    super.key,
    required this.onDrag,
    required this.color,
    this.onDoubleTap,
  });

  final ValueChanged<double> onDrag;
  final Color color;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        supportedDevices: kDragDevices,
        onVerticalDragUpdate: (d) => onDrag(-d.delta.dy),
        onDoubleTap: onDoubleTap,
        child: Container(
          height: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              height: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
