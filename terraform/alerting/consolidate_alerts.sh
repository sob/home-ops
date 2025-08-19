#!/bin/bash

# Script to consolidate alert rules into a cleaner structure
# This will backup existing files and create the new consolidated structure

echo "Consolidating Terraform alert rules..."

# Create backup directory
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup existing rule files
echo "Backing up existing rule files to $BACKUP_DIR..."
cp rules_*.tf "$BACKUP_DIR/" 2>/dev/null

# Files to remove after consolidation
OLD_FILES=(
    "rules_cert_manager.tf"
    "rules_flux.tf"
    "rules_infrastructure.tf"
    "rules_media_services.tf"
    "rules_nodes.tf"
    "rules_power.tf"
    "rules_prometheus_connectivity.tf"
    "rules_services.tf"
    "rules_storage.tf"
)

echo ""
echo "Proposed consolidation:"
echo "======================"
echo "📁 Infrastructure"
echo "  - Node availability (from rules_nodes.tf)"
echo "  - Prometheus connectivity (from rules_prometheus_connectivity.tf)"
echo "  - Power/UPS monitoring (from rules_power.tf)"
echo ""
echo "📁 Storage"
echo "  - SMART disk monitoring (from rules_storage.tf)"
echo "  - Ceph cluster health (from rules_storage.tf)"
echo "  - Volsync backups (from rules_storage.tf)"
echo ""
echo "📁 Platform Services"
echo "  - Flux GitOps (from rules_flux.tf)"
echo "  - External Secrets (from rules_flux.tf)"
echo "  - Cert Manager (from rules_cert_manager.tf)"
echo ""
echo "📁 Applications"
echo "  - Critical services (from rules_services.tf + rules_infrastructure.tf)"
echo "  - Media services (from rules_media_services.tf)"
echo ""
echo "This reduces from 7 folders to 4 folders with better organization."
echo ""
echo "To complete the consolidation:"
echo "1. Review rules_consolidated.tf"
echo "2. Run: terraform plan"
echo "3. If satisfied, remove old files:"
echo "   rm ${OLD_FILES[*]}"
echo "4. Rename: mv rules_consolidated.tf rules.tf"
echo ""
echo "Backup created in: $BACKUP_DIR"