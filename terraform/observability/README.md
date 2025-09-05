# Observability

This Terraform module manages observability infrastructure including synthetic monitoring with K6 and application performance dashboards for media services in the Kubernetes cluster.

## Features

- **12 Service Coverage**: Tests Plex, Jellyfin, Sonarr, Radarr, Prowlarr, Lidarr, Readarr, SABnzbd, Tautulli, Jellyseerr, and Overseerr
- **Automated Testing**: Runs k6 tests on schedule (default every 10 minutes, Plex internal every 5)
- **Prometheus Integration**: Exports metrics directly to Prometheus via remote write
- **Grafana Dashboard**: Comprehensive dashboard showing service health, response times, and failures
- **Automatic Cleanup**: Kyverno policies clean up test pods (1 min for success, 30 min for failures)
- **Flexible Configuration**: Each service can have custom test scripts, schedules, and thresholds

## Architecture

1. **CronJobs**: Kubernetes CronJobs trigger test runs on schedule
2. **TestRun CRDs**: K6 Operator manages test execution via TestRun custom resources
3. **Metrics Export**: K6 exports metrics to Prometheus with service tags
4. **Alerting**: Grafana alerts on failures, slow responses, and stuck tests

## Configuration

### Required Secrets (via 1Password)

The module pulls configuration from 1Password. Required items:

**k6 item** in STONEHEDGES vault:
- `DOMAIN`: Your domain name (e.g., "56kbps.io")

**grafana-cloud item** in STONEHEDGES vault:
- `GRAFANA_URL`: Grafana Cloud URL
- `GRAFANA_CLOUD_TOKEN`: API token
- `GRAFANA_CLOUD_PDC_DATASOURCE_ID`: PDC datasource ID

### Environment Variables

```bash
export TF_VAR_onepassword_account="your-account"
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
```

### Local Overrides (Optional)

Create `terraform.tfvars` for local testing (ignored by git):

```hcl
# Override domain (instead of using 1Password)
domain = "test.example.com"

# Override specific test configurations
k6_tests = {
  plex-internal = {
    schedule = "*/3 * * * *"  # Run every 3 minutes
    # ... see terraform.tfvars.example for full options
  }
}
```

## Usage

### Initial Setup

```bash
terraform init
terraform plan
terraform apply
```

### View Test Status

```bash
# Check running tests
kubectl get pods -n observability -l app=k6

# Check test runs
kubectl get testruns -n observability

# View test logs
kubectl logs -n observability -l app=k6,test_name=overseerr --tail=50
```

### Clean Up Stuck Tests

```bash
# Delete stuck TestRuns
kubectl get testruns -n observability -o json | \
  jq -r '.items[] | select(.status.stage == "started") | .metadata.name' | \
  xargs -r kubectl delete testrun -n observability
```

## Metrics

All metrics are prefixed with `k6_` and tagged with `service`:

- `k6_checks_rate{service="..."}` - Test check success rate (0-1)
- `k6_http_req_duration_seconds` - Response time histogram
- `k6_http_reqs_total{status="..."}` - HTTP requests by status code
- `k6_http_req_failed` - Failed request rate
- `k6_iterations_total` - Test iteration count
- `k6_data_sent_bytes_total` - Used to detect active tests

## Dashboard Panels

The Grafana dashboard includes:
- Overall check success rate
- Services tested count
- Active test runs
- Test iterations
- Service availability bar gauge
- Response time trends
- HTTP failure rates
- Failed request details table

## Alerts

Configured in `../alerting/rules_synthetic.tf`:

- **SyntheticServiceDown**: Service < 95% success rate (10m)
- **CriticalServiceDown**: Critical service < 90% success (5m)
- **ServiceSlowResponse**: P95 response > 3000ms (15m)
- **ServiceHTTPFailures**: > 10% HTTP failures (10m)
- **SyntheticTestsMissing**: No tests running (20m)
- **SyntheticTestStuck**: > 5 concurrent tests (5m)

## Test Scripts

### Base Media Test (`tests/base-media.js`)
Generic test that all services use:
- Health endpoint check (default: `/`)
- API endpoint check (default: `/api/v1/status`)
- Configurable via environment variables
- Supports API key authentication
- Exits with error on threshold failures

### Custom Tests
- `plex-internal.js`: Direct LoadBalancer access
- `plex-external.js`: Cloudflare tunnel access

## Adding New Services

1. Create test configuration in `tests.tf`:

```hcl
new-service = {
  script   = file("${path.module}/tests/base-media.js")
  schedule = "*/10 * * * *"
  env_vars = {
    SERVICE_NAME = "new-service"
    SERVICE_URL  = "https://new-service.${local.test_domain}"
    API_ENDPOINT = "/api/health"  # Optional overrides
  }
  secret_env_vars = {}
  resources = local.default_resources
}
```

2. Add to alerting in `../alerting/rules_synthetic.tf`:

```hcl
locals {
  synthetic_services = [
    # ... existing services
    "new-service"
  ]
}
```

## Troubleshooting

### Tests Not Running
- Check CronJob status: `kubectl get cronjobs -n observability`
- Look for stuck TestRuns (see cleanup command above)

### No Metrics in Dashboard
- Verify PDC connection: `kubectl logs -n observability deployment/grafana-pdc`
- Check k6 logs for remote write errors

### Test Failures
- Failed pods kept for 30 minutes for debugging
- Check logs: `kubectl logs -n observability <failed-pod>`
- Verify service endpoints are accessible

## File Structure

```
terraform/observability/
├── .gitignore                 # Excludes sensitive tfvars
├── terraform.tfvars.example   # Configuration template
├── variables.tf               # Variable definitions
├── main.tf                    # Core k6 infrastructure
├── tests.tf                   # Service test configurations
├── dashboard_synthetic.tf     # Synthetic monitoring dashboard
├── dashboard_media.tf         # Media application dashboards
├── externalsecret.tf          # Kubernetes secrets
├── README.md                  # This documentation
├── tests/                     # Test scripts
│   ├── base-media.js         # Generic service test
│   ├── plex-internal.js      # Plex internal test
│   └── plex-external.js      # Plex external test
└── dashboards/
    ├── synthetic.json         # Synthetic monitoring dashboard
    └── media-services.json   # Media services dashboard
```

---

# ALERT TESTING FRAMEWORK

## Problem Statement
We need to test that our Grafana alert notifications are working correctly, specifically:

1. **Template Processing** - Verify Grafana's template engine processes our notification templates correctly
2. **RESOLVED Prefix** - Confirm that resolved alerts show `✅ RESOLVED:` prefix via template logic  
3. **Variable Substitution** - Ensure `{{ $value }}` shows actual metric values instead of template code
4. **Real Metric Values** - Test with actual current metrics, not simulated data
5. **New Messages** - Each test should create fresh notifications, not reuse existing ones

## Why We Can't Use Other Approaches

### ❌ Webhook Bypass
- **Problem**: Bypasses Grafana's template engine entirely
- **Issue**: Doesn't test the actual notification pipeline we're using in production

### ❌ Grafana API Endpoints  
- **Problem**: Contact point test APIs return 404/500 errors
- **Issue**: Grafana Cloud may not expose these endpoints or requires different authentication

### ❌ Separate Test Alerts
- **Problem**: Duplicate logic maintenance  
- **Issue**: If we change alert logic, we have to update it in two places (violates DRY)

## Proposed Solution: Single-Condition Manual Trigger

### Concept
Modify existing alert conditions to include an OR clause that can be manually triggered:

```hcl
# Original condition:
expr = "(avg(avg_over_time(k6_checks_rate{service=\"jellyseerr\"}[10m])) * 100) < 95"

# Modified condition:
expr = "((avg(avg_over_time(k6_checks_rate{service=\"jellyseerr\"}[10m])) * 100) < 95) or (vector(1) and on() kube_pod_labels{pod=\"test-trigger-jellyseerr\"})"
```

### How It Works
1. **Fire Alert**: `kubectl run test-trigger-jellyseerr --image=nginx --restart=Never`
   - Alert fires immediately using current real metric values
   - Notification shows actual success rate (e.g., "success rate: 97%")
   - Goes through Grafana's complete template system

2. **Resolve Alert**: `kubectl delete pod test-trigger-jellyseerr`  
   - Assuming real metrics are healthy (≥95%), alert resolves
   - Notification shows "✅ RESOLVED:" prefix via template
   - Tests the complete resolved notification flow

### Benefits
- ✅ **Real Data**: Uses actual current metrics for notification values
- ✅ **Template Testing**: Goes through Grafana's actual template engine
- ✅ **Single Source**: No duplicate alert logic to maintain
- ✅ **Complete Cycle**: Tests both firing and resolved states
- ✅ **RESOLVED Prefix**: Verifies `{{ if eq .Status "resolved" }}✅ RESOLVED:` works

## Current Alert Inventory
- **3 alert types** × **12 services** = **36 total alerts**
- Services: jellyfin, jellyseerr, lidarr, overseerr, plex-external, plex-internal, prowlarr, radarr, readarr, sabnzbd, sonarr, tautulli
- Alert types: SyntheticTestsFailing, SyntheticTestsNotRunning, SyntheticSlowResponse

## Implementation Plan

### Phase 1: Single Alert Test
1. Modify `SyntheticTestsFailing-jellyseerr` alert to include trigger condition
2. Test manually:
   ```bash
   # Fire alert with real current metrics
   kubectl run test-trigger-jellyseerr --image=nginx --restart=Never
   
   # Wait for Slack notification, verify it shows real values
   # Verify template processing works correctly
   
   # Resolve alert  
   kubectl delete pod test-trigger-jellyseerr
   
   # Wait for resolved notification with "✅ RESOLVED:" prefix
   ```

### Phase 2: Task Automation
Create `task alerting:test:trigger ALERT=SyntheticTestsFailing-jellyseerr` that:
- Creates trigger pod
- Waits for alert to fire  
- Deletes trigger pod
- Waits for alert to resolve
- Provides status feedback

### Phase 3: Rollout (if successful)
- Extend trigger logic to all 36 alerts
- Create comprehensive testing tasks
- Document testing procedures

## Key Template Changes Already Applied
- Fixed `{{ $values.A.Value }}` → `{{ $value }}` for proper variable substitution
- Added RESOLVED prefix logic: `{{ if eq .Status "resolved" }}✅ RESOLVED: {{ else }}🚨 {{ end }}`

## Next Steps
1. Implement Phase 1 with jellyseerr alert
2. Test manually to verify approach works  
3. Create automated task for testing
4. Expand to other alerts if successful