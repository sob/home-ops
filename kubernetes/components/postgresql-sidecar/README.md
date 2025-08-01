# PostgreSQL Sidecar Component

This component adds PostgreSQL as a sidecar container to any app-template based application.

## Features

- PostgreSQL runs as a sidecar container in the same pod as your app
- Database accessible at `localhost:5432` (no network hops)
- Automatic database initialization via init container
- Dedicated PVC for PostgreSQL data
- Simple backup via volume snapshots

## Usage

In your app's `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./helmrelease.yaml
  - ./externalsecret.yaml

components:
  - ../../../components/postgresql-sidecar

replacements:
  - targets:
      - select:
          kind: HelmRelease
      - select:
          kind: ExternalSecret
    source:
      kind: ConfigMap
      name: required-for-kustomize-but-not-used
      fieldPath: metadata.name
    options:
      delimiter: '-'
      index: 0
```

## Requirements

Your 1Password item must contain:
- `${APP}_POSTGRES_USER` - PostgreSQL username
- `${APP}_POSTGRES_PASS` - PostgreSQL password  
- `${APP}_POSTGRES_NAME` - Database name

## What It Does

1. Adds a PostgreSQL container to your main pod
2. Creates a PVC for PostgreSQL data (8Gi default)
3. Configures init container to create database if needed
4. PostgreSQL accessible at `localhost:5432` within the pod

## Database Connection

Since PostgreSQL runs as a sidecar, your app connects to:
- Host: `localhost` or `127.0.0.1`
- Port: `5432`
- Database: Value from `${APP}_POSTGRES_NAME`
- Username: Value from `${APP}_POSTGRES_USER`
- Password: Value from `${APP}_POSTGRES_PASS`

## Example App Configuration

```yaml
containers:
  app:
    image:
      repository: ghcr.io/your-app/image
      tag: latest
    env:
      DATABASE_URL: "postgresql://$(INIT_POSTGRES_USER):$(INIT_POSTGRES_PASS)@localhost:5432/$(INIT_POSTGRES_DBNAME)"
    envFrom:
      - secretRef:
          name: ${APP}-db-secret
```

## Resource Sizing

Default resources are sized for small databases (like *arr apps):
- **CPU**: 10m request, 500m limit
- **Memory**: 128Mi request, 512Mi limit  
- **Storage**: 8Gi

For larger databases, override in your HelmRelease:

```yaml
spec:
  values:
    controllers:
      main:
        containers:
          postgres:
            resources:
              requests:
                memory: 512Mi   # For medium databases
              limits:
                memory: 2Gi     # For medium databases
    persistence:
      postgres-data:
        size: 50Gi  # Larger storage
```

### Sizing Guidelines:
- **Tiny** (default): Personal apps, *arr stack, <100MB data
- **Small**: Home Assistant, small web apps, <1GB data
- **Medium**: Authentik, Nextcloud, 1-10GB data
- **Large**: Use dedicated PostgreSQL, not sidecar

## Pros and Cons

### Pros:
- Simple setup, no separate Helm charts
- Fast local connection (no network latency)
- Pod-level isolation
- Easy to backup (single PVC)

### Cons:
- PostgreSQL lifecycle tied to app pod
- Cannot scale PostgreSQL independently
- Shared resources with app container
- Not suitable for multiple apps sharing a database

## When to Use This

Good for:
- Apps that need dedicated PostgreSQL
- Development/testing environments
- Apps with light database load
- When you want simplicity over flexibility

Not good for:
- High-load database applications
- Multiple apps sharing one database
- When you need PostgreSQL-specific scaling
- Production workloads requiring HA PostgreSQL