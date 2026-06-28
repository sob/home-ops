# 1Password & Secret Storage

## Model: SOPS bootstraps 1Password; 1Password does everything else

SOPS holds **only** what's needed to bring the cluster up far enough for
External Secrets + 1Password Connect to run. Once Connect is up, every other
secret comes from 1Password via `ExternalSecret`s.

**SOPS-encrypted (bootstrap-only — must stay):**

| File | Purpose |
|---|---|
| `kubernetes/apps/external-secrets/onepassword-connect/app/onepassword-connect.secret.sops.yaml` | 1Password Connect credentials (the seed) |
| `kubernetes/components/common/sops/sops-age.secret.sops.yaml` | SOPS age key |
| `bootstrap/flux/github-deploy-key.sops.yaml` | Flux git access |

Everything else (cluster substitution vars, cloudflare/cloudflared/cert-manager
tokens, all per-app secrets) is a 1Password `ExternalSecret`.

## Cluster substitution variables (`${SECRET_*}`)

Flux postBuild substitution reads, in order:

1. **`cluster-settings`** — a committed, non-secret **ConfigMap**
   (`kubernetes/components/common/cluster-settings/`) holding **dummy** values.
   This is what CI (which has no 1Password/SOPS) renders against, and a bootstrap
   fallback.
2. **`cluster-secrets`** — the 1Password **ExternalSecret**
   (`kubernetes/components/common/cluster-secrets/`) with the **real** values,
   listed second so it **overrides** the dummies in-cluster.

Real domains/IPs therefore live only in 1Password (out of git); only fake
placeholders are committed.

**Bootstrap seeding.** `bootstrap/resources.yaml.j2` also seeds
`flux-system/cluster-secrets` from the local `op` CLI, so postBuild substitution
has real values from the first bootstrap apply — before onepassword-connect (and
the ExternalSecret) is up. The ExternalSecret adopts/refreshes that Secret once
Connect is running. This closes the brief from-scratch-bootstrap window where
apps would otherwise render against the `cluster-settings` placeholders.

## Required 1Password fields (verify BEFORE merging the SOPS-minimization PR)

Removing the SOPS copies makes 1Password the sole source — these fields must
exist or the consuming app breaks:

**Item `cluster-secrets`** — every referenced `${SECRET_*}`, notably the
newly-added **`SECRET_EXTERNAL_DOMAIN`** (was missing from the ExternalSecret),
plus `SECRET_DOMAIN`, `SECRET_INTERNAL_DOMAIN`, `SECRET_ACME_EMAIL`,
`SECRET_CIDR`, `SECRET_CLOUDFLARE_TUNNEL_ID`, `SECRET_NAS_DOOM/MORDOR`,
`SECRET_NFS_SERVER`, `SECRET_NFS_PATH_MEDIA`, `SECRET_VIP_PLEX/SMTP/ZIGBEE`,
`CILIUM_LB_RANGE_START/END`.

**Item `cloudflare`:**
- `CLOUDFLARE_API_TOKEN` — used by **cert-manager** (new ExternalSecret) and external-dns
- `CLOUDFLARE_EMAIL` — external-dns
- `TUNNEL_ID`, `TUNNEL_CREDENTIALS_JSON` — cloudflared

> The cloudflared / external-dns ExternalSecrets already existed (the deleted
> SOPS files were redundant duplicates), so those fields are almost certainly
> already populated; cert-manager is the only newly-wired consumer.

## CI

`kustomize build` does not run Flux substitution, so `kubeconform` skips
`HTTPRoute` (its `${SECRET_DOMAIN}` hostnames can't pass the strict hostname
schema). `flux-local` substitutes via `cluster-settings` and validates the real
rendered output.
