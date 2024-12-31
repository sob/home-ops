#!/bin/bash

#
# https://github.com/solidDoWant/infra-mk3/blob/master/.taskfiles/authentik/get-task-errors.sh
#

set -euo pipefail
shopt -s extglob

# Get teh SQL service name from onepassword
SQL_CLUSTER_NAME="$(
    op read 'op://stonehedges/authentik/AUTHENTIK_POSTGRES__HOST' | cut -d'.' -f1 | cut -d'-' -f1
)"

SQL_INSTANCE_NAME="$(
    op read 'op://stonehedges/authentik/AUTHENTIK_POSTGRES__NAME'
)"

# Get a list of errors
# cspell:words systemtask psql
SQL_QUERY="select jsonb_agg(j) from (select name,uid,description,task_call_module,messages from authentik_events_systemtask where status = 'error') j;"
ERRORS="$(kubectl cnpg psql -n database "${SQL_CLUSTER_NAME}" -t=false -i=false -- ${SQL_INSTANCE_NAME} -t -c "${SQL_QUERY}")"
# Trim leading and trailing whitespace
ERRORS="${ERRORS##+([[:space:]])}"
ERRORS="${ERRORS%%+([[:space:]])}"

if [[ -z "${ERRORS}" ]]; then
    echo "No errors found"
    exit
fi

# Log the errors
echo "Found $(echo "${ERRORS}" | jq -c 'length // 0') errors"
echo "${ERRORS}" | jq -c '.[]' | while read -r error ; do
    echo "Task: $(echo "${error}" | jq -r '.name + "." + .task_call_module + "/" + .uid + ": " + .description')"
    echo 'Errors:'
    echo "${error}" | jq '.messages[]'
done
