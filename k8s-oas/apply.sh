#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo "ERROR: .env is missing"; exit 1; }
set -a; source .env; set +a
: "${GRAFANA_ADMIN_PASSWORD:?set GRAFANA_ADMIN_PASSWORD in .env}"

bash k8s/apply-node-isolation.sh

kubectl -n farmagro create secret generic grafana-admin --from-literal=password="$GRAFANA_ADMIN_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n farmagro create configmap grafana-datasources --from-file=prometheus.yml=k8s-oas/grafana-provisioning/datasources/prometheus.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n farmagro create configmap grafana-dashboard-providers --from-file=farmagro.yml=k8s-oas/grafana-provisioning/dashboards/farmagro.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n farmagro create configmap grafana-dashboards --from-file=k8s-oas/dashboards --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s-oas/monitoring-rbac.yaml
kubectl apply -f k8s-oas/monitoring-config.yaml
kubectl apply -f k8s-oas/node-exporter.yaml
kubectl apply -f k8s-oas/kafka.yaml
kubectl apply -f k8s-oas/kafka-exporter.yaml
kubectl apply -f k8s-oas/kafka-clients.yaml
kubectl apply -f k8s-oas/prometheus.yaml
kubectl apply -f k8s-oas/grafana.yaml
kubectl apply -f k8s-oas/hpa.yaml

kubectl -n farmagro rollout status statefulset/kafka --timeout=180s
kubectl -n farmagro rollout status deployment/kafka-exporter --timeout=120s
kubectl -n farmagro rollout status deployment/kafka-consumer --timeout=120s
kubectl -n farmagro rollout status statefulset/prometheus --timeout=180s
kubectl -n farmagro rollout status deployment/grafana --timeout=180s
kubectl -n farmagro get pods -o wide
