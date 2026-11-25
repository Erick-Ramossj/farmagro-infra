#!/usr/bin/env bash
# Worker node: joins the cluster and labels itself.
# usage: sudo bash install-agent.sh <control-private-ip> <token> <backend|analitico|monitoring>
set -euo pipefail
[[ $# -eq 3 ]] || { echo "usage: $0 <control-private-ip> <token> <backend|analitico|monitoring>"; exit 1; }
CONTROL_IP=$1; TOKEN=$2; ROLE=$3
[[ $ROLE == backend || $ROLE == analitico || $ROLE == monitoring ]] || { echo "role must be backend, analitico or monitoring"; exit 1; }
curl -sfL https://get.k3s.io | K3S_URL="https://${CONTROL_IP}:6443" K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="agent --node-label role=${ROLE}" sh -
echo "Joined as role=${ROLE}. Check on the control node: kubectl get nodes -L role"
