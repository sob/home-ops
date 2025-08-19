# Bug Report: PVC naming conflict when using existingClaim with multiple persistence entries

## Summary
When defining multiple persistence entries where some use `existingClaim`, the app-template chart incorrectly names newly created PVCs without their identifier suffix, causing naming conflicts.

## Chart Version
- **Chart**: app-template
- **Version**: 4.2.0

## Description of the Bug
The PVC naming logic in `charts/library/common/templates/lib/common/_determineResourceNameFromValues.tpl` only appends the identifier suffix (e.g., `-cache`) when more than one PVC is being **created**. However, it counts only PVCs that will be created (those without `existingClaim`), not the total number of persistence entries.

This causes issues when:
1. You have multiple persistence entries (e.g., `config` and `cache`)
2. Some use `existingClaim` (e.g., `config: existingClaim: my-pvc`)
3. Others create new PVCs (e.g., `cache: type: persistentVolumeClaim`)

In this scenario, only 1 PVC is being created (for `cache`), so the count is 1, and the identifier is not appended. The PVC gets named `<release-name>` instead of `<release-name>-cache`.

## Steps to Reproduce
1. Create a HelmRelease with the following persistence configuration:
```yaml
persistence:
  config:
    existingClaim: my-existing-pvc
    globalMounts:
      - path: /config
  cache:
    type: persistentVolumeClaim
    storageClass: my-storage-class
    accessMode: ReadWriteOnce
    size: 20Gi
    globalMounts:
      - path: /cache
```

2. Deploy the chart
3. Observe that the cache PVC is named `<release-name>` instead of `<release-name>-cache`

## Expected Behavior
The cache PVC should be named `<release-name>-cache` to avoid conflicts with other resources, especially when using components that create PVCs with the base release name.

## Actual Behavior
The cache PVC is named just `<release-name>`, which can conflict with:
- Other PVCs created by Kustomize components
- The expected naming convention when multiple persistence entries exist

## Impact
This bug causes deployment failures when:
- Using Kustomize components that create PVCs with the release name
- The existing PVC has a different storage class than what the chart tries to create
- Results in error: `cannot patch "<name>" with kind PersistentVolumeClaim: PersistentVolumeClaim "<name>" is invalid: spec: Forbidden: spec is immutable after creation`

## Root Cause
In `charts/library/common/templates/lib/pvc/_enabled_pvcs.tpl`, the logic only adds PVCs to the `enabledPVCs` dict if they don't have `existingClaim`:

```go-template
{{- if and $pvcEnabled (eq (default "persistentVolumeClaim" $persistenceItem.type) "persistentVolumeClaim") (not $persistenceItem.existingClaim) -}}
  {{- $_ := set $enabledPVCs $identifier . -}}
{{- end -}}
```

Then in `_determineResourceNameFromValues.tpl`, the naming logic checks the count:
```go-template
{{- if or (gt $itemCount 1) ($rootContext.Values.global.alwaysAppendIdentifierToResourceName) -}}
  {{- $objectName = printf "%s-%s" $objectName $identifier -}}
{{- end -}}
```

Since only created PVCs are counted, `$itemCount` is 1 when it should consider all persistence entries.

## Workaround
Users can work around this issue by:
1. Setting `global.alwaysAppendIdentifierToResourceName: true`
2. Using `suffix: <name>` on the persistence entry
3. Using `forceRename: "{{ .Release.Name }}-<name>"` on the persistence entry

## Proposed Fix
The fix involves counting all PVC-type persistence entries, not just ones being created. See the attached patch file for the implementation.

## Test Case
```yaml
# This configuration should create a PVC named "myapp-cache", not "myapp"
persistence:
  config:
    existingClaim: myapp-config
  cache:
    type: persistentVolumeClaim
    size: 10Gi
```

## Environment
- Kubernetes version: 1.31.0
- Helm version: 3.x
- Using Flux CD with Kustomize components

## Additional Context
This issue was discovered when using volsync Kustomize component which creates a PVC with the release name, conflicting with the incorrectly named cache PVC.