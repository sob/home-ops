# GitHub Workflows & Validation

This repository uses comprehensive validation to ensure changes don't break the cluster or expose secrets.

## Overview

All pull requests that modify files in the `kubernetes/` directory will trigger automated validation checks that must pass before merging.

## Validation Checks

### 1. **YAML Lint** ✅
- Validates YAML syntax and formatting
- Enforces consistent style across all files
- Configuration: `.yamllint.yaml`

### 2. **Secret Scanning** 🔒
- **Gitleaks**: Scans for secrets in code
- **TruffleHog**: Verifies no credentials are exposed
- Automatic PR comments if secrets are found

### 3. **Kustomize Build** 🏗️
- Builds all kustomizations to ensure they're valid
- Validates that all referenced files exist
- Checks component references

### 4. **Kubeconform** ☸️
- Validates Kubernetes manifests against schemas
- Checks CRD compatibility
- Ensures resources follow Kubernetes API specifications

### 5. **Flux Local Test** 🔄
- Validates Flux configurations
- Tests HelmRelease and Kustomization resources
- Verifies source references

### 6. **Flux Local Diff** 📊
- Shows what changes will be applied to the cluster
- Generates PR comments with diffs
- Helps reviewers understand impact

### 7. **Helm Values Validation** ⎯
- Validates HelmRelease values
- Checks for syntax errors in helm-values.yaml files

### 8. **OPA Policies** 📋
- Enforces organizational standards:
  - Resource limits and requests required
  - Security contexts mandatory
  - No :latest tags
  - Media workloads need node affinity
  - Volsync apps need UID/GID configuration

### 9. **Dependency Check** 🔗
- Validates all Flux dependencies exist
- Prevents broken dependency chains
- Checks for circular dependencies

## Local Validation

### Pre-commit Hooks

Install pre-commit to run validation locally before pushing:

```bash
# Install pre-commit
pip install pre-commit

# Install the git hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

### Manual Validation

```bash
# Validate specific kustomization
kustomize build kubernetes/apps/default/plex/app

# Run kubeconform
kubeconform -strict -ignore-missing-schemas kubernetes/apps/default/plex/app/helmrelease.yaml

# Test with flux-local
flux-local test -p kubernetes/flux/cluster
```

## Common Issues and Fixes

### "Container does not have memory limits set"
Add resource limits to your container:
```yaml
resources:
  requests:
    cpu: 10m
    memory: 128Mi
  limits:
    memory: 256Mi
```

### "HelmRelease does not have remediation settings"
Add remediation configuration:
```yaml
spec:
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      strategy: rollback
      retries: 3
```

### "File may contain unencrypted secrets"
Use SOPS encryption or ExternalSecrets instead of plain text secrets.

### "Kustomization uses volsync but doesn't set VOLSYNC_UID"
Add UID/GID to postBuild substitutions:
```yaml
postBuild:
  substitute:
    APP: *app
    VOLSYNC_UID: "1000"
    VOLSYNC_GID: "1000"
    VOLSYNC_FSGROUP: "1000"
```

## Workflow Configuration

The validation workflow is defined in `.github/workflows/validate-pr.yaml`.

Key features:
- Runs on all PRs to main branch
- Parallel job execution for speed
- Clear error messages with file locations
- Automatic PR comments for diffs

## Adding New Validation

1. **OPA Policies**: Edit `.github/policies/kubernetes.rego`
2. **Pre-commit Hooks**: Update `.pre-commit-config.yaml`
3. **Workflow Jobs**: Add to `.github/workflows/validate-pr.yaml`

## Bypassing Checks (Emergency Only)

In rare cases where you need to bypass a check:

1. **OPA Policies**: Add annotation `home-ops/allow-root: "true"` for root containers
2. **Resource Limits**: Use `home-ops/skip-resource-validation: "true"`

⚠️ **Use sparingly and document why the bypass is necessary**