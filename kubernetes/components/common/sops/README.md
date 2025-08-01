# SOPS Age Key Backup

This component contains the encrypted SOPS age key used for cluster secret decryption.

## ⚠️ CRITICAL: Bootstrap Requirement

The `sops-age` secret must be manually created BEFORE applying Flux:

```bash
# Create the secret from your age key backup
kubectl create secret generic sops-age \
  --from-file=age.agekey=/path/to/age.key \
  -n flux-system
```

## Backup Locations

The age.key private key is backed up in:
1. **1Password**: `flux` vault → `sops-age-key` item
2. **Physical**: Encrypted USB in safe
3. **Recovery**: Paper printout in safety deposit box

## Disaster Recovery

1. Install fresh Talos/k8s cluster
2. Retrieve age.key from backup location
3. Create sops-age secret (command above)
4. Bootstrap Flux
5. Flux will decrypt this file and apply all secrets

## File Contents

- `secret.sops.yaml` - The encrypted sops-age secret
- This file is encrypted with the SAME key it contains (bootstrap paradox)
- DO NOT DELETE unless you have the key backed up elsewhere!