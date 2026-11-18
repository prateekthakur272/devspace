# Contributing to DevSpace

Thank you for contributing to DevSpace! This guide details local development setup, code organization, testing invariants, and pull request guidelines.

## Ways to Help

- **Report a bug**: Use **Help ▸ About DevSpace ▸ Report an Issue** or submit a GitHub issue detailing steps to reproduce, expected behavior, and environment specs.
- **Propose a feature**: Describe the workflow friction you are attempting to eliminate before proposing implementation specifics.
- **Improve documentation**: Enhance or clarify guides in `docs/`.
- **Submit a pull request**: Address existing issues or add enhancements adhering to the architecture.

## Local Development Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable channel). DevSpace uses Flutter 3.50.0 (Dart SDK `^3.14.0`).
2. Fork and clone the repository:
   ```bash
   git clone https://github.com/prateekthakurdev/devspace.git
   cd devspace
   flutter pub get
   ```
3. Run the application on your platform:
   ```bash
   flutter run -d macos    # or -d windows, -d linux
   ```
4. Verify code quality:
   ```bash
   flutter analyze
   flutter test
   ```

## Code Organization & Architecture

Before making changes, review [ARCHITECTURE.md](ARCHITECTURE.md), [project-structure.md](project-structure.md), and [guidelines.md](guidelines.md). Key invariants:

1. **Layer Separation**:
   - `core/` contains pure domain models, Git logic, and file storage.
   - **`core/` must never import `app/`, `features/`, `components/`, `theme/`, or `platform/`.**
   - New screens belong in `features/<name>/`.
   - Shared desktop widgets belong in `components/`.
2. **State Management**:
   - Keep state in `AppState` (`lib/app/app_state.dart`) or topic-specific extensions (`app_state_*.dart`).
   - Use `AppScope.of(context)` to consume state reactively.
3. **Desktop Interaction Standards**:
   - All drag handles and splitters must pass `supportedDevices: kDragDevices` to prevent trackpad scrolling from initiating drag actions.
   - Modals must use `ModalScaffold` with intrinsic height constraints (`MainAxisSize.min`).
4. **Data Storage**:
   - Zero reliance on `shared_preferences`. Store data via `AppStore` in `~/.devspace/`.
   - Never log secrets, auth tokens, or private paths.

## Testing Guidelines

```bash
flutter test
```

- **Unit tests**: Test business logic and Git models in isolation without Flutter widget bindings.
- **Widget tests**: Use widget harnesses with `host(state)` to verify desktop layout, keyboard navigation, modal presentation, and event handling.
- **Isolation**: Tests that read or write configuration must configure `AppStore.homeOverride` to use a temporary directory to avoid touching the developer's real `~/.devspace`.

## Submitting Pull Requests

1. Format code with `dart format lib test`.
2. Ensure `flutter analyze` reports **0 issues**.
3. Ensure all tests in `flutter test` pass (**100% pass rate**).
4. Update matching documentation in `docs/` and `README.md` if your PR introduces new features, shortcuts, or architectural changes.
