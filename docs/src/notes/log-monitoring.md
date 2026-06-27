# Log Monitoring & Daily Health Review

A unified, cheap log pipeline for container, Talos host, and network/syslog
logs — with a self-hosted single pane of glass and a daily Claude health digest.

## Goals

- Aggregate **container logs**, **Talos host logs**, and **network/device syslog**
  into one place.
- Keep storage cheap: every log byte lands in **Cloudflare R2**, not replicated Ceph.
- **Single pane of glass** is self-hosted (free); **Grafana Cloud is used only for
  off-cluster alerting** (the "is the homelab reachable from outside" safety net).
- A **daily Claude Code routine** analyses the last 24h and posts a health digest.

## Architecture

```
 Container logs ─► Alloy/Promtail ─┐
 Talos host logs (machine.logging) ─► Vector log-edge ─┤
 UniFi / Synology / UPS·PDU / printers (syslog) ─────► │─► Loki ─► R2 (chunks, cheap)
                                       (parse/drop/                 │
                                        log→metric)                 ├─► index cache on Ceph (20Gi)
                                                                    │
 Self-hosted Grafana (single pane) ◄── Prometheus + Loki datasources┘
 Grafana Cloud  ◄── Alloy (metrics only) ── used ONLY for off-cluster alerting
 Daily Claude CronJob ──LogQL+PromQL──► markdown digest ─► Slack (+Pushover if CRITICAL)
```

## Components

| Component | Path | Role |
|---|---|---|
| Loki (R2 backend) | `kubernetes/apps/observability/loki` | Log store; chunks/ruler in R2 bucket `loki-logs` |
| Vector log-edge | `kubernetes/apps/observability/vector-aggregator` | Syslog + Talos json receiver (LoadBalancer `10.1.100.210`) |
| Talos logging | `talos/machineconfig.yaml.j2` | Ships kernel/service logs to the edge |
| Grafana (self-hosted) | `kube-prometheus-stack` HelmRelease | Single pane; dashboards `Logs — Overview`, `Network & Syslog` |
| Network/log alerts | `kube-prometheus-stack/app/rules/network-health.yaml`, `log-pipeline-health.yaml`, `loki/app/rules.yaml` | In-cluster alerts |
| Off-cluster safety net | `terraform/alerting/rules_network.tf` | Grafana Cloud dead-man's-switch alerts |
| Daily Claude review | `kubernetes/apps/observability/health-review` | CronJob → Slack digest |

## Storage & retention (cost control)

- Loki default retention **30d** (`retention_period: 720h`); chunks always live in R2.
- "Cold" tier ~**270d** for high-value streams via `retention_stream`:
  `source=talos|unifi|synology|network` and `namespace=kube-system|flux-system|security`.
- Vector drops health-check/probe noise and emits `vector_log_events_total` so
  dashboards/alerts query cheap metrics instead of scanning logs.
- Ceph PVC shrunk to **20Gi** (index cache/WAL only).

## Syslog source ports (point devices here → `10.1.100.210`)

| Source | Protocol / Port |
|---|---|
| Generic syslog (UniFi, UPS/PDU, IoT) | UDP **514** / TCP **514** |
| RFC5424 (Synology, printers) | TCP **601** |
| Talos host logs (json_lines) | UDP **5170** (auto-configured via machineconfig) |

Configure UniFi (Settings → System → Remote Logging), Synology (Log Center →
syslog), CyberPower, and printers to send to `10.1.100.210`.

## Network-device analysis & alerting recommendations

Current monitoring is metric-rich but had **no log/syslog visibility** and several
metric-alert gaps. Added/recommended:

- **UniFi** (unpoller + new syslog): poller-down, device-offline, switch port RX
  errors; syslog-driven firewall/IDS spikes, repeated auth failures.
  *Tune `unpoller_*` metric names to your unpoller version.*
- **Talos hosts** (new host logs): kernel/hardware errors (I/O, EXT4/XFS, MCE,
  NIC link-down), flapping services.
- **Synology ×2**: SNMP-down alert; syslog volume/disk/SMART/scrub errors.
- **CyberPower UPS**: estimated-runtime-low (complements existing on-battery/low-
  capacity/overload rules in `terraform/alerting/rules_power.tf`).
- **WAN/speedtest**: download/upload degraded, latency high.
- **Log pipeline self-health**: Loki down, Vector down, ingest stalled, R2 flush
  failures.
- **Off-cluster (Grafana Cloud)**: metrics-forwarding-down and all-nodes-unreachable
  dead-man's switches.

## Required 1Password items

Create these in the `STONEHEDGES` vault (referenced by ExternalSecrets):

| Item | Fields |
|---|---|
| `cloudflare` *(existing)* | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `CLOUDFLARE_R2_ACCOUNT_ID` — reused by Loki |
| `grafana` *(new)* | `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD` |
| `claude-health` *(new)* | `ANTHROPIC_API_KEY`, `SLACK_WEBHOOK_URL`, `PUSHOVER_TOKEN`, `PUSHOVER_USER` |

Also create the **`loki-logs`** bucket in Cloudflare R2 (same account as the
existing `kube-prometheus-stack` Thanos bucket).

## Apply / rollout

1. Create the 1Password items and the `loki-logs` R2 bucket (above).
2. Merge the PR; Flux reconciles the observability namespace.
3. **Apply the Talos change** (host log shipping) — regenerate and apply machine
   config to each node, e.g. `task talos:apply-node IP=10.1.100.10x` (or your
   existing talhelper/talosctl workflow). This is required for `source=talos`
   logs to flow.
4. Point network devices' remote-syslog at `10.1.100.210` (see ports above).
5. Visit `https://grafana.${SECRET_DOMAIN}` and confirm the Logs and
   Network & Syslog dashboards populate.

## Follow-ups (intentionally deferred)

- **Thanos Query + Store Gateway** to read the long-term metrics already in R2
  (today the sidecar only writes). Local Prometheus retention was bumped to 48h
  so the pane/daily-job have a window; add Thanos Query for >48h history in Grafana.
- Optionally retire **Promtail** into Alloy to consolidate container-log collection.
