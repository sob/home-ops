#!/usr/bin/env bash

JOB=$1
NAMESPACE="${2:-default}"

[[ -z "${JOB}" ]] && echo "Job name not specified" && exit 1

# Spinner array
SPINNERS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_IDX=0

# Function to cleanup cursor on script exit
trap 'printf "\n"' EXIT

while true; do
    if [[ $JOB == volsync-dst-wipe-* ]] || [[ $JOB == volsync-list-* ]] || [[ $JOB == volsync-unlock-* ]]; then
        # Get pod status first for wipe/list/unlock jobs
        POD_STATUS="$(kubectl --namespace "${NAMESPACE}" get pod --selector="job-name=${JOB}" --output="jsonpath='{.items[*].status.phase}'" 2>/dev/null)"
        if [ "${POD_STATUS}" == "'Succeeded'" ]; then
            printf "\r✓ Job completed successfully\n"
            break
        fi
        SELECTOR="job-name=${JOB}"
    else
        # For restore jobs, check replicationdestination status
        COMPLETE=$(kubectl --namespace "${NAMESPACE}" get replicationdestination "${JOB}" -o jsonpath='{.status.lastSyncTime}' 2>/dev/null)
        if [ ! -z "$COMPLETE" ]; then
            RESULT=$(kubectl --namespace "${NAMESPACE}" get replicationdestination "${JOB}" -o jsonpath='{.status.latestMoverStatus.result}' 2>/dev/null)
            if [ "${RESULT}" == "Successful" ]; then
                printf "\r✓ Job completed successfully\n"
                break
            fi
        fi
        SELECTOR="job-name=volsync-dst-${JOB}"
    fi

    # Show pod status with spinner
    POD_STATUS="$(kubectl --namespace "${NAMESPACE}" get pod --selector="${SELECTOR}" --output="jsonpath='{.items[*].status.phase}'" 2>/dev/null)"
    SPINNER=${SPINNERS[$SPINNER_IDX]}
    printf "\r${SPINNER} Job status: ${POD_STATUS}  "
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % 10 ))
    sleep 0.1
done
