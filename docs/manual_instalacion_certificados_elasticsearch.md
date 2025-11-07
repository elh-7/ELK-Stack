# Generación de Certificados SSL/TLS para Elasticsearch en Kubernetes

## 🎯 Propósito del Script

El propósito de este procedimiento es crear **certificados SSL/TLS** que permitan establecer **comunicaciones seguras (HTTPS y autenticadas)** entre los componentes del clúster de **Elasticsearch**.  

Este proceso se realiza mediante un **Pod temporal en Kubernetes** que utiliza la **imagen oficial de Elasticsearch** para generar los certificados, exportarlos y almacenarlos como un **Secret** dentro del namespace `logging`.

---

## 📁 Archivo del Script

- **Nombre sugerido:** `generate_elastic_certs.sh`  
- **Ubicación:** `/root/k8s-logging/scripts/generate_elastic_certs.sh`

El script automatiza todo el proceso en **cuatro fases principales**:

1. Creación del Pod generador de certificados.  
2. Ejecución de comandos internos para crear la **Autoridad Certificadora (CA)** y los certificados del nodo.  
3. Extracción de los archivos generados al sistema local.  
4. Creación de un **Secret** en Kubernetes con los certificados.

---

## 🧩 1. Creación del Pod temporal `elastic-cert-gen`

El script genera un manifiesto YAML (`elasticsearch-cert-gen.yaml`) que define un **Pod** con la imagen oficial de Elasticsearch (`docker.elastic.co/elasticsearch/elasticsearch:7.17.4`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: elastic-cert-gen
  namespace: logging
spec:
  containers:
  - name: elasticsearch
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.4
    command: ["/bin/sh", "-c", "sleep 3600"]
  restartPolicy: Never
````

**Propósito:**
Este contenedor sirve como **entorno aislado** para generar los certificados, sin afectar los Pods productivos del clúster.
El comando `sleep 3600` mantiene el contenedor activo durante una hora para permitir la ejecución manual o automatizada de los comandos necesarios.

---

## ⚙️ 2. Aplicación del Manifiesto y Acceso al Pod

```bash
kubectl apply -f elasticsearch-cert-gen.yaml
kubectl exec -it elastic-cert-gen -n logging -- /bin/bash
```

* `kubectl apply` crea el Pod en el namespace `logging`.
* `kubectl exec` permite acceder interactivamente a la consola del contenedor para ejecutar las herramientas de generación de certificados incluidas en Elasticsearch.

---

## 🔐 3. Generación de Certificados dentro del Contenedor

Dentro del Pod, se crean los directorios necesarios y se ejecutan los comandos de `elasticsearch-certutil` y `openssl` para generar los archivos **P12** y **PEM**:

```bash
mkdir -p /usr/share/elasticsearch/certs/pem
cd /usr/share/elasticsearch/certs

# Generar CA
elasticsearch-certutil ca --out elastic-ca.p12 --pass ""

# Generar certificados de nodo
elasticsearch-certutil cert --ca elastic-ca.p12 --out elastic-certificates.p12 --pass ""

# Extraer archivos en formato PEM
cd pem
openssl pkcs12 -in ../../elastic-certificates.p12 -out elasticsearch.crt -clcerts -nokeys -passin pass:
openssl pkcs12 -in ../../elastic-certificates.p12 -out elasticsearch.key -nocerts -nodes -passin pass:
openssl pkcs12 -in ../../elastic-certificates.p12 -out ca.crt -cacerts -nokeys -passin pass:
```

* `elasticsearch-certutil` crea una **CA** y los certificados firmados automáticamente.
* `openssl pkcs12` convierte los archivos **P12** en certificados y claves **PEM**, utilizables por otros componentes como **Kibana** y **Logstash**.

---

## 📤 4. Exportación de Certificados al Sistema Local

Una vez generados los archivos PEM dentro del contenedor, se copian al nodo administrador con:

```bash
kubectl cp elastic-cert-gen:/usr/share/elasticsearch/certs/pem/elasticsearch.crt ./elasticsearch.crt
kubectl cp elastic-cert-gen:/usr/share/elasticsearch/certs/pem/elasticsearch.key ./elasticsearch.key
kubectl cp elastic-cert-gen:/usr/share/elasticsearch/certs/pem/ca.crt ./ca.crt
```

> `kubectl cp` permite copiar archivos entre el contenedor y el entorno local o el nodo maestro del clúster.

---

## 🧱 5. Creación del Secret `elastic-certs`

Los certificados exportados se almacenan en un **Secret de Kubernetes**, que será referenciado por los Pods de Elasticsearch y Kibana para activar el cifrado **SSL/TLS**:

```bash
kubectl -n logging create secret generic elastic-certs \
  --from-file=certs/elasticsearch.crt \
  --from-file=certs/elasticsearch.key \
  --from-file=certs/ca.crt
```

Este **Secret** puede luego ser montado como volumen en los despliegues de Elasticsearch o Kibana usando la clave:

```yaml
secretName: elastic-certs
```

---

## ✅ Beneficios del Procedimiento

* 🔒 Asegura la **autenticación y cifrado TLS** entre los nodos del stack ELK.
* 🛡️ Evita la **exposición de certificados locales** en los hosts.
* ⚙️ Facilita la **automatización** del proceso dentro del clúster.
* 🧰 Permite un **mantenimiento controlado** mediante Pods temporales.

---

---

📘 **Autor:** Axel Bautista y Emanuel López
📅 **Versión:** 1.0
🧭 **Compatibilidad:** RHEL / Rocky / AlmaLinux / Fedora
