#!/bin/bash
set -e
set -o pipefail

PREFIX="${CMD_PREFIX:-}"

echo "Checking UFW status..."
FIREWALL_STATUS=$($PREFIX sudo ufw status | grep "Status: active" || true)
if [ -z "$FIREWALL_STATUS" ]; then
    echo "UFW is not active!"
    exit 1
fi

echo "Checking systemd services..."
for service in k3s tailscaled; do
    if ! $PREFIX systemctl is-active --quiet "$service"; then
        echo "Service $service is not active!"
        exit 1
    fi
done

echo "Checking K3s Node Status..."
NODE_STATUS=$($PREFIX "sudo k3s kubectl get nodes" | awk 'NR==2 {print $2}')
if [ "$NODE_STATUS" != "Ready" ]; then
    echo "K3s node is not Ready! Status: $NODE_STATUS"
    exit 1
fi

echo "All required services and Kubernetes are active."
exit 0
