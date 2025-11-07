#!/usr/bin/env bash
# ==========================================================
# Script de generación y carga de certificados SSL para
# Elasticsearch en Kubernetes.
# ----------------------------------------------------------
# Uso:
#   ./generate_elk_certs.sh
# ==========================================================

set -e

# --- VARIABLES CONFIGURABLES ---
NAMESPACE="logging"
POD_NAME="elastic-cert-gen"
IMAGE="docker.elastic.co/elasticsearch/elasticsearch:7.17.4"
LOCAL_CERT_DIR="./certs"

# --- VALIDACIÓN DE DEPENDENCIAS ---
if ! command -v kubectl &> /dev/null; then
  echo "kubectl no está instalado o no está en el PATH."
  exit 1
fi

echo "Iniciando generación de certificados para Elasticsearch..."

# --- CREAR POD TEMPORAL PARA GENERAR CERTIFICADOS ---
echo "Creando pod temporal '${POD_NAME}'..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: elasticsearch
    image: ${IMAGE}
    command: ["/bin/sh", "-c", "sleep 3600"]
  restartPolicy: Never
EOF

# --- ESPERAR A QUE EL POD ESTÉ LISTO ---
echo "Esperando a que el pod esté en estado 'Running'..."
kubectl wait --for=condition=Ready pod/${POD_NAME} -n ${NAMESPACE} --timeout=120s

# --- CREAR DIRECTORIO Y GENERAR CERTIFICADOS DENTRO DEL POD ---
echo "Generando certificados dentro del contenedor..."
kubectl exec -n ${NAMESPACE} ${POD_NAME} -- bash -c "
  mkdir -p /usr/share/elasticsearch/certs/pem &&
  cd /usr/share/elasticsearch/certs &&
  elasticsearch-certutil ca --out elastic-ca.p12 --pass '' &&
  elasticsearch-certutil cert --ca elastic-ca.p12 --out elastic-certificates.p12 --pass '' &&
  cd pem &&
  openssl pkcs12 -in ../../elastic-certificates.p12 -out elasticsearch.crt -clcerts -nokeys -passin pass: &&
  openssl pkcs12 -in ../../elastic-certificates.p12 -out elasticsearch.key -nocerts -nodes -passin pass: &&
  openssl pkcs12 -in ../../elastic-certificates.p12 -out ca.crt -cacerts -nokeys -passin pass:
"

# --- CREAR DIRECTORIO LOCAL PARA COPIAR LOS CERTIFICADOS ---
mkdir -p ${LOCAL_CERT_DIR}

# --- COPIAR CERTIFICADOS DESDE EL POD AL NODO LOCAL ---
echo "Copiando certificados desde el contenedor..."
kubectl cp ${NAMESPACE}/${POD_NAME}:/usr/share/elasticsearch/certs/pem/elasticsearch.crt ${LOCAL_CERT_DIR}/elasticsearch.crt
kubectl cp ${NAMESPACE}/${POD_NAME}:/usr/share/elasticsearch/certs/pem/elasticsearch.key ${LOCAL_CERT_DIR}/elasticsearch.key
kubectl cp ${NAMESPACE}/${POD_NAME}:/usr/share/elasticsearch/certs/pem/ca.crt ${LOCAL_CERT_DIR}/ca.crt

# --- CREAR SECRET EN KUBERNETES ---
echo "Creando Secret 'elastic-certs' en el namespace '${NAMESPACE}'..."
kubectl -n ${NAMESPACE} create secret generic elastic-certs \
  --from-file=${LOCAL_CERT_DIR}/elasticsearch.crt \
  --from-file=${LOCAL_CERT_DIR}/elasticsearch.key \
  --from-file=${LOCAL_CERT_DIR}/ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -

# --- LIMPIEZA (OPCIONAL) ---
read -p "¿Deseas eliminar el pod temporal '${POD_NAME}'? (s/n): " confirm
if [[ $confirm == "s" || $confirm == "S" ]]; then
  kubectl delete pod ${POD_NAME} -n ${NAMESPACE}
  echo "Pod temporal eliminado."
else
  echo "El pod '${POD_NAME}' permanecerá en ejecución para revisión manual."
fi

echo "Certificados generados y cargados exitosamente en el Secret 'elastic-certs'."
echo "Certificados locales disponibles en: ${LOCAL_CERT_DIR}/"
