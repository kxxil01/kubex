# Kubex

Kubex is a native macOS client for day-to-day Kubernetes operations. The app mirrors the high-level experience of Lens—surfacing cluster metrics, workloads, nodes, networking, and configuration resources—while remaining lightweight and scriptable through Swift Package Manager.

## Key Capabilities
- Multi-kubeconfig support with connection wizard, context switching, and "All Namespaces" aggregation.
- Lens-style inspector for workloads and pods featuring rollout history charts, live logs, YAML editing, and inline port-forward management.
- Fixed-layout resource tables for workloads, nodes, networking, and config objects with filtering and sortable columns.
- Secret management workflow with base64 reveal/edit, RBAC-aware controls, and kubectl apply integration.
- Cluster overview dashboard with sparkline metrics, heatmaps, and rollout annotations sourced from Prometheus-compatible data.

## Requirements
- macOS 13 Ventura or newer (SwiftUI/Charts requirement).
- Xcode 15+ or Swift 5.9 toolchain (Swift Package Manager friendly).
- `kubectl` and (optionally) `helm` available on `PATH`.
- Access to kubeconfig files (default `~/.kube/config` or custom paths via the connection wizard).

## Getting Started
```bash
# clone the repository
$ git clone https://github.com/kxxil01/kubex.git
$ cd kubex

# build & run unit tests
$ swift build
$ swift test
```

### Launching the App
```bash
# Debug run from the command line
$ swift run kubex

# Package as a reusable .app bundle
$ Scripts/build_and_install_app.sh
```
The packaging script removes any existing `/Applications/Kubex.app` before installing the freshly built bundle.

## Repository Layout
- `Sources/kubex/` – SwiftUI macOS client (Views, ViewModels, Services, Models).
- `Tests/kubexTests/` – Swift Testing suites covering metrics, inspector actions, kubectl stubs, and regression scenarios.
- `Scripts/` – Tooling for packaging, telemetry, and developer automation.
- `AGENTS.md` – Contributor guidelines, testing expectations, and design notes.

## Development Tips
- Use the resource toolbar search and sort menus to verify fixed-layout tables render correctly across workloads/nodes/namespaces.
- Run `swift build && swift test` before committing; capture command output in PR notes.
- Secrets, kubeconfigs, and other credentials remain local (`auth.json`, `kubeconfig_*` are gitignored). Audit with `rg -n "(token|secret|password)"` prior to publishing.

## Troubleshooting
- Inspect kubectl runner logs in `~/Library/Logs/Kubex/` for PATH or plugin issues (e.g., GKE auth plugin).
- If Prometheus metrics are unavailable, overview charts fall back to placeholders; confirm the `/stats/summary` endpoint is reachable.
- For RBAC errors, the inspector surfaces inline banners—use `kubectl auth can-i` manually to validate permissions.

Kubex is under active development and aims to track Lens feature parity while embracing native macOS conventions. Contributions and feedback are welcome—consult `AGENTS.md` before opening pull requests.
