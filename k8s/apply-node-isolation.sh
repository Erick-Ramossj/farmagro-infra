#!/usr/bin/env bash
set -euo pipefail

for role in frontend backend analitico monitoring; do
  nodes=$(kubectl get nodes -l "role=$role" -o name | cut -d/ -f2)
  [[ -n "$nodes" ]] || { echo "ERROR: no node has role=$role"; exit 1; }
  while IFS= read -r node; do
    [[ -n "$node" ]] || continue
    kubectl label node "$node" "role=$role" --overwrite
    kubectl taint node "$node" "role=$role:NoSchedule" --overwrite
  done <<< "$nodes"
done

kubectl get nodes -L role
for role in frontend backend analitico monitoring; do
  for node in $(kubectl get nodes -l "role=$role" -o name | cut -d/ -f2); do
    echo "== $node =="
    kubectl describe node "$node" | grep -i '^Taints:'
  done
done
