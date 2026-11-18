# DevSpace architecture

DevSpace is a high-performance desktop workspace for developers. `lib/main.dart` initializes window bounds and flags, sets up state, and renders the root application shell; everything else is divided into strict layers under `lib/`.

## Architectural Layers

| Layer | Owns | May depend on |
|---|---|---|
| `core/` | Domain logic: domain models, Git operations, disk storage, logging, terminal handling, tool & IDE detection | `utils/` |
| `utils/` | Constants, path resolution, JSON serialization, app metadata, update checks | `core/logging/` |
| `theme/`, `platform/` | Color palette (`Pal`), icons, desktop layout tokens, native OS bridges | `core/logging/`, `utils/` |
| `components/` | Reusable UI widgets: buttons, splitters, inputs, modal scaffolding | `theme/`, `core/model/` |
| `app/` | Application state (`AppState`), slice extensions, modal triggers | `core/`, `platform/` |
| `features/*` | Specific screens: Catalog, Git Radar, Notes, Tools, Palette, Shell | `app/`, `components/`, `core/`, `theme/`, `platform/` |
| `main.dart`, `features/shell/` | Window shell, menus, and top-level composition | Everything |

### Invariant: Pure Core Logic

The most critical architectural invariant:
> **`core/` never imports `app/`, `features/`, `components/`, `theme/`, or `platform/`.**

All logic in `core/` (Git operations, model serialization, IDE detection, logging) must run and be fully testable without a Flutter UI context or widget tree.

## State Management

- **`AppState`** (`lib/app/app_state.dart`): The single owner of truth (a `ChangeNotifier`). Owns project collections, Git repositories, notes, active workspace filters, and the currently active modal dialog.
- **Slice Extensions** (`lib/app/app_state_*.dart`): Operations on `AppState` are partitioned by topic (e.g., `app_state_projects.dart`, `app_state_git.dart`) to keep state definitions clean and behaviors organized.
- **`AppScope`** (`lib/app/app_scope.dart`): An `InheritedNotifier` delivering state down the widget tree. `AppScope.of(context)` subscribes widgets to state changes; `AppScope.read(context)` inspects state without rebuilding.
- **Dialogs & Modals**: Represented as a sealed `Modal` class. Calling `state.modal = ModalAddProject(...)` displays a modal; `Modals` (`lib/features/dialogs/modals.dart`) resolves each case via an exhaustive pattern match.
- **Platform Menus**: Defined as declarative data in `lib/features/shell/menus.dart`. Rendered as native macOS menu items via `PlatformMenuBar` and as title bar menus on Windows and Linux.

## Repository-First Git Radar Architecture

DevSpace implements a **repository-first aggregation model**:
1. Multiple registered projects may belong to the same root Git repository (e.g., in a monorepo).
2. Git Radar groups these projects into a canonical `RadarRepository`, preventing duplicate Git status polls and redundant fetch operations.
3. Repositories provide context-aware menus: opening single-project repositories launches the project directly; opening multi-project monorepos presents a sub-menu to choose between specific subprojects or the repository root in the default editor.
4. Clicking a repository card opens the Git sidepane. Clicking the selected repository again maintains focus without collapsing the sidepane.

## Desktop Interaction Invariants

1. **Trackpad vs. Mouse Separation**: All draggable handles, splitters, and window dividers pass `supportedDevices: kDragDevices` (excluding trackpad scrolling) to prevent accidental layout resize operations during trackpad navigation.
2. **Modal Dialog Shrink-Wrapping**: `ModalScaffold` uses intrinsic constraints (`ConstrainedBox(maxHeight: maxBodyHeight)` with `Column(mainAxisSize: MainAxisSize.min)`), ensuring dialogs never stretch to full window height while smoothly scrolling large contents.
3. **Window Bounds Persistence**: Window size, position, and maximized states are saved to disk with monitor visibility checks (`_onScreen`) to guarantee the window never opens offscreen.
4. **Flicker-Free Startup**: The window is rendered offscreen or shown only after the first frame completes.

## Data on Disk

DevSpace maintains zero reliance on cloud services or operating system preference stores (`shared_preferences`). All application state is stored locally under `~/.devspace` (or `%USERPROFILE%\.devspace` on Windows):

| File / Folder | Contents |
|---|---|
| `settings.json` | User preferences: theme, font scale, default IDE, Git auto-refresh interval |
| `projects.json` / `projects/*.json` | Registered projects, custom paths, tags, favorite status, project-specific IDEs |
| `workspaces.json` | Custom workspace/group definitions and color tags |
| `notes.json` / `notes/*.json` | Quick scratchpad notes, project associations, and task checklists |
| `state.json` | Session state: active tab, selected workspace, collapsed sidebar status |
| `prefs.json` | Minor flags, onboarding completion, dismissed release notifications |
| `devspace.log` | Rotating, size-capped execution log (1 MB with `.old` backup) |

All file paths are resolved through `Paths` (`lib/utils/paths.dart`) and read/written via `AppStore` (`lib/core/storage/storage.dart`).
