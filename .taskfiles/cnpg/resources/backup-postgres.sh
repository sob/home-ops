#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1}"
CLUSTER="${2}"
WAIT="${3}"
TIMEOUT="${4}"

TIMESTAMP="$(date +%Y%m%d%H%M%S%z)"
TIMESTAMP="${TIMESTAMP/+/plus}"
TIMESTAMP="${TIMESTAMP/-/minus}"
FULLNAME="${CLUSTER}-${TIMESTAMP}"

kubectl cnpg backup -n "${NAMESPACE}" "${CLUSTER}" --backup-name "${FULLNAME}"

if [ "${WAIT}" = "true" ]; then
  echo "Waiting for backup ${FULLNAME}..."
  kubectl wait -n "${NAMESPACE}" "backups.postgresql.cnpg.io/${FULLNAME}" \
    --for=jsonpath='{.status.phase}'=completed \
    --timeout="${TIMEOUT}"
  kubectl delete -n "${NAMESPACE}" "backups.postgresql.cnpg.io/${FULLNAME}"
  echo "Backup of ${FULLNAME} is completed"
fi
