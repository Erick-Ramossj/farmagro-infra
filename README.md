# farmagro-infra

Manifests y scripts para desplegar FARMAGRO en un clúster k3s de 4 nodos, con Kafka, Prometheus y Grafana en pods. Las imágenes ya están publicadas y fijadas por digest: no se compila nada.

| Nodo | Rol (`role=`) | Qué corre |
|---|---|---|
| control | `frontend` (k3s server) | frontend, kube-state-metrics |
| backend | `backend` | backend funcional (Spring Boot) |
| analitico | `analitico` | backend analítico (Flask) |
| kafka | `monitoring` | Kafka, kafka-exporter, kafka-consumer, Prometheus, Grafana |

MongoDB (27017) y SQL Server (1433) son externos al clúster y deben tener sus datos cargados **antes** de desplegar. Este repositorio no incluye semillas, credenciales ni código fuente. Todas las imágenes funcionan en amd64.

## Uso

1. Control: instala k3s e imprime la IP privada y el token.

   ```bash
   git clone --depth 1 -b eva-final-v2 https://github.com/Erick-Ramossj/farmagro-infra.git ~/farmagro-infra
   cd ~/farmagro-infra && sudo env INSTALL_K3S_VERSION=v1.37.2+k3s1 bash k3s/install-server.sh
   ```

2. Cada worker, empezando por `backend` (los otros roles son `analitico` y `monitoring`):

   ```bash
   sudo env INSTALL_K3S_VERSION=v1.37.2+k3s1 bash k3s/install-agent.sh <IP_PRIVADA_CONTROL> <K3S_TOKEN> backend
   ```

   Espera a que los pods de `kube-system` estén `Running` antes de seguir: `deploy.sh` aplica taints a todos los nodos.

3. Control: completa `.env` y despliega.

   ```bash
   cp .env.example .env && bash set-db-credentials.sh   # pide usuario y clave de SQL Server
   nano .env                                            # MONGO_HOST, RDS_HOST y GRAFANA_ADMIN_PASSWORD
   bash deploy.sh
   ```

Resultado: 12 pods `Running` en el namespace `farmagro`.

| Puerto | Servicio |
|---|---|
| 30080 | Web |
| 30081 | API funcional (`/swagger-ui.html`) |
| 30082 | API analítica (`/docs`) |
| 30090 | Prometheus |
| 30091 | Grafana (usuario `admin`) |

## Eventos

El backend publica en el tópico `eventos-negocio` un evento por cada inicio de sesión, registro y escritura exitosa:

```bash
kubectl -n farmagro logs -f deploy/kafka-consumer
```

La red entre los nodos debe permitir todo el tráfico. Prometheus y Grafana no deben abrirse a Internet.
