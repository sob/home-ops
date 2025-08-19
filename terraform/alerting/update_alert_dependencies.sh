#!/bin/bash

# Script to update all alert rules to handle Prometheus dependencies properly

echo "Updating alert rules to handle Prometheus dependencies..."

# Find all rule files
for file in rules_*.tf; do
    if [[ "$file" == "rules_prometheus_connectivity.tf" ]]; then
        continue  # Skip the connectivity rule itself
    fi
    
    echo "Processing $file..."
    
    # Update no_data_state from "OK" to "NoData" for Prometheus-dependent rules
    sed -i.bak 's/no_data_state = "OK"/no_data_state = "NoData"/g' "$file"
    
    # Add depends_on_prometheus label if it's using prometheus_pdc_uid
    if grep -q "prometheus_pdc_uid" "$file"; then
        # Add the label to rules that don't already have it
        awk '
        /labels = {/ {
            in_labels = 1
            print
            next
        }
        in_labels && /}/ {
            if (!has_depends) {
                print "      depends_on_prometheus = \"true\""
            }
            in_labels = 0
            has_depends = 0
        }
        /depends_on_prometheus/ {
            has_depends = 1
        }
        { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
done

echo "Alert rules updated. Backup files created with .bak extension."
echo ""
echo "Summary of changes:"
echo "1. Changed no_data_state from 'OK' to 'NoData' for all rules"
echo "2. Added 'depends_on_prometheus = true' label to rules using PDC datasource"
echo ""
echo "This ensures:"
echo "- Alerts won't fire when Prometheus is unreachable"
echo "- Notification policy can group/suppress them appropriately"
echo "- You get one 'PrometheusDataSourceDown' alert instead of 30+ individual alerts"