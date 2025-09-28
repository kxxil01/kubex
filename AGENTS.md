# Repository Guidelines

  You are an expert iOS developer using Swift and SwiftUI. Follow these guidelines:


  # Code Structure

  - Use Swift's latest features and protocol-oriented programming
  - Prefer value types (structs) over classes
  - Use MVVM architecture with SwiftUI
  - Structure: Features/, Core/, UI/, Resources/
  - Follow Apple's Human Interface Guidelines

  
  # Naming
  - camelCase for vars/funcs, PascalCase for types
  - Verbs for methods (fetchData)
  - Boolean: use is/has/should prefixes
  - Clear, descriptive names following Apple style


  # Swift Best Practices

  - Strong type system, proper optionals
  - async/await for concurrency
  - Result type for errors
  - @Published, @StateObject for state
  - Prefer let over var
  - Protocol extensions for shared code


  # UI Development

  - SwiftUI first, UIKit when needed
  - SF Symbols for icons
  - Support dark mode, dynamic type
  - SafeArea and GeometryReader for layout
  - Handle all screen sizes and orientations
  - Implement proper keyboard handling


  # Performance

  - Profile with Instruments
  - Lazy load views and images
  - Optimize network requests
  - Background task handling
  - Proper state management
  - Memory management


  # Data & State

  - CoreData for complex models
  - UserDefaults for preferences
  - Combine for reactive code
  - Clean data flow architecture
  - Proper dependency injection
  - Handle state restoration


  # Security

  - Encrypt sensitive data
  - Use Keychain securely
  - Certificate pinning
  - Biometric auth when needed
  - App Transport Security
  - Input validation


  # Testing & Quality

  - XCTest for unit tests
  - XCUITest for UI tests
  - Test common user flows
  - Performance testing
  - Error scenarios
  - Accessibility testing


  # Essential Features

  - Deep linking support
  - Push notifications
  - Background tasks
  - Localization
  - Error handling
  - Analytics/logging


  # Development Process

  - Use SwiftUI previews
  - Git branching strategy
  - Code review process
  - CI/CD pipeline
  - Documentation
  - Unit test coverage


  # App Store Guidelines

  - Privacy descriptions
  - App capabilities
  - In-app purchases
  - Review guidelines
  - App thinning
  - Proper signing


  Follow Apple's documentation for detailed implementation guidance.
  

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
- ConfigMaps share the same diffable editor pattern as Secrets; populate `config_map_entries` when adding new fetchers so the detail sheet can render values and compute diffs.

## Recently Shipped
- Lens-style sidebar regrouping that mirrors Lens (Workloads/Config/Network/Storage) with collapsible categories, dedicated subtabs, and fixed-width lists; storage now splits PVCs, PVs, and storage classes.
- Global quick search (`⌘K`) with keyboard navigation, namespace filter, and jump-to focus that syncs the center panel and inspector.
- Advanced list filtering with status chips, label selectors, and persisted sort preferences across workloads, pods, nodes, and config resources.
- RBAC-aware UI actions across pods, config resources, secrets, services, and PVCs (tooltips surface `kubectl auth can-i --reason` output).
- Inline event badges and consolidated timelines in pod/workload inspectors, plus embedded exec/log panes replacing modal sheets.
- Enhanced rollout visuals with chart overlays, status change markers, and pod topology highlighting tied to rollout health.
- Networking insights: endpoint health badges in lists/inspectors, ingress route visualizations, and a live port-forward dashboard scoped to the current cluster.
- Telemetry pipeline emitting rollout, service health, and port-forward events to a JSONL log for external dashboards.

## Upcoming Feature Milestones
1. Storage & RBAC coverage – wire real data and inspectors into the new PV/StorageClass tabs plus broaden RBAC-aware controls for cluster-scoped resources and CRDs.
2. Cluster overview metrics – integrate Prometheus queries with selectable ranges and baseline comparisons.
3. Extension hooks – define an extension manifest and sandboxed API for custom panels/actions.
- Node and workload tables include toolbar sort menus (name, age, readiness, etc.); default to `Name ↑` and preserve namespace filter interaction when extending columns.
