# Kubex Agent Guidance

## Vision
Kubex is a native macOS Kubernetes explorer that helps operators understand and act on cluster state quickly.

## Core Pillars
- **Clarity first**: Always present resources and actions in context, minimizing modal dialogs and extra clicks.
- **Safe operations**: Favor read-only previews, diffing, and confirmations before mutating cluster state.
- **Mac-native UX**: Use familiar macOS patterns—split views, command palette, menu bar extras, and system sharing.
- **Extensibility**: Design with plugins/hooks for custom resource types, auth providers, and automation scripts.

## MVP Feature Set
1. **Cluster Browser**
   - List kubeconfig contexts, connect, and show namespaces, workloads (Deployments, StatefulSets, DaemonSets), Services, and Nodes in a sidebar tree.
   - Detail pane with tabs: Overview (labels, annotations, status), Pods list, Events, YAML.
2. **Live Resource Inspector**
   - Stream pod logs with filtering (containers, timestamps, search).
   - Interactive shell (`kubectl exec`), with copy/paste and history.
   - One-click port-forward for services and pods, showing active tunnels.
3. **YAML Workspace**
   - Built-in editor with syntax highlighting, Kubernetes schema validation, autocomplete from cluster.
   - Change diff viewer against live object; apply/rollback with undo history.
   - Snippets library for common manifests (e.g., CronJob, Ingress).
4. **Health Dashboard**
   - Aggregate cluster/node health, deployment rollout status, and warnings.
   - Visual topology graph linking Services ⇄ Pods ⇄ Nodes.
   - Alert center surfacing recent events, failing probes, pending pods.
5. **Saved Workflows**
   - Record and replay sequences: e.g., “Tail logs for deployment X in namespace Y and open shell to pod Z”.
   - Quick action buttons assignable to keyboard shortcuts or Touch Bar.

## Supporting Features & Integrations
- Menu bar mini-monitor showing active context, problematic workloads count, and quick-switch menu.
- Spotlight-style command palette (⌘K) for resource search and actions.
- Contextual actions: right-click in tables to scale deployments, restart pods, edit config maps.
- Support for port-forward sharing via macOS share sheet (copy URL, open in browser).
- Secure keychain storage for cluster tokens; integrate with SSO (OIDC) flows.

## Technical Foundation
- Language: Swift + SwiftUI for main app; Combine for reactive data flows.
- Kubernetes API client: Leverage `SwiftKubernetesClient` or wrap `kubectl` fallback where API missing.
- Use background workers for polling/watch streams; ensure main thread updates via publishers.
- Persist user preferences and workflows via `UserDefaults` + JSON files in `~/Library/Application Support/Kubex`.
- Modular architecture: Core modules for ClusterService, ResourceStore, YAMLService, WorkflowEngine.

## UX Guidelines
- Default to light/dark mode parity; respect system accessibility (VoiceOver labels, Dynamic Type where possible).
- Offer onboarding flow to import kubeconfig and select default context.
- Provide undo/redo for destructive actions; surface confirmation dialogs with resource diffs.

## Future Extensions (Keep in mind)
- Multi-user collaboration (share workflow bundles). 
- Policy validation (OPA, Kyverno) before apply. 
- AI assistant for generating manifests and interpreting events.

Keep this document updated as requirements evolve.

## Current Implementation Snapshot
- Swift Package Manager executable targeting macOS 14 with SwiftUI app entry (`KubexApp`).
- NavigationSplitView layout: sidebar clusters, namespace list, and tabbed detail pane.
- kubectl-backed services for contexts, workloads, logs, exec, and port-forward replace mock defaults (graceful alert on failure).
- Cluster detail toolbar exposes Tail Logs, Port Forward, and Open Shell; new sheets stream kubectl output in-app.
- Menu bar extra lists active port-forwards with inline stop control.
- Scripts/package_app.sh wraps the release binary into `Kubex.app` for manual testing.
- kubectl services fall back to ~/.kube/config when no explicit kubeconfig path is provided.
- Kubectl runner now augments PATH with standard install locations and surfaces a clear error when the binary is missing.
- Unreachable clusters now surface as `unreachable` health with captured kubectl errors instead of failing the entire refresh.
- Clusters load in a disconnected state; explicit connect/disconnect fetches/tears down live data for one context at a time.
- Cluster names default to kubeconfig cluster entries (contexts still shown beneath).
- Connection failures now bubble sanitized guidance (e.g., missing gke-gcloud-auth-plugin) rather than raw kubectl spam.
- PATH bootstrap includes common Google Cloud SDK locations so kubectl auth plugins (e.g., gke-gcloud-auth-plugin) resolve when launched via the app.
- Connecting fetches the namespace list instantly; detailed workloads/pods/events load lazily when a namespace is opened.
- `~/Library/Logs/Kubex/kubectl-runner.log` captures PATH resolution, detected plugins, and kubectl invocations for debugging credentials.

## Near-Term Integration Notes
- Cache kubectl responses and surface loading states to avoid sequential round-trips per refresh.
- Persist user preferences for selected cluster/namespace and saved port-forwards.
- Expand YAML editor to fetch/apply manifests via the new kubectl bindings with diff previews.



## Known Issues
- GKE credential plugin detection still relying on PATH; verify `gke-gcloud-auth-plugin` availability when connecting to GKE contexts.
