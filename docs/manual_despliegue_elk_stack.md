# 📦 Despliegue Automatizado de la Pila ELK en Kubernetes

## 1. 🎯 Propósito del Script

Este script automatiza el despliegue de la **pila ELK** (*Elasticsearch, Fluentd, Kibana*) en **Kubernetes**.  
Crea los recursos necesarios (**namespaces**, **roles**, **configuraciones** y **servicios**) dentro del clúster para habilitar una infraestructura completa de **observabilidad y monitoreo centralizado de logs**.

### Estructura desplegada:
- **Elasticsearch:** Motor de almacenamiento y búsqueda de logs.  
- **Fluentd:** Recolector y redireccionador de logs desde los nodos.  
- **Kibana:** Interfaz visual para explorar los datos recolectados.  
- **Certificados de seguridad y roles RBAC:** Control de acceso y comunicación segura.

---

## 2. ⚙️ Encabezado y Preparación

```bash
#!/usr/bin/env bash
````

* Define que el script será ejecutado usando **bash** desde el entorno del sistema.
* Garantiza compatibilidad en distribuciones basadas en **Linux**.

---

## 3. 🧱 Creación del Namespace

```bash
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
```

* Crea el namespace `logging`, que agrupará todos los recursos relacionados con ELK.
* El parámetro `--dry-run=client -o yaml` genera la definición YAML sin aplicarla directamente.
* El resultado se canaliza (`|`) hacia `kubectl apply -f -`, que finalmente la crea o actualiza en el clúster.
* Esto asegura que el namespace exista antes de desplegar los manifiestos posteriores.

---

## 4. 📄 Aplicación de Manifiestos

```bash
cat <<'EOF' | kubectl apply -f -
```

* Inicia un bloque **here-document (`EOF`)** que contiene todos los manifiestos YAML del stack.
* Todo lo que se encuentre dentro del bloque será leído por `kubectl apply -f -`, aplicando cada definición en el clúster.
* El uso de `'EOF'` (con comillas simples) evita que **bash** interprete variables o caracteres especiales.

---

## 5. 🧩 Elasticsearch: Servicio y StatefulSet

### 🛰️ Service (elasticsearch)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: logging
spec:
  clusterIP: None
```

* Define un **Service sin IP fija** (`clusterIP: None`), típico para servicios de tipo StatefulSet.
* Permite la comunicación entre los pods del clúster Elasticsearch usando DNS interno.
* Expone los puertos:

  * `9200`: Acceso REST (para consultas externas, Kibana, Fluentd).
  * `9300`: Comunicación interna entre nodos Elasticsearch.

---

### 🗄️ StatefulSet (elasticsearch)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: logging
```

* Crea **tres réplicas** (`replicas: 3`) de Elasticsearch, cada una con almacenamiento persistente y nombre único (`elasticsearch-0`, `-1`, `-2`).
* Usa `serviceName: elasticsearch` para habilitar la resolución de nombres DNS.
* Configura variables de entorno que definen el clúster:

  * `cluster.name`, `node.name`, `discovery.seed_hosts`, `cluster.initial_master_nodes`: permiten la formación del clúster distribuido.
  * `xpack.security.*`: habilita autenticación, cifrado TLS/SSL y contraseñas seguras.
  * `ELASTIC_PASSWORD`: define la contraseña del usuario `elastic`.
  * `ES_JAVA_OPTS`: limita el uso de memoria JVM (512MB en este caso).
* Define volúmenes:

  * `data`: almacenamiento persistente de índices (PVC de 10Gi).
  * `certs`: montaje de certificados desde un Secret llamado `elastic-certs`.

**Propósito:** garantizar **alta disponibilidad y seguridad** del almacenamiento de logs.

---

## 6. 🔄 Fluentd: Recolector de Logs

Fluentd actúa como el **agente que recopila todos los logs de contenedores** y los envía a Elasticsearch.

### 🔐 RBAC (Roles y Permisos)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
...
kind: ClusterRoleBinding
```

* Se crea un **ClusterRole** que otorga permisos de lectura sobre pods y namespaces.
* Se define un **ServiceAccount** `fluentd` dentro del namespace `logging`.
* El **ClusterRoleBinding** enlaza el rol con la cuenta de servicio, permitiendo que Fluentd lea metadatos del clúster necesarios para etiquetar logs correctamente.

---

### ⚙️ ConfigMap (Configuración de Fluentd)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: logging
data:
  fluent.conf: |
```

* Crea la configuración principal de **Fluentd** (`fluent.conf`).
* Define:

  * **Input (<source>):**

    * Recolecta archivos de logs ubicados en `/var/log/containers/*.log`.
    * Interpreta logs multilinea (útil para errores con varias líneas).
  * **Output (<match>):**

    * Envía los logs procesados hacia Elasticsearch (`host: elasticsearch`, puerto `9200`).
    * Usa HTTPS pero sin verificación estricta (`ssl_verify false`).
    * Indexa los datos bajo el índice `fluentd` con formato `logstash`.

---

### 🧍 DaemonSet (fluentd)

```yaml
apiVersion: apps/v1
kind: DaemonSet
```

* Despliega un **Pod de Fluentd en cada nodo del clúster**.
* Usa la imagen oficial `fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch`.
* Monta los siguientes volúmenes:

  * `/var/log`: para leer logs de contenedores.
  * `/var/lib/docker/containers`: acceso directo a los archivos de logs generados por Docker/CRI.
  * `/fluentd/etc`: donde se carga la configuración desde el ConfigMap.
* Define `requests/limits` para controlar el uso de CPU y memoria.

**Propósito:** garantizar que todos los logs de Kubernetes sean recolectados sin importar en qué nodo se generen.

---

## 7. 📊 Kibana: Interfaz de Visualización

### 🚀 Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging
```

* Despliega una instancia de **Kibana (1 réplica)**.
* Usa la imagen `docker.elastic.co/kibana/kibana:7.17.4`.
* Variables de entorno:

  * `ELASTICSEARCH_HOSTS`: apunta al servicio de Elasticsearch.
  * `ELASTICSEARCH_USERNAME` / `ELASTICSEARCH_PASSWORD`: autenticación con el clúster.
  * `SERVER_SSL_ENABLED: false`: deshabilita SSL interno para simplificar la configuración inicial.

---

### 🌐 Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  type: NodePort
```

* Expone Kibana en el puerto **5601** dentro del clúster y **30001** externamente.
* Permite acceso desde un navegador web mediante:

  ```
  http://<NodeIP>:30001
  ```

---

## 8. 🧾 Pod Temporal para Generar Certificados

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: elastic-cert-gen
  namespace: logging
```

* Crea un **Pod temporal** basado en la imagen de Elasticsearch.
* Ejecuta un comando que mantiene el contenedor activo por una hora (`sleep 3600`).
* Puede usarse para **generar o administrar certificados** requeridos por Elasticsearch y Fluentd.

---

## 9. 🏁 Finalización del Script

```bash
EOF
```

* Marca el final del bloque **here-document**.
* Todo lo que se definió anteriormente (los manifiestos) ya fue aplicado al clúster mediante `kubectl apply -f -`.

---

## 10. 🧠 Recomendaciones y Buenas Prácticas

* Ejecutar el script como **usuario con permisos administrativos** (`kubectl admin` o similar).

* Modificar el valor de `TuPasswordSeguro` antes de desplegar el stack.

* Instalar un **controlador de almacenamiento (StorageClass)** compatible, por ejemplo `nfs-csi`.

* Validar que los pods se encuentren en estado **Running** con:

  ```bash
  kubectl get pods -n logging
  ```

* Acceder a Kibana:

  ```
  http://<IP_del_nodo>:30001
  ```

* Verificar conectividad con Elasticsearch:

  ```bash
  curl -u elastic:TuPasswordSeguro -k https://<IP>:9200
  ```

---
📘 **Autor:** Axel Bautista y Emanuel López
📅 **Versión:** 1.0
🧭 **Compatibilidad:** Kubernetes v1.28 / Rocky Linux / Fedora / RHEL-like
