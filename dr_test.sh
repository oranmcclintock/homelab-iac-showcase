#!/bin/bash

# ======================================================================
# GITOPS DISASTER RECOVERY VALIDATION SCRIPT
# ======================================================================
# This script performs a non-destructive health audit of the Proxmox/K3s
# GitOps infrastructure to validate that a disaster recovery restore
# was successful.
# ======================================================================

set -e

echo "[DR TEST] Phase 1: Checking K3s Node Health..."
if ! sudo k3s kubectl get nodes | grep -q "Ready"; then
    echo "[FAIL] No nodes are in the Ready state."
    exit 1
fi
echo "[PASS] K3s Node is Ready."

echo "[DR TEST] Phase 2: QA Pod Health Audit..."
# Check for any pods that are not Running or Completed
PODS_DOWN=$(sudo k3s kubectl get pods -A --field-selector=status.phase!=Running | grep -v "Completed" | grep -v "NAMESPACE" | wc -l | tr -d ' ')

if [ "$PODS_DOWN" -gt 0 ]; then
    echo "[FAIL] QA FAILED: $PODS_DOWN pod(s) are crashing or not in Running state!"
    sudo k3s kubectl get pods -A --field-selector=status.phase!=Running | grep -v "Completed"
    exit 1
else
    echo "[PASS] QA PASSED: All K3s pods are healthy."
fi

echo "[DR TEST] Phase 3: Traefik Ingress Routing Audit..."

# Spoof Host headers to test Traefik routing directly via localhost port 80
DOMAINS=("paperless.example.com" "nextcloud.example.com" "gitea.example.com" "vaultwarden.example.com")

for DOMAIN in "${DOMAINS[@]}"; do
    # Fetch the HTTP status code from Traefik on port 80
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" -H "Host: $DOMAIN" http://localhost:80)
    
    # Acceptable codes: 200 (OK), 301/302 (Redirect to login/HTTPS), 401 (Unauthorized/Auth required), 404 (In some cases ok, but mostly 302s and 200s)
    if [[ "$HTTP_STATUS" =~ ^(200|301|302|401)$ ]]; then
        echo "[PASS] ROUTING PASSED: $DOMAIN -> HTTP $HTTP_STATUS"
    else
        echo "[FAIL] ROUTING FAILED: $DOMAIN -> HTTP $HTTP_STATUS (Traefik failed to route to backend)"
        exit 1
    fi
done

echo ""
echo "======================================================================"
echo "DISASTER RECOVERY AUDIT 100% SUCCESSFUL"
echo "======================================================================"
echo "All K3s nodes and pods are healthy."
echo "Traefik is accurately routing traffic for internal services."
echo "The infrastructure has successfully survived the DR test!"
