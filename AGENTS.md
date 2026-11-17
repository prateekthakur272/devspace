# DevSpace Development Instructions & Guidelines

All development and code generation in this project must strictly adhere to the engineering guidelines, architecture, and desktop patterns documented in **[docs/guidelines.md](file:///Users/ent-0554/Documents/Prateeks%20Workspace/devspace/docs/guidelines.md)**.

## Core Rules & Invariants

1. **Architecture & File Organization**:
   - `lib/app/`: Central `AppState` (`ChangeNotifier`) with slice extensions (`app_state_*.dart`), modal management (`state.modal`), and session persistence.
   - `lib/components/`: Reusable desktop design-system widgets (buttons, splitters, context menus, drag device filters, custom borders, hover builders).
   - `lib/core/`: Platform-agnostic domain logic, rotating file logger (`Log`), immutable data models, and synchronous atomic storage (`storage.dart`).
   - `lib/features/`: Feature modules (`shell/`, `catalog/`, `git_radar/`, `palette/`, `preferences/`).
   - `lib/platform/`: Desktop OS bridges (`platform.dart`) for native dialogs, revealing in Finder/Explorer, terminal launches, and external URLs.
   - `lib/theme/`: Semantic palette tokens via `Pal` / `PalScope` / `context.pal` and desktop layout density.
   - `lib/utils/`: Path resolution (`Paths.home`, `Paths.dataDir`), safe JSON serialization, and dynamic metadata.

2. **Window Management & Chrome**:
   - Custom title bar with `TitleBarStyle.hidden` using `window_manager`.
   - Preserve macOS traffic lights (`leftInset: 72`); provide custom window buttons on Windows/Linux.
   - Title bar drag, double-click to toggle maximize/restore/zoom, and right-click for window context menu.
   - Always persist and restore window bounds with monitor visibility checks (`_onScreen`) and debounced saving.
   - Prevent close (`setPreventClose(true)`) to flush and persist state before `destroy()`.
   - Flicker-free launch: show window only on the first rendered frame.

3. **Desktop Interaction & Input**:
   - **Trackpad vs Mouse drag separation**: Always pass `supportedDevices: kDragDevices` (excluding `PointerDeviceKind.trackpad`) to draggable handles and splitters to prevent trackpad scrolling from triggering accidental resize/drag operations.
   - Enforce `ClampingScrollPhysics` and desktop hover scrollbars; disable mobile rubber-band overscroll.
   - Platform-adaptive menus: Native macOS menu bar (`PlatformMenuBar`) and in-window menu bars for Windows/Linux.
   - Platform-aware shortcuts (`Shortcut` class: `⌘` on macOS, `Ctrl` on Windows/Linux).
   - Universal Command Palette (`Cmd + K` / `Ctrl + K`) with fast fuzzy search.

4. **Code Quality & Reliability**:
   - Centralize path resolution in `Paths` (single source of truth with `homeOverride` for tests).
   - Synchronous atomic storage for instant startup.
   - Safe error handling: functional `Result<T>`, normalized messages via `errorText()`, and assertions via `require()`.
   - Rotating logger capped at 1 MB with `.old` backup, structured tags, and secret sanitization.
