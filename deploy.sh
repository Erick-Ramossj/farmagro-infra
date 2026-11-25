#!/usr/bin/env bash
# FARMAGRO — deploys the three applications, kube-state-metrics and the OAS stack to the k3s cluster.
# Run it on the control node, from this folder, after filling in .env:  bash deploy.sh
#
# Order matters: the frontend goes last, once the backends exist.
set -euo pipefail
cd "$(dirname "$0")"

[[ -f .env ]] || { echo "ERROR: .env is missing. Run: cp .env.example .env  and fill it in."; exit 1; }
set -a; source .env; set +a

for var in MONGO_HOST RDS_HOST SQLSERVER_USER SQLSERVER_PASSWORD; do
  [[ -n "${!var:-}" ]] || { echo "ERROR: $var is empty in .env"; exit 1; }
done
IMAGE_TAG="${IMAGE_TAG:-eva-final-v2}"
BACKEND_UPSTREAM="${BACKEND_UPSTREAM:-http://farmagro-backend.farmagro.svc.cluster.local:8080}"
ANALYTICS_UPSTREAM="${ANALYTICS_UPSTREAM:-http://farmagro-analitico.farmagro.svc.cluster.local:8000}"
NS=farmagro

echo "== 1/7 Cluster"
READY=$(kubectl get nodes --no-headers | grep -c ' Ready' || true)
(( READY >= 4 )) || { echo "ERROR: 4 nodes Ready are needed, there are $READY."; kubectl get nodes; exit 1; }
bash k8s/apply-node-isolation.sh

echo "== 2/7 Namespace and secrets"
kubectl apply -f k8s/00-namespace.yml
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT; chmod 600 "$TMP"
cat > "$TMP" <<ENVFILE
SPRING_DATA_MONGODB_URI=mongodb://${MONGO_HOST}:27017/farmagro_s4
R2DBC_URL=r2dbc:mssql://${RDS_HOST}:1433/FARMAGRO_SA
R2DBC_USERNAME=${SQLSERVER_USER}
R2DBC_PASSWORD=${SQLSERVER_PASSWORD}
ENVFILE
kubectl -n $NS create secret generic farmagro-backend-secret --from-env-file="$TMP" --dry-run=client -o yaml | kubectl apply -f -
cat > "$TMP" <<ENVFILE
MONGODB_URI=mongodb://${MONGO_HOST}:27017
SQLSERVER_HOST=${RDS_HOST}
SQLSERVER_USER=${SQLSERVER_USER}
SQLSERVER_PASSWORD=${SQLSERVER_PASSWORD}
ENVFILE
kubectl -n $NS create secret generic farmagro-analytics-secret --from-env-file="$TMP" --dry-run=client -o yaml | kubectl apply -f -

apply() { sed -e "s|__BACKEND_UPSTREAM__|${BACKEND_UPSTREAM}|" \
              -e "s|__ANALYTICS_UPSTREAM__|${ANALYTICS_UPSTREAM}|" "$1" | kubectl apply -f -; }

echo "== 3/7 Backend 1 (Spring Boot) — the JVM takes 60-90 s"
apply k8s/01-backend.yml
kubectl -n $NS rollout status deploy/backend1 --timeout=300s

echo "== 4/7 Backend 2 (Flask)"
apply k8s/02-analytics.yml
kubectl -n $NS rollout status deploy/backend2 --timeout=180s

echo "== 5/7 kube-state-metrics"
kubectl apply -f k8s/04-kube-state-metrics.yml
kubectl -n kube-system rollout status deploy/kube-state-metrics --timeout=120s

echo "== 6/7 Frontend (nginx)"
apply k8s/03-frontend.yml
kubectl -n $NS rollout status deploy/frontend --timeout=180s

echo "== 7/7 Kafka, Prometheus y Grafana en pods"
bash k8s-oas/apply.sh

echo; kubectl -n $NS get pods -o wide; echo; kubectl -n $NS get svc
CONTROL_PUBLIC=$(curl -s --max-time 3 http://169.254.169.254/latest/meta-data/public-ipv4 || true)
echo; echo "Web:  http://${CONTROL_PUBLIC:-<public IP of the control node>}:30080"
