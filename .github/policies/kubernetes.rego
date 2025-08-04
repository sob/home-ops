package kubernetes.validation

import rego.v1

# Deny containers without resource limits
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container '%s' in Deployment '%s' does not have memory limits set", [container.name, input.metadata.name])
}

deny contains msg if {
    input.kind == "StatefulSet"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container '%s' in StatefulSet '%s' does not have memory limits set", [container.name, input.metadata.name])
}

# Deny containers without resource requests
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests.memory
    msg := sprintf("Container '%s' in Deployment '%s' does not have memory requests set", [container.name, input.metadata.name])
}

deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests.cpu
    msg := sprintf("Container '%s' in Deployment '%s' does not have CPU requests set", [container.name, input.metadata.name])
}

# Deny containers running as root (unless explicitly allowed)
deny contains msg if {
    input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
    input.metadata.annotations["home-ops/allow-root"] != "true"
    container := input.spec.template.spec.containers[_]
    container.securityContext.runAsUser == 0
    msg := sprintf("Container '%s' in %s '%s' runs as root (UID 0)", [container.name, input.kind, input.metadata.name])
}

# Deny containers without security context
deny contains msg if {
    input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
    not input.spec.template.spec.securityContext
    msg := sprintf("%s '%s' does not have a pod security context", [input.kind, input.metadata.name])
}

# Warn about missing liveness probes for main containers
warn contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.name in ["app", "main", input.metadata.name]
    not container.livenessProbe
    msg := sprintf("Container '%s' in Deployment '%s' does not have a liveness probe", [container.name, input.metadata.name])
}

# Deny HelmRelease without remediation settings
deny contains msg if {
    input.kind == "HelmRelease"
    not input.spec.install.remediation
    msg := sprintf("HelmRelease '%s' does not have install remediation settings", [input.metadata.name])
}

deny contains msg if {
    input.kind == "HelmRelease"
    not input.spec.upgrade.remediation
    msg := sprintf("HelmRelease '%s' does not have upgrade remediation settings", [input.metadata.name])
}

# Deny PersistentVolumeClaim without storage class
deny contains msg if {
    input.kind == "PersistentVolumeClaim"
    not input.spec.storageClassName
    msg := sprintf("PVC '%s' does not specify a storage class", [input.metadata.name])
}

# Validate Flux Kustomization dependencies exist
deny contains msg if {
    input.kind == "Kustomization"
    input.apiVersion == "kustomize.toolkit.fluxcd.io/v1"
    dep := input.spec.dependsOn[_]
    # This would need to be enhanced with actual dependency checking
    msg := sprintf("Kustomization '%s' has dependency on '%s' - verify it exists", [input.metadata.name, dep.name])
}

# Ensure postBuild substitutions use proper format
deny contains msg if {
    input.kind == "Kustomization"
    input.apiVersion == "kustomize.toolkit.fluxcd.io/v1"
    key := input.spec.postBuild.substitute[k]
    not regex.match("^[A-Z][A-Z0-9_]*$", k)
    msg := sprintf("Kustomization '%s' has invalid substitution key '%s' - use UPPER_SNAKE_CASE", [input.metadata.name, k])
}

# Validate container image tags
deny contains msg if {
    input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
    container := input.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%s' in %s '%s' uses ':latest' tag", [container.name, input.kind, input.metadata.name])
}

# Ensure media workloads have proper node affinity
deny contains msg if {
    input.kind in ["Deployment", "StatefulSet"]
    input.metadata.namespace == "default"
    input.metadata.name in ["plex", "jellyfin", "emby", "bazarr", "lidarr", "radarr", "readarr", "sonarr"]
    not input.spec.template.spec.affinity.nodeAffinity
    msg := sprintf("Media workload %s '%s' does not have node affinity configured", [input.kind, input.metadata.name])
}

# Ensure volsync-enabled apps have proper UIDs set
warn contains msg if {
    input.kind == "Kustomization"
    input.apiVersion == "kustomize.toolkit.fluxcd.io/v1"
    "volsync" in input.spec.components[_]
    not input.spec.postBuild.substitute.VOLSYNC_UID
    msg := sprintf("Kustomization '%s' uses volsync but doesn't set VOLSYNC_UID", [input.metadata.name])
}

# HelmRelease validations

# Ensure HelmRelease has interval set
deny contains msg if {
    input.kind == "HelmRelease"
    not input.spec.interval
    msg := sprintf("HelmRelease '%s' does not have interval set", [input.metadata.name])
}

# Warn if HelmRelease interval is too short
warn contains msg if {
    input.kind == "HelmRelease"
    input.spec.interval
    # Extract number from interval (e.g., "5m" -> 5)
    interval_match := regex.match("^([0-9]+)(m|h)$", input.spec.interval)
    interval_value := to_number(interval_match[1])
    interval_unit := interval_match[2]
    interval_unit == "m"
    interval_value < 5
    msg := sprintf("HelmRelease '%s' has very short interval '%s' - consider using 5m or longer", [input.metadata.name, input.spec.interval])
}

# Ensure HelmRelease has chart version pinned (not latest)
deny contains msg if {
    input.kind == "HelmRelease"
    not input.spec.chart.spec.version
    msg := sprintf("HelmRelease '%s' does not have chart version pinned", [input.metadata.name])
}

# Ensure HelmRelease has sourceRef
deny contains msg if {
    input.kind == "HelmRelease"
    not input.spec.chart.spec.sourceRef
    msg := sprintf("HelmRelease '%s' does not have chart sourceRef defined", [input.metadata.name])
}

# Ensure HelmRelease sourceRef has namespace
deny contains msg if {
    input.kind == "HelmRelease"
    input.spec.chart.spec.sourceRef
    not input.spec.chart.spec.sourceRef.namespace
    msg := sprintf("HelmRelease '%s' sourceRef does not specify namespace", [input.metadata.name])
}

# Warn if HelmRelease doesn't have retries configured
warn contains msg if {
    input.kind == "HelmRelease"
    not input.spec.install.remediation.retries
    msg := sprintf("HelmRelease '%s' does not have install retries configured", [input.metadata.name])
}

warn contains msg if {
    input.kind == "HelmRelease"
    not input.spec.upgrade.remediation.retries
    msg := sprintf("HelmRelease '%s' does not have upgrade retries configured", [input.metadata.name])
}

# Ensure HelmRelease has proper upgrade strategy
deny contains msg if {
    input.kind == "HelmRelease"
    input.spec.upgrade.remediation
    not input.spec.upgrade.remediation.strategy
    msg := sprintf("HelmRelease '%s' does not have upgrade remediation strategy set", [input.metadata.name])
}

# Warn if HelmRelease doesn't have cleanupOnFail for upgrades
warn contains msg if {
    input.kind == "HelmRelease"
    not input.spec.upgrade.cleanupOnFail
    msg := sprintf("HelmRelease '%s' does not have upgrade.cleanupOnFail enabled", [input.metadata.name])
}

# Check for deprecated API versions in HelmRelease
deny contains msg if {
    input.kind == "HelmRelease"
    input.apiVersion == "helm.toolkit.fluxcd.io/v2beta1"
    msg := sprintf("HelmRelease '%s' uses deprecated API version v2beta1 - upgrade to v2", [input.metadata.name])
}

deny contains msg if {
    input.kind == "HelmRelease"
    input.apiVersion == "helm.toolkit.fluxcd.io/v2beta2"
    msg := sprintf("HelmRelease '%s' uses deprecated API version v2beta2 - upgrade to v2", [input.metadata.name])
}

# Ensure critical HelmReleases have dependencies defined
warn contains msg if {
    input.kind == "HelmRelease"
    input.metadata.namespace in ["default", "media", "home-automation"]
    not input.spec.dependsOn
    msg := sprintf("HelmRelease '%s' in namespace '%s' has no dependencies defined - consider adding storage/network dependencies", [input.metadata.name, input.metadata.namespace])
}

# Validate HelmRelease timeout is reasonable
warn contains msg if {
    input.kind == "HelmRelease"
    input.spec.timeout
    timeout_match := regex.match("^([0-9]+)(m|h)$", input.spec.timeout)
    timeout_value := to_number(timeout_match[1])
    timeout_unit := timeout_match[2]
    timeout_unit == "m"
    timeout_value > 30
    msg := sprintf("HelmRelease '%s' has very long timeout '%s' - consider if this is necessary", [input.metadata.name, input.spec.timeout])
}

# Ensure HelmReleases in production namespaces have suspend field explicitly set
warn contains msg if {
    input.kind == "HelmRelease"
    input.metadata.namespace in ["default", "media", "networking", "security"]
    not has(input.spec, "suspend")
    msg := sprintf("HelmRelease '%s' in production namespace '%s' should explicitly set suspend field", [input.metadata.name, input.metadata.namespace])
}

# Check for common HelmRelease configuration patterns
warn contains msg if {
    input.kind == "HelmRelease"
    contains(input.spec.chart.spec.chart, "app-template")
    not input.spec.values
    msg := sprintf("HelmRelease '%s' uses app-template but has no values defined", [input.metadata.name])
}

# Ensure HelmRelease using valuesFrom has ConfigMap/Secret defined
deny contains msg if {
    input.kind == "HelmRelease"
    valuesFrom := input.spec.valuesFrom[_]
    not valuesFrom.kind in ["ConfigMap", "Secret"]
    msg := sprintf("HelmRelease '%s' has invalid valuesFrom kind: %s", [input.metadata.name, valuesFrom.kind])
}

# Helper function to check if object has field
has(object, field) := true if {
    object[field]
} else := true if {
    object[field] == false
} else := false