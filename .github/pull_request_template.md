<!-- Renovate PRs can ignore this template. -->

## What & why

<!-- One or two lines. Link an issue if there is one. -->

## Checklist

- [ ] Ran `task validate` locally (or pushed and let the `Validate` workflow run)
- [ ] Pre-commit/pre-push hooks pass (`mise install` wires them; broken YAML/lint blocks the push)
- [ ] No plaintext secrets — sensitive values are SOPS-encrypted (`*.sops.yaml`) or via External Secrets
- [ ] Reviewed the **Flux Diff** comment below — the rendered change matches intent

## Notes

<!-- Anything reviewers (or future-you) should know: manual steps, follow-ups, risks. -->
