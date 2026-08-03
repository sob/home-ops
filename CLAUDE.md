# Claude Assistant Context for home-ops Repository

## Key Infrastructure Details

- **Cluster**: Single cluster running Talos Linux on bare metal Intel NUC devices
- **Nodes**: 3 control plane nodes, 4 worker nodes (10.1.1.x subnet)
- **Storage**: Rook-Ceph for persistent storage — storage classes `ceph-block` (default) and `ceph-filesystem` (OpenEBS has been removed)
- **Networking**: Cilium CNI. Production L7 is **Envoy Gateway** — internal gateway `10.1.100.200`, external `10.1.100.201`. External path is Cloudflare Tunnel → cloudflared → gateway service. Authentik forward-auth runs as an Envoy `SecurityPolicy` ext-auth (ingress-nginx has been removed).
- **DNS**: Blocky for internal DNS, external-dns for managing records
- **Secrets**: External-secrets with OnePassword, SOPS for sensitive data
- **Domain**: 56kbps.io (using Cloudflare for external access)
- **Backup**: Volsync with Restic to Cloudflare R2

## Working Guidelines

### Git Workflow

1. Always check current status before making changes
2. Make atomic commits with clear messages following conventional commits format
3. Never commit secrets or sensitive data
4. Test changes locally when possible before pushing
5. Never use git add -A, select your files carefully when committing

### Kubernetes Operations

1. Use `task` commands when available (e.g., `task flux:hr APP=appname`)
2. Use `existingClaim` for PVCs when they already exist

### Common Tasks & Commands

- **Reconcile app**: `task flux:hr APP=<app-name>`
- **Force flux sync**: `task flux:ks APP=cluster-apps`

### Known Issues & Workarounds

1. **App-template 4.2.0 PVC naming bug**: When using multiple persistence entries with existingClaim, add `suffix: name` to force correct PVC naming
2. **HTTPRoute for internal/external access**: Attach to both gateways for split-horizon DNS
3. **Volsync components**: Create PVCs that may conflict with app-template generated PVCs
4. **Renovate**: Should group bootstrap/helmfile.yaml updates with kubernetes/apps/ manifests
5. **Cilium LoadBalancer IP conflicts**: Avoid hardcoding IPs with `io.cilium/lb-ipam-ips` annotation unless necessary - let Cilium manage IP allocation
6. **SNMP metric unit conversions**: CyberPower devices report voltage in decivolts (e.g., 1130 = 113.0V) - divide by 10 for correct display

### Validation & Testing

- YAML lint and schema validation produce warnings only (non-blocking)
- Critical checks: kustomize-build, kubeconform, flux-local-test
- Run `task validate` before pushing major changes
- Check GitHub Actions workflow status after pushing

### External Services Integration

- **Cloudflare**: Tunnels for external access, R2 for backups
- **GitHub**: Renovate for dependency updates, Actions for CI/CD
- **OnePassword**: External secrets backend
- **NFS**: Media storage at 10.1.100.254

## Response Style Preferences

- Be concise and direct - avoid unnecessary explanations
- Show commands and their output
- Explain "why" only when the reasoning isn't obvious
- Use tool calls efficiently - batch operations when possible
- Don't create new files unless absolutely necessary
- Follow existing patterns and conventions in the codebase

Remember: This is a production homelab - stability and reliability are important, but it's also a learning environment where we can experiment with new technologies and approaches.
