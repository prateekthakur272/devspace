# Project structure

DevSpace is a Flutter desktop application (macOS, Windows, and Linux) written in Dart. There is one primary package, `devspace`, and no Android, iOS, or web targets.

```
devspace/
├── README.md                 Overview, feature summary, quick install, and docs index
├── pubspec.yaml              Dependencies, version, and asset declarations
├── analysis_options.yaml     Static analysis lints (flutter_lints)
├── lib/                      Dart source code organized in strict architectural layers
├── test/                     Unit and widget tests (100% passing)
├── docs/                     User guides, architecture specifications, and workflows
│   ├── ARCHITECTURE.md
│   ├── README.md
│   ├── building-and-releasing.md
│   ├── contributing.md
│   ├── features.md
│   ├── getting-started.md
│   ├── guidelines.md
│   ├── keyboard-shortcuts.md
│   ├── product-specification.md
│   ├── project-structure.md
│   ├── troubleshooting.md
│   └── user-manual.md
├── macos/ windows/ linux/    Native desktop platform runners and packaging configurations
├── .github/workflows/        Continuous integration (ci.yml) and release automation (release.yml)
└── assets/                   Icons, emblems, and visual assets
```

## `lib/` Layer Breakdown

Every Dart import is structured as `package:devspace/...`. The root directory is organized into clear functional layers:

```
lib/
├── main.dart            Application entry point: window initialization, menu setup, root AppScope
├── app/                 Centralized application state and topic-specific extensions
├── core/                Platform-agnostic domain models, Git operations, storage, and logging
├── features/            Feature screen modules (Catalog, Git Radar, Notes, Tools, Shell, Palette)
├── components/          Reusable desktop design-system widgets (buttons, splitters, inputs, dialogs)
├── theme/               Color palette (Pal), semantic tokens, density, and icons
├── platform/            Native OS interactions (process launching, Finder/Explorer reveal, URLs)
└── utils/               Paths, JSON serialization, app configuration, update checker
```

### `app/`: State Management

| File | Responsibility |
|---|---|
| `app_state.dart` | `AppState`: Central `ChangeNotifier` owning projects, groups, notes, active filters, and modal states. Handed to widgets via `AppScope` (`InheritedNotifier`). |
| `app_state_*.dart` | Topic-specific extensions (`app_state_projects.dart`, `app_state_git.dart`, `app_state_groups.dart`, `app_state_notes.dart`, `app_state_tools.dart`, `app_state_filter.dart`) keeping business logic modular. |
| `app_scope.dart` | `AppScope`: Provides reactive context access (`AppScope.of(context)`). |
| `modal.dart` | Sealed hierarchy of modal dialog descriptors (`ModalSettings`, `ModalAddProject`, `ModalConfirmDelete`, `ModalAbout`, etc.). |

### `core/`: Logic and Services (UI-Independent)

Logic in `core/` has **zero dependencies on Flutter UI widgets** or `features/`, ensuring full testability:

| Folder | What it holds |
|---|---|
| `git/` | `GitService`: Interacts with system `git` CLI (status, diffs, stage, unstage, commit, push, pull, fetch, stash, branch creation). |
| `logging/` | `Log`: Rotating, size-capped (1 MB) file logger with structured tags and secret redaction. |
| `model/` | Immutable data structures: `Project`, `Group`, `Note`, `RadarRepository`, `GitStatus`, `GitChangedFile`, `IdeInstallation`. |
| `storage/` | `AppStore`: Synchronous, atomic JSON persistence for configuration, projects, workspaces, notes, and session state. |
| `terminal/` | Terminal execution bridges and ANSI color parsing. |
| `tools/` | Automated detection services for IDEs (`ide_detection_service.dart`) and CLI tools (`tool_detection_service.dart`). |

### `features/`: Screen Modules

| Folder | What it provides |
|---|---|
| `catalog/` | Unified Project Catalog: grid/list cards, project detail view, tagging, pinning, and workspace sidebar. |
| `git_radar/` | Repository-First Git Radar: consolidated dashboard, single-row responsive header, interactive Git sidepane, diff view. |
| `notes/` | Scratchpad & Notes: project-linked notes, interactive Markdown checklist engine (`[]`), search, and categorization. |
| `tools/` | Developer Tools & SDKs dashboard: CLI and runtime inspector with version detection. |
| `palette/` | Universal Command Palette (`⌘K` / `Ctrl+K`): fuzzy search across all entities and commands. |
| `shell/` | Application Shell: frameless custom title bar, macOS traffic light padding, tab strip, status bar, and native platform menus. |
| `dialogs/` | Modal dialogs: Settings, Add/Edit Project, Group management, Developer info, Onboarding tour. |

### `components/`: Desktop Design System

Reusable desktop widgets built for precision and keyboard accessibility:

- `buttons.dart`: `Btn`, `IconBtn`, `Segmented`, `ClickableNoRipple`.
- `layout.dart`: `ModalScaffold` with shrink-wrap constraints, scrollbars, cards.
- `splitters.dart`: Desktop resizable splitters with trackpad drag separation (`kDragDevices`).
- `context_menu.dart`: Desktop right-click and dropdown menus.
- `inputs.dart`: Framed search inputs, text fields, and dropdown selectors.
