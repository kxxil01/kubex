# Kubex MVP 1

## Features
- List kubeconfig contexts with cluster metadata; connect/disconnect per context
- Lazy namespace/workload/pod/event loading on demand
- Pod log streaming, exec shells, and port-forward management
- Menu bar status for active context and tunnels

## Shortcomings
- GKE credential plugins (`gke-gcloud-auth-plugin`) must be on PATH; automatic detection may still miss custom installations.
- Non-GKE resource loading relies on sequential kubectl calls (no watch/caching yet).
- YAML editor is read-only; apply/diff workflows out of scope for MVP1.

## Troubleshooting
- Use `~/Library/Logs/Kubex/kubectl-runner.log` for PATH/plugin diagnostics.
- Run `kubex --env-dump PATH SHELL HOME` (from bundle binary) to inspect runtime env.
- If logs show "gke-gcloud-auth-plugin not found", ensure `gcloud components install gke-gcloud-auth-plugin` and restart Kubex.
