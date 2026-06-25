#!/usr/bin/env python3
"""
GitOps permission guard for Claude Code  (PreToolUse hook, matcher: Bash)

home-ops is a Flux GitOps cluster, so the policy is intent-based, not read/write:

  ALLOW (no prompt) - reads + transient troubleshooting that self-heals or that
      Flux will reconcile back to git:
        kubectl get/describe/logs/top/exec/port-forward/cp/debug/run,
        kubectl delete <anything Flux re-applies>, rollout restart/undo, scale,
        cordon/drain, annotate/label, flux get/reconcile/suspend/resume/diff,
        talos read verbs, terraform plan/validate/apply, kustomize build, helm read.
      (kubectl delete and terraform apply are allowed because Flux/tofu reconcile
       cluster state back to git, so a delete or apply self-heals.)

  ASK (prompt once, with a "push it through git" reminder) - direct desired-state
      edits whose real home is a manifest -> commit -> Flux:
        kubectl apply/create/edit/patch/replace/set,
        flux create/delete, terraform import/taint, helm install/upgrade,
        talos apply-config/upgrade/bootstrap, etcd remove-member.

  DENY (hard block) - catastrophic / irreversible:
        kubectl delete namespace|node|pv|pvc|crd|cephcluster|helmrelease|kustomization,
        kubectl delete --all-namespaces, talos reset/reboot/shutdown/wipe,
        terraform destroy / state push, rm -rf, dd, mkfs.

Anything unrecognized -> stay silent (exit 0) and let the normal allow/ask/deny
rules + the interactive prompt decide. The hook only ever *allows* things it is
certain are safe, so it never silently widens a static deny rule.

Decisions are matched against the kubectl/flux/talos/etc. *verb*, found by scanning
for a known verb token, so flag position (`kubectl -n x get`) never matters.
"""
import json
import re
import shlex
import sys

ALLOW, ASK, DENY, UNKNOWN = "allow", "ask", "deny", "unknown"
RANK = {ALLOW: 0, UNKNOWN: 1, ASK: 2, DENY: 3}

REASONS = {
    ASK: ("This changes cluster desired state directly. Prefer GitOps: edit the "
          "manifest, commit, and let Flux apply it. Approve only for a deliberate "
          "one-off troubleshooting change."),
    DENY: ("Blocked: catastrophic / irreversible operation. If you really need it, "
           "run it by hand in a terminal."),
}

# ---- generic safe tools (so `kubectl ... | jq | grep` stays fully auto) ----
NEUTRAL = {
    "ls", "cat", "head", "tail", "grep", "rg", "egrep", "fgrep", "zgrep", "jq",
    "yq", "awk", "gawk", "sed", "cut", "tr", "sort", "uniq", "wc", "echo",
    "printf", "find", "basename", "dirname", "realpath", "stat", "file", "which",
    "pwd", "true", "false", "test", "[", "date", "env", "printenv", "whoami",
    "uname", "hostname", "column", "tee", "dig", "nslookup", "host", "base64",
    "sha256sum", "md5sum", "comm", "paste", "fold", "nl", "tac", "seq", "sleep",
    "openssl", "curl", "wget", "gron", "dyff", "kubeconform", "yamllint", "sops",
    "age", "mkdir", "touch", "cp", "mv", "ln", "chmod", "diff", "cmp", "tree",
    "du", "df", "cd", "export", "pushd", "popd", "skopeo", "crane", "op",
}

# ---- kubectl ----
K_ALLOW = {
    "get", "describe", "logs", "top", "explain", "events", "api-resources",
    "api-versions", "cluster-info", "version", "auth", "diff", "wait", "rollout",
    "port-forward", "exec", "cp", "debug", "attach", "proxy", "run", "scale",
    "cordon", "uncordon", "drain", "annotate", "label", "config", "completion",
    "kustomize", "options",
}
K_ASK = {
    "apply", "create", "edit", "patch", "replace", "set", "expose", "autoscale",
    "taint", "certificate", "rollout-pause",
}
K_VERBS = K_ALLOW | K_ASK | {"delete"}

TRANSIENT_TYPES = {
    "pod", "pods", "po", "job", "jobs", "replicaset", "replicasets", "rs",
}
CATASTROPHIC_TYPES = {
    "namespace", "namespaces", "ns", "node", "nodes", "no", "pv",
    "persistentvolume", "persistentvolumes", "pvc", "persistentvolumeclaim",
    "persistentvolumeclaims", "crd", "crds", "customresourcedefinition",
    "customresourcedefinitions", "storageclass", "storageclasses", "sc",
    "cephcluster", "cephclusters", "cluster", "clusters",
}
# Flux control objects: deleting one is a known recovery move (e.g. delete a stuck
# HelmRelease so its Kustomization recreates it) but it halts reconciliation, so ask.
GITOPS_CONTROL_TYPES = {
    "helmrelease", "helmreleases", "hr", "kustomization", "kustomizations", "ks",
    "gitrepository", "gitrepositories", "ocirepository", "ocirepositories",
    "helmrepository", "helmrepositories",
}

# ---- flux ----
F_DENY = {"bootstrap", "uninstall"}
F_ASK = {"create", "delete", "export", "push", "pull", "install"}
F_ALLOW = {
    "get", "stats", "tree", "check", "logs", "diff", "events", "version",
    "reconcile", "suspend", "resume", "build", "trace", "completion", "envsubst",
}

# ---- talos (read-mostly: allow unless a known mutating/destructive verb shows up) ----
T_DENY = {"reset", "reboot", "shutdown", "wipe"}
T_ASK = {
    "apply-config", "apply-machine-config", "patch-machine-config", "edit",
    "upgrade", "upgrade-k8s", "rollback", "install", "bootstrap",
}

# ---- terraform / tofu ----
TF_ASK = {"import", "taint", "untaint", "refresh", "unlock"}
TF_ALLOW = {
    "apply", "validate", "plan", "fmt", "show", "output", "version", "providers",
    "graph", "init", "get", "test", "login", "logout", "console", "workspace",
}

# ---- helm / helmfile ----
H_ASK = {"install", "upgrade", "uninstall", "delete", "rollback", "push", "registry"}
H_ALLOW = {
    "list", "ls", "status", "get", "show", "template", "history", "version",
    "search", "lint", "repo", "env", "dependency", "dep", "diff", "pull",
}
HF_ASK = {"apply", "sync", "destroy", "delete"}
HF_ALLOW = {"diff", "template", "list", "lint", "build", "version", "status", "deps"}

WRAPPERS = {"sudo", "nohup", "time", "nice", "ionice", "command", "stdbuf", "env"}
ENV_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def strip_wrappers(tokens):
    """Drop leading env-assignments, sudo/timeout/xargs/etc. to reach the real cmd."""
    i = 0
    n = len(tokens)
    while i < n:
        t = tokens[i]
        if ENV_ASSIGN.match(t):
            i += 1
            continue
        if t in WRAPPERS:
            i += 1
            continue
        if t == "timeout":
            i += 1
            while i < n and tokens[i].startswith("-"):
                i += 1
            if i < n:  # duration token
                i += 1
            continue
        if t in ("xargs", "watch"):
            i += 1
            while i < n and tokens[i].startswith("-"):
                flag = tokens[i]
                i += 1
                if flag in ("-I", "-n", "-P", "-d", "-E", "-s", "-L") and i < n:
                    i += 1
            continue
        break
    return tokens[i:]


def membership(words, deny, ask, allow, default):
    if any(w in deny for w in words):
        return DENY
    if any(w in ask for w in words):
        return ASK
    if any(w in allow for w in words):
        return ALLOW
    return default


def classify_kubectl(tokens):
    words = tokens[1:]
    verb = None
    for w in words:
        if w.startswith("-"):
            continue
        if w in K_VERBS:
            verb = w
            break
    if verb == "delete":
        return kubectl_delete(words)
    if verb in K_ASK:
        return ASK
    if verb in K_ALLOW:
        return ALLOW
    return ASK  # unknown / unidentifiable kubectl verb -> be safe


def kubectl_delete(words):
    if "--all-namespaces" in words or "-A" in words:
        return DENY
    rtype = None
    seen = False
    for w in words:
        if not seen:
            if w == "delete":
                seen = True
            continue
        if w.startswith("-"):
            continue
        rtype = w
        break
    if rtype is None:
        return ALLOW  # `delete -f file` / `delete -k dir` -> Flux re-applies from git
    base = rtype.split("/")[0].split(".")[0].lower()
    if base in CATASTROPHIC_TYPES:
        return DENY
    if base in GITOPS_CONTROL_TYPES:
        return ASK
    # everything else (deploy/svc/cm/secret/pod/job/...) self-heals: Flux re-applies it.
    return ALLOW


def classify_talos(tokens):
    words = tokens[1:]
    if any(w in T_DENY for w in words):
        return DENY
    if any(w in T_ASK for w in words):
        return ASK
    if "etcd" in words and any(w in {"remove-member", "forfeit-leadership"} for w in words):
        return ASK
    return ALLOW


def classify_tf(tokens):
    words = tokens[1:]
    if "destroy" in words:
        return DENY
    if "state" in words:
        if "push" in words:
            return DENY
        if any(w in {"rm", "mv", "replace-provider"} for w in words):
            return ASK
        return ALLOW
    return membership(words, set(), TF_ASK, TF_ALLOW, ASK)


def classify_task(tokens):
    recipe = None
    for w in tokens[1:]:
        if w.startswith("-"):
            continue
        if ENV_ASSIGN.match(w):
            continue
        recipe = w.lower()
        break
    if recipe is None:
        return ALLOW  # `task -l`
    if re.search(r"(destroy|reset|wipe|bootstrap|upgrade|uninstall)", recipe):
        return ASK
    if recipe.endswith(":apply") or recipe == "apply":
        return ALLOW  # terraform-style apply; Flux/tofu reconciles to git
    if re.search(r"(^flux:|plan|validate|fmt|lint|build|diff|test|check|list|status|get|view|show|reconcile|hr|ks)", recipe):
        return ALLOW
    return UNKNOWN


def classify_rm(tokens):
    flags = " ".join(t for t in tokens[1:] if t.startswith("-"))
    letters = "".join(f.lstrip("-") for f in flags.split())
    recursive = "r" in letters or "R" in letters or "--recursive" in flags
    force = "f" in letters or "--force" in flags
    if recursive and force:
        return DENY
    return UNKNOWN  # plain `rm` -> let normal rules decide


def classify_segment(tokens):
    tokens = strip_wrappers(tokens)
    if not tokens:
        return ALLOW
    base = tokens[0].split("/")[-1]
    if base in ("kubectl", "k", "kubectl.exe"):
        return classify_kubectl(tokens)
    if base == "flux":
        return membership(tokens[1:], F_DENY, F_ASK, F_ALLOW, ASK)
    if base in ("talosctl", "talos"):
        return classify_talos(tokens)
    if base in ("terraform", "tofu", "opentofu"):
        return classify_tf(tokens)
    if base == "helm":
        return membership(tokens[1:], set(), H_ASK, H_ALLOW, ASK)
    if base == "helmfile":
        return membership(tokens[1:], set(), HF_ASK, HF_ALLOW, ASK)
    if base == "task":
        return classify_task(tokens)
    if base == "kustomize":
        return ALLOW
    if base == "rm":
        return classify_rm(tokens)
    if base in ("dd", "shred", "mkfs") or base.startswith("mkfs."):
        return DENY
    if base in NEUTRAL:
        return ALLOW
    return UNKNOWN


def tokenize(command):
    """Shell-aware tokenizer that splits compound commands reliably.

    shlex.split() does NOT emit shell operators as standalone tokens, so a
    semicolon written without a leading space (`head; echo`, the common case)
    stays glued to the previous word (`head;`). That broke split_segments(),
    which then handed a mangled segment to the classifier -> UNKNOWN -> the hook
    silently deferred and the command prompted.

    Using shlex.shlex with punctuation_chars=";" emits `;` as its own token even
    when glued, while quotes, posix escapes (`-exec cat {} \\;`) and redirects
    (`2>/dev/null`, `2>&1`) are preserved. Only `;` is punctuation -- `&`/`<`/`>`
    are deliberately excluded so redirect operators don't get split apart;
    space-separated `|`, `&&`, `||` still arrive as their own tokens via
    whitespace splitting and are handled in split_segments().
    """
    lex = shlex.shlex(command, posix=True, punctuation_chars=";")
    lex.whitespace_split = True
    lex.commenters = ""  # don't treat '#' as a comment (URLs, anchors, regexes)
    return list(lex)


def split_segments(tokens):
    operators = {"|", "||", "&&", ";", "&", "|&"}
    segments, cur = [], []
    for tok in tokens:
        if tok in operators:
            if cur:
                segments.append(cur)
                cur = []
        else:
            cur.append(tok)
    if cur:
        segments.append(cur)
    return segments


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    if payload.get("tool_name") != "Bash":
        return
    command = (payload.get("tool_input") or {}).get("command", "")
    if not command.strip():
        return
    try:
        tokens = tokenize(command)
    except ValueError:
        return  # unbalanced quotes etc. -> defer to normal rules

    decision = ALLOW
    for seg in split_segments(tokens):
        d = classify_segment(seg)
        if RANK[d] > RANK[decision]:
            decision = d

    if decision == UNKNOWN:
        return  # defer to normal allow/ask/deny rules + prompt
    if decision == ALLOW:
        out = {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": "Read-only or transient troubleshooting (auto-approved by gitops-guard).",
        }}
    else:
        out = {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": REASONS[decision],
        }}
    print(json.dumps(out))


if __name__ == "__main__":
    main()
