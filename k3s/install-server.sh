#!/usr/bin/env bash
# Control node: installs the k3s server. Traefik and the service load balancer are disabled
# (not needed, they only take memory). The node is labelled and tainted role=frontend because it also runs the web.
# usage: sudo bash install-server.sh
set -euo pipefail
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --disable servicelb --write-kubeconfig-mode 644" sh -
until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
kubectl label node "$NODE" role=frontend --overwrite
kubectl taint node "$NODE" role=frontend:NoSchedule --overwrite
echo
echo "Control private IP: $(hostname -I | awk '{print $1}')"
echo "Join token (use it in install-agent.sh):"
cat /var/lib/rancher/k3s/server/node-token
