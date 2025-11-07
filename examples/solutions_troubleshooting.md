## Comandos Originales

### 1. Ver nodos de Elasticsearch
bash
kubectl exec -it -n logging elasticsearch-0 -- curl -s localhost:9200/_cat/nodes?v

*Explicación*: Ejecuta un comando curl dentro del pod elasticsearch-0 para listar los nodos del cluster Elasticsearch con formato legible.

### 2. Logs anteriores de Elasticsearch
bash
kubectl logs elasticsearch-0 -n logging --previous --tail=10

*Explicación*: Muestra las últimas 10 líneas de logs de la instancia anterior del contenedor (útil si el pod se reinició).

### 3. Logs de Fluentd
bash
kubectl logs -n logging -l app=fluentd --tail=50

*Explicación*: Muestra las últimas 50 líneas de logs de todos los pods con la etiqueta app=fluentd.

### 4. Listar índices de Elasticsearch
bash
kubectl exec -n logging elasticsearch-0 -- curl -u elastic:TuPasswordSeguro -k https://localhost:9200/_cat/indices?v

*Explicación*: Ejecuta curl autenticado para listar todos los índices de Elasticsearch con detalles.

### 5. Salud del cluster Elasticsearch
bash
kubectl exec -n logging elasticsearch-0 -- curl -u elastic:TuPasswordSeguro -k https://localhost:9200/_cluster/health?pretty

*Explicación*: Verifica el estado de salud del cluster Elasticsearch con formato legible.

### 6. Listar pods con detalles
bash
kubectl get pod -n logging -o wide

*Explicación*: Lista todos los pods en el namespace logging mostrando información extendida (IPs, nodos, etc.).

## Comando Adicional - Prueba de Conectividad

### 7. Pod temporal para pruebas de conectividad
bash
kubectl run -it --rm debug-pod --image=busybox -n logging -- /bin/sh

*Explicación*: Crea un pod temporal interactivo con busybox en el mismo namespace para realizar pruebas de conectividad entre servicios.

*Uso típico dentro del pod*:
bash
# Probar conectividad a Elasticsearch
wget -O- http://elasticsearch-0:9200

# Probar DNS resolution
nslookup elasticsearch-0

# Probar conectividad a otros servicios
telnet fluentd-svc 24224
