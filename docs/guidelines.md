# DevSpace Desktop Engineering Guidelines & Architecture

This document establishes the architecture, code organization, and desktop design standards for **DevSpace**, derived from the battle-tested patterns and best practices in [`open_rest`](file:///Users/ent-0554/Documents/Prateeks%20Workspace/open_rest).

---

## 1. Project Organization & Modular Architecture

DevSpace follows a layered, feature-oriented structure with clear separation between platform abstraction, business domain, state management, and desktop UI presentation.

```
lib/
├── app/                  # Application lifecycle & global state
│   ├── app_state.dart    # Central ChangeNotifier orchestrator
│   ├── app_state_*.dart  # Focused state extensions (projects, git, workspaces)
│   ├── modal.dart        # Typed modal definitions & overlay controller
│   └── sessions.dart     # Tab & active session persistence
├── components/           # Reusable desktop design-system widgets
│   ├── buttons.dart      # Desktop buttons & icon triggers
│   ├── context_menu.dart # Declarative right-click popup menus
│   ├── drag_devices.dart # Trackpad vs mouse drag filtering
│   ├── layout.dart       # SplitPanes, tab strips, panels, dividers
│   ├── modifiers.dart    # HoverBuilder, Clickable, border painters
│   └── text.dart         # Standardized desktop typography
├── core/                 # Platform-agnostic domain logic
│   ├── git/              # Git CLI runners, branch parsers, health analyzers
│   ├── ide/              # IDE discovery, executable resolvers, launchers
│   ├── logging/          # Rotating file & console logger
│   ├── model/            # Immutable data models & schemas
│   └── storage/          # Local filesystem persistence (~/.devspace)
├── features/             # High-level UI feature views
│   ├── catalog/          # Project list, grid, and detail views
│   ├── git_radar/        # Aggregated git health dashboard
│   ├── palette/          # Universal Command Palette (Cmd/Ctrl + K)
│   ├── preferences/      # App & workspace settings modals
│   └── shell/            # Window chrome, title bars, menus, layout scaffold
├── platform/             # Desktop OS bridges
│   └── platform.dart     # Finder/Explorer reveal, terminal launch, pickers
├── theme/                # Visual design system
│   ├── icons.dart        # Centralized icon definitions
│   └── theme.dart        # Dual-theme palette (Pal, PalScope, ColorScheme)
└── utils/                # General helpers
    ├── app_config.dart   # App constants & identifiers
    ├── app_metadata.dart # Dynamic version & build info
    ├── json.dart         # Safe JSON parser & serializers
    └── paths.dart        # Single-source directory & path resolver
```

---

## 2. Desktop-First Architectural Best Practices

### 2.1. Centralized Single Source of Truth for Paths
Never hardcode `~` or build user directory paths in widgets or feature code. Centralize all filesystem locations in `Paths`:
- Support Windows (`USERPROFILE`) and Unix (`HOME`) consistently.
- Standardize app directories: config files (`~/.devspace/config.json`), logs (`~/.devspace/devspace.log`), and uniquely stamped temp files (`systemTemp/devspace-<timestamp>.<ext>`).
- Allow `homeOverride` to isolate test environments without polluting the user's home folder.

### 2.2. Robust Persistence & Synchronous Storage
- Settings and workspace configs are small; reading synchronously on startup prevents empty "loading" states or widget flashing.
- Separate **Settings** (`settings.json`), **State** (`state.json` - window bounds, sidebar width, open tabs, active filters), and **Projects** (`projects.json`).
- Always check `isFirstRun()` (absence of configuration files) to display onboarding or welcome walkthroughs automatically.

### 2.3. Resilient Error Handling & Safe Logging
- Standardize on a functional `Result<T>` pattern for operations that can fail (e.g. running git commands, resolving IDE executables).
- Use `errorText(Object e)` to strip Dart runtime prefixes (`Exception: `, `Bad state: `) for human-facing errors.
- Rotating logger (`Log`):
  - Cap log files at 1 MB, automatically rotating to `<name>.old`.
  - Log with structured tags: `Log.info('git', 'Checked out branch main')`.
  - Use `Log.orElse()` for non-critical fallback operations (reading optional files).
  - **Never** log passwords, tokens, or sensitive project secrets.

---

## 3. Mandatory Desktop Platform Features

### 3.1. Native Window Management & Custom Chrome
Desktop applications should render an integrated title bar while respecting OS conventions:

```dart
// Window initialization checklist
await wm.windowManager.ensureInitialized();
await wm.windowManager.waitUntilReadyToShow(
  wm.WindowOptions(
    size: savedGeometry?.size ?? const Size(1360, 860),
    minimumSize: const Size(800, 500),
    center: savedGeometry == null,
    title: AppConfig.NAME,
    titleBarStyle: wm.TitleBarStyle.hidden,
    windowButtonVisibility: Platform.isMac, // Native traffic lights on macOS
  ),
  () async {
    if (savedGeometry != null && isVisibleOnConnectedScreens(savedGeometry)) {
      await wm.windowManager.setPosition(savedGeometry.position);
    }
    if (savedGeometry?.maximized == true) {
      await wm.windowManager.maximize();
    }
  },
);
await wm.windowManager.setPreventClose(true);
```

#### Essential Window Chrome Rules:
1. **macOS Inset**: Keep a `leftInset: 72` on the custom title bar on macOS to make space for the floating native traffic light buttons.
2. **Windows / Linux Caption Controls**: Provide dedicated minimize, maximize/restore, and close buttons on Windows and Linux.
3. **Title Bar Gestures**:
   - Drag anywhere on empty title bar space moves the window (`windowManager.startDragging()`).
   - Double-click toggles maximize / restore (zoom on macOS).
   - Right-click pops up the native OS window context menu (`windowManager.popUpWindowMenu()`).
4. **Window Geometry Persistence**:
   - Debounce window move/resize events (e.g., 400ms) before writing bounds to disk to avoid thrashing I/O.
   - Verify saved coordinates against current `PlatformDispatcher.instance.displays` to prevent opening windows off-screen when an external monitor has been unplugged.
5. **Flicker-Free Launch**:
   - Keep window invisible until the first Flutter frame renders (`addPostFrameCallback`), then call `setOpacity(1)`, `show()`, and `focus()`.

### 3.2. Platform-Adaptive Menu Bars & Shortcuts
- **macOS Native Menu Bar**: Use `PlatformMenuBar`, `PlatformMenu`, and `PlatformMenuItem` to integrate directly with the top macOS system bar (About, Preferences `Cmd+,`, Services, Hide, Quit `Cmd+Q`).
- **Windows / Linux In-Window Menus**: Render compact File, Edit, View, Help menus inline inside the custom title bar.
- **Platform-Aware Keyboard Shortcuts**:
  - Abstraction class (`Shortcut`): Maps `primary` modifier to `⌘` (Meta) on macOS and `Ctrl` on Windows/Linux.
  - Consistent label generation (`⌘⇧P` vs `Ctrl+Shift+P`).
  - Global hardware keyboard interception via `HardwareKeyboard.instance.addHandler()`.

### 3.3. Command Palette (`Cmd + K` / `Ctrl + K`)
- Fast, non-blocking modal overlay for quick project jumping, editor selection, and command execution.
- Implement an in-memory fuzzy search algorithm scoring prefix matches, word boundaries (`/`, `-`, `_`, `.`), and character proximity.
- Full keyboard control: Arrow Up/Down navigation, Enter to execute, Escape to dismiss.

### 3.4. Resizable Panes & Draggable Dividers
- Use `SplitPane` with fractional widths (e.g., sidebar 22%, main content 78%).
- Show clear mouse cursors (`SystemMouseCursors.resizeLeftRight` / `SystemMouseCursors.resizeUpDown`).
- **Critical Trackpad Fix**: Explicitly pass `supportedDevices: kDragDevices` to gesture detectors:
  ```dart
  // Exclude PointerDeviceKind.trackpad so two-finger scroll swipes do NOT drag dividers or reorder tiles
  const Set<PointerDeviceKind> kDragDevices = {
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
  ```

### 3.5. Desktop Scroll & Mouse Interaction
- Override default mobile scroll behavior using a custom `MaterialScrollBehavior`:
  - Enforce `ClampingScrollPhysics` (disable mobile elastic bounce/glow).
  - Remove intrusive automatic mobile scrollbars in favor of clean desktop hover scrollbars (`FadeScrollbar`).
- Hover states: Wrap clickable cards and list items in `HoverBuilder` or `MouseRegion` to provide cursor feedback (`SystemMouseCursors.click`) and subtle highlight backgrounds.

### 3.6. OS Integration Bridges (`Platform` utility)
Provide native OS bridges for:
- **Show in File Manager**:
  - macOS: `open -R "$path"`
  - Windows: `explorer /select,"$path"`
  - Linux: `xdg-open "$(dirname "$path")"`
- **Launch in Terminal**: Spawn the user's preferred terminal emulator (Terminal.app, iTerm2, Windows Terminal, Ghostty, Alacritty) set to the project root directory.
- **Native File & Folder Pickers**: Use `file_picker` with `FilePicker.skipEntitlementsChecks()` called on startup.
- **External URL Launching**: Launch links via `url_launcher` with `LaunchMode.externalApplication`.

---

## 4. State Management & Data Flow

DevSpace utilizes a decoupled **ChangeNotifier + Slices** model:
1. **`AppState` Orchestrator**: The root `ChangeNotifier` holds references to active data stores and coordinates global events.
2. **Feature Extensions**: Partition state logic into clean extension files (`app_state_projects.dart`, `app_state_git.dart`, `app_state_workspaces.dart`) to keep files concise and maintainable.
3. **Reactive UI Binding**: Views listen to `AppState` via `ListenableBuilder` or scoped listeners, avoiding heavy third-party framework overhead for desktop apps.
4. **Modals as State**: Dialogs and overlays are managed declaratively:
   ```dart
   state.modal = ModalAddProject(); // Opens modal
   state.modal = null;              // Closes modal
   ```

---

## 5. Visual Design System & Theme Engine

1. **Semantic Color Palette (`Pal`)**:
   - Provide explicit tokens for `bg`, `panel`, `field`, `border`, `text`, `muted`, `accent`, `ok`, `warn`, and `err`.
   - Access via context extension: `context.pal.text`.
2. **`PalScope` InheritedTheme**: Ensures nested overlays, popups, and context menus inherit the current palette automatically.
3. **Compact Desktop Density**:
   - Use standard desktop heights (controls: 34px [tabs, buttons, text fields, dropdowns], list items: 36px, title bar: 28px).
   - Sub-13px typography for metadata badges and secondary labels.
