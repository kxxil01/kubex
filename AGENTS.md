# Repository Guidelines

## Project Structure & Module Organization
- `Sources/kubex/` contains the SwiftUI macOS client, split into `Views/`, `ViewModels/`, `Services/`, and `Models/`; keep UI state in view models, not views.
- `Sources/kubex/Views/ClusterDetailView.swift` now owns the rollout inspector; reuse `WorkloadRolloutPane` helpers for charts, annotations, and the fixed column resource grids.
- `Tests/kubexTests/` mirrors the source tree and now runs with Swift 6's built-in `Testing` module—add new suites beside the code they exercise.
- `Scripts/` packages automation such as `build_and_install_app.sh` (builds + replaces `/Applications/Kubex.app`) and telemetry helpers.
- Runtime assets (kubeconfigs, logs, auth) stay outside the repo—see `README-MVP.md` for expected locations and setup walkthroughs.

## Build, Test, and Development Commands
- `swift build` — primary compile; run after every change to catch SwiftUI or dependency errors.
- `swift test` — executes the growing Testing-based suite (metrics, secrets, inspector flows); keep it green before pushing.
- `swift run kubex` — launches the CLI target for quick manual validation when Xcode is unavailable.
- `Scripts/build_and_install_app.sh` — produces a release `.app`, removes any existing `/Applications/Kubex.app`, and installs the fresh build.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines: types in UpperCamelCase, members in lowerCamelCase, protocol conformances grouped via extensions.
- Views stay small and composable; rely on the shared fixed-column table helpers for resource lists instead of ad-hoc `ScrollView` layouts.
- Configuration files (JSON/TOML) use snake_case keys, two-space indentation, and a trailing newline; keep diffs minimal and focused.

## Testing Guidelines
- Add targeted tests under `Tests/kubexTests/` using the `@Test` attribute; prefer fixture-driven mocks for kubectl interactions.
- Cover new selector or inspector behaviour with async tests where possible; exercise failure paths (forbidden RBAC, missing metrics, etc.).
- When touching rollout history or service latency heuristics, assert the percentile helpers and event annotations stay in sync with mock data.
- Run `swift build && swift test` before packaging; include the commands (and results) in PR notes.

## Commit & Pull Request Guidelines
- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`); keep subjects imperative and under 72 characters.
- PRs must describe scope, affected views/services, manual QA, and test output; attach screenshots or screen recordings for visual tweaks.
- Reference tracking issues or roadmap items, and note any required kubeconfig or Prometheus setup so reviewers can reproduce.

## Security & Configuration Tips
- Never commit kubeconfigs or secrets—`auth.json` remains local. Audit changes with `rg -n "(token|secret|password)"` before publishing.
- Multi-kubeconfig support expects explicit paths; verify connections via the Connection Wizard and log output in `~/Library/Logs/Kubex/`.
- Update `version.json` whenever behaviour visible to users changes (UI layout, metrics providers, packaging flow) so release notes stay accurate.

## UI & UX Expectations
- Rollout charts now surface success/failure annotations sourced from events; keep tooltip copy succinct and prefer ≤6 concurrent markers.
- Topology cards should display per-service endpoint coverage plus p50/p95 latency text using the shared `ServiceCardStat` utilities.
- Inspector port-forward badges must expose in-place teardown (no external Terminal); defer to `AppModel.stopPortForward` for cleanup.
- Node and workload tables include toolbar sort menus (name, age, readiness, etc.); default to `Name ↑` and preserve namespace filter interaction when extending columns.
