import 'package:flutter/material.dart';
import 'package:devspace/app/app_state.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/layout.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/core/storage/storage.dart';
import 'package:devspace/platform/platform.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';
import 'package:devspace/utils/app_config.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  int _currentStep = 0;
  static const int _totalSteps = 3;

  void _finish() {
    AppStore.setFlag('onboarding_completed', true);
    widget.state.modal = null;
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;

    return ModalScaffold(
      title: switch (_currentStep) {
        0 => 'Welcome to ${AppConfig.NAME}',
        1 => 'Customize Workspace',
        _ => 'Get Started with Projects',
      },
      width: 620,
      onClose: _finish,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Content step
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(_currentStep),
              child: switch (_currentStep) {
                0 => _buildWelcomeStep(p),
                1 => _buildCustomizeStep(p),
                _ => _buildGetStartedStep(p),
              },
            ),
          ),

          const SizedBox(height: 20),

          // Stepper Navigation Footer
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border.withOpacity(0.6), width: 1)),
            ),
            child: Row(
              children: [
                Btn(
                  label: 'Skip',
                  onClick: _finish,
                  height: 32,
                  fontSize: 12,
                ),
                const Spacer(),
                // Step Indicator Dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < _totalSteps; i++) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _currentStep == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentStep == i ? p.accent : p.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      if (i < _totalSteps - 1) const SizedBox(width: 5),
                    ],
                  ],
                ),
                const Spacer(),
                if (_currentStep > 0) ...[
                  Btn(
                    label: 'Back',
                    onClick: _prev,
                    height: 32,
                    fontSize: 12,
                  ),
                  const SizedBox(width: 8),
                ],
                Btn(
                  label: _currentStep == _totalSteps - 1 ? 'Get Started' : 'Continue',
                  primary: true,
                  icon: _currentStep == _totalSteps - 1 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                  onClick: _next,
                  height: 32,
                  fontSize: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Welcome & Mission
  // ---------------------------------------------------------------------------
  Widget _buildWelcomeStep(Pal p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero branding card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                p.accent.withOpacity(0.14),
                p.panel,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.accent.withOpacity(0.25), width: 1),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/header_logo.png',
                width: 44,
                height: 44,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T(
                      'Welcome to ${AppConfig.NAME}',
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 3),
                    T(
                      'The unified desktop workspace, repository hub, and live Git radar for local developers.',
                      size: 12,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3 Key pillars
        _buildFeatureItem(
          p: p,
          icon: Icons.grid_view_rounded,
          iconColor: p.accent,
          title: 'Workspace Catalog & Groups',
          description:
              'Group and monitor repositories across custom workspace categories with automatic tech stack detection and one-click IDE launch.',
        ),
        const SizedBox(height: 8),
        _buildFeatureItem(
          p: p,
          icon: AppIcons.radar,
          iconColor: p.warn,
          title: 'Real-Time Combined Git Radar',
          description:
              'Instant dashboard for every Git repo: tracking branches, modified files, unpushed commits, stash states, and release tags.',
        ),
        const SizedBox(height: 8),
        _buildFeatureItem(
          p: p,
          icon: AppIcons.note,
          iconColor: p.ok,
          title: 'Contextual Notes & Scratchpad',
          description:
              'Embedded markdown notes, checklists, and @project mentions to organize development plans right inside your workspace.',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required Pal p,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border.withOpacity(0.6), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(title, size: 12.5, weight: FontWeight.w600),
                const SizedBox(height: 2),
                T(
                  description,
                  size: 11,
                  color: p.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Customize Environment
  // ---------------------------------------------------------------------------
  Widget _buildCustomizeStep(Pal p) {
    final settings = widget.state.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const T('Appearance & Theme', size: 13, weight: FontWeight.w600),
        const SizedBox(height: 4),
        T(
          'Select your preferred color mode. You can change this anytime from preferences.',
          size: 11,
          color: p.muted,
        ),
        const SizedBox(height: 10),

        // Theme selector cards
        Row(
          children: [
            _buildThemeOption(
              p: p,
              title: 'System',
              subtitle: 'Follows OS mode',
              icon: Icons.brightness_auto_rounded,
              mode: ThemeMode.system,
              selected: settings.themeMode == ThemeMode.system,
            ),
            const SizedBox(width: 8),
            _buildThemeOption(
              p: p,
              title: 'Dark',
              subtitle: 'Slate dark palette',
              icon: Icons.dark_mode_rounded,
              mode: ThemeMode.dark,
              selected: settings.themeMode == ThemeMode.dark,
            ),
            const SizedBox(width: 8),
            _buildThemeOption(
              p: p,
              title: 'Light',
              subtitle: 'Crisp bright palette',
              icon: Icons.light_mode_rounded,
              mode: ThemeMode.light,
              selected: settings.themeMode == ThemeMode.light,
            ),
          ],
        ),

        const SizedBox(height: 16),

        const T('Preferred IDE / Editor', size: 13, weight: FontWeight.w600),
        const SizedBox(height: 4),
        T(
          'Choose the editor DevSpace launches when clicking on a project card.',
          size: 11,
          color: p.muted,
        ),
        const SizedBox(height: 10),

        // Editor selection grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final editor in [
              EditorType.vscode,
              EditorType.cursor,
              EditorType.intellij,
              EditorType.androidStudio,
              if (Platform.isMac) EditorType.xcode,
              EditorType.custom,
            ])
              _buildEditorChip(
                p: p,
                editor: editor,
                selected: settings.defaultEditor == editor,
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Detected Developer Tools
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border.withOpacity(0.6), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.terminal_rounded, size: 18, color: p.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Developer Tools & SDKs', size: 12, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      widget.state.detectedTools.isEmpty
                          ? 'Scanning your PATH for installed developer CLI tools…'
                          : '${widget.state.detectedTools.length} developer tools detected and verified.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              if (widget.state.detectedTools.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.ok.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 11, color: p.ok),
                      const SizedBox(width: 3),
                      T('${widget.state.detectedTools.length} Ready', size: 10.5, color: p.ok, weight: FontWeight.w600),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required Pal p,
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
  }) {
    return Expanded(
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        onTap: () {
          widget.state.updateSettings(
            widget.state.settings.copyWith(themeMode: mode),
          );
        },
        builder: (context, hovered) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? p.accent.withOpacity(0.12)
                  : hovered
                      ? p.hover
                      : p.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? p.accent
                    : hovered
                        ? p.border
                        : p.border.withOpacity(0.6),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? p.accent : p.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T(
                        title,
                        size: 12,
                        weight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? p.accent : p.text,
                      ),
                      T(subtitle, size: 10, color: p.muted),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorChip({
    required Pal p,
    required EditorType editor,
    required bool selected,
  }) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      onTap: () {
        widget.state.updateSettings(
          widget.state.settings.copyWith(defaultEditor: editor),
        );
      },
      builder: (context, hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? p.accent.withOpacity(0.12)
                : hovered
                    ? p.hover
                    : p.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? p.accent : p.border.withOpacity(0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: selected ? p.accent : p.muted,
              ),
              const SizedBox(width: 6),
              T(
                editor.label,
                size: 11.5,
                weight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? p.accent : p.text,
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Get Started
  // ---------------------------------------------------------------------------
  Widget _buildGetStartedStep(Pal p) {
    final mod = Platform.isMac ? '⌘' : 'Ctrl+';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const T('Import Your First Project', size: 13, weight: FontWeight.w600),
        const SizedBox(height: 4),
        T(
          'Add a Git repository from your machine or create a workspace group.',
          size: 11,
          color: p.muted,
        ),
        const SizedBox(height: 12),

        // Action card: Add Project
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.accent.withOpacity(0.35), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(AppIcons.folder, size: 22, color: p.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Browse Local Repository', size: 13, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      'Pick any folder on disk. DevSpace automatically inspects Git status and tech stack.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Btn(
                label: 'Add Project…',
                primary: true,
                icon: AppIcons.add,
                height: 32,
                fontSize: 12,
                onClick: () async {
                  _finish();
                  final picked = await Platform.pickDirectory('Select Project Directory');
                  if (picked != null && picked.isNotEmpty) {
                    widget.state.modal = ModalAddProject(initialPath: picked);
                  } else {
                    widget.state.modal = const ModalAddProject();
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Action card: Create Workspace Group
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border.withOpacity(0.6), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.warn.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.create_new_folder_outlined, size: 22, color: p.warn),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Create Workspace Group', size: 13, weight: FontWeight.w600),
                    const SizedBox(height: 2),
                    T(
                      'Organize multiple repos into groups like Work, Personal, or Open Source.',
                      size: 11,
                      color: p.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Btn(
                label: 'New Group…',
                outlined: true,
                height: 32,
                fontSize: 12,
                onClick: () {
                  _finish();
                  widget.state.modal = const ModalCreateGroup();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Shortcuts summary badge bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: p.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: p.border.withOpacity(0.5), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.keyboard_outlined, size: 14, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: T(
                  'Quick Keys:  ${mod}K Palette  •  ${mod}N Add Project  •  ${mod}R Refresh Git  •  ${mod}1 Catalog  •  ${mod}2 Radar',
                  size: 10.5,
                  color: p.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
