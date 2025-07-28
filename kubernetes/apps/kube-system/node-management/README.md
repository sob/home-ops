# Node Management Strategy for Workload Distribution

## Problem Statement
- metal-07 is significantly more powerful than other nodes
- Kubernetes scheduler assigns most pods to metal-07 due to available CPU
- This causes imbalanced workload distribution
- Media workloads that need the power aren't guaranteed to run on metal-07

## Solution Overview
Use a combination of node labels, taints, and pod affinity to ensure:
1. Media workloads run on metal-07
2. Other workloads are distributed across remaining nodes
3. Prevent scheduler from overloading metal-07 with non-critical workloads

## Implementation Strategy

### 1. Node Labeling
Label nodes to identify their roles:
- `node-role.kubernetes.io/media=true` - for metal-07
- `node-role.kubernetes.io/worker=true` - for metal-04, metal-05, metal-06
- metal-01, metal-02, metal-03 are control plane nodes

### 2. Node Taints
Apply taints to metal-07 to prevent non-media workloads:
- Key: `workload-type`
- Value: `media`
- Effect: `NoSchedule`

### 3. Tolerations for Media Workloads
Media workloads will need tolerations:
```yaml
tolerations:
  - key: "workload-type"
    operator: "Equal"
    value: "media"
    effect: "NoSchedule"
```

### 4. Node Affinity for Media Workloads
Ensure media workloads prefer metal-07:
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/media
          operator: In
          values:
          - "true"
```

## Identified Media Workloads
The following workloads should run on metal-07:
- Plex (with Intel GPU support)
- Overseerr
- Tautulli
- Sonarr
- Radarr
- Lidarr
- Readarr
- Prowlarr
- Bazarr
- Sabnzbd
- Unpackerr

## Implementation Steps
1. Apply node labels
2. Apply taint to metal-07
3. Update media workload HelmReleases with tolerations and affinity
4. Monitor and adjust as needed