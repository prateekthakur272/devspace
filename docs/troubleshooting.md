# Troubleshooting

## Where DevSpace keeps its files

DevSpace stores all configuration and application state in `~/.devspace` (on Windows: `%USERPROFILE%\.devspace`). Choose **Help ▸ Show Data Folder** or **Settings ▸ Storage & Data ▸ Open Folder** to open it.

| File / Folder | Purpose |
|---|---|
| `settings.json` | Application preferences (theme, default IDE, Git refresh intervals) |
| `projects.json` / `projects/` | Registered projects, tags, pinning, and per-project default editors |
| `workspaces.json` | User-defined project workspaces and groups |
| `notes.json` / `notes/` | Quick notes, markdown checklists, and project associations |
| `state.json` | Saved session state (active tab, selected workspace, sidebar status) |
| `prefs.json` | Minor application flags and dismissed notifications |
| `devspace.log` | Rotating log of operational warnings and errors |

Your original source code files and repositories are never moved into this folder.

To reset DevSpace to a clean state:
1. Quit DevSpace completely.
2. Move or rename the `~/.devspace` directory.
3. Relaunch the app.

---

## Editor & IDE Launching

- **Editor is not appearing in the list**: DevSpace searches standard system application paths (`/Applications`, `~/Applications`, `C:\Program Files`, `/usr/bin`, etc.). If your editor is installed in a non-standard location or via a custom package manager, add its absolute binary path under **Settings ▸ Editors ▸ Custom Editors**.
- **VS Code or Cursor fails to open project**: Ensure the command-line CLI (`code` or `cursor`) is installed in your system `PATH`. In VS Code, you can enable this via the Command Palette: `Shell Command: Install 'code' command in PATH`.
- **Opening a multi-project monorepo opens the wrong folder**: Right-click the repository or click the dropdown arrow next to the open button to view the **Open** submenu, which allows selecting either specific subprojects or the canonical **Repo Root**.

---

## Git Radar & Repositories

- **Repository status says "Not a Git repository"**: Ensure the folder contains a `.git` subdirectory or is located within a valid Git worktree.
- **Git status is out of date**: Press **⌘R** or select **Rescan Git Statuses** from the Git Radar overflow menu (`···`) to force a fresh scan of all repositories.
- **Git command fails (Authentication or Permission)**: DevSpace executes native `git` CLI operations using your system environment credentials (SSH keys or credential helpers). If a pull or push fails, open your native terminal in that repository to verify remote access and SSH agents.
- **Sidepane diff does not load**: Very large generated files (minified bundles, locks) or binary files cannot be previewed in text diffs. DevSpace will note when a file is binary.

---

## Performance & Logs

- **Inspect operational logs**: Open `~/.devspace/devspace.log` to review timestamped log entries and diagnostic warnings.
- **Reporting an issue**: Click **Help ▸ About DevSpace ▸ Report an Issue** to open the issue tracker with your DevSpace version and operating system automatically prefilled.
