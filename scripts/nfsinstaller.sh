#!/usr/bin/env bash
# ================================================================
# Script de configuración automática de NFS + CSI Driver para Kubernetes
# Autor: Axel (adaptado por ChatGPT)
# Uso:
#   sudo ./setup-nfs-csi.sh <RED> <IP_SERVIDOR>
#
# Ejemplo:
#   sudo ./setup-nfs-csi.sh 192.168.109.0/24 192.168.109.210
#
# ================================================================

set -e

# --- Validación de parámetros ---
if [ "$#" -ne 2 ]; then
  echo "Uso: $0 <RED> <IP_SERVIDOR>"
  echo "Ejemplo: $0 192.168.109.0/24 192.168.109.210"
  exit 1
fi

NFS_NETWORK="$1"
NFS_SERVER_IP="$2"

# --- Instalación de NFS ---
echo ">>> Instalando nfs-utils..."
dnf install -y nfs-utils

echo ">>> Habilitando y arrancando el servicio NFS..."
systemctl enable --now nfs-server
systemctl start nfs-server
systemctl status nfs-server --no-pager

# --- Creación de directorio compartido ---
echo ">>> Creando directorio de almacenamiento NFS..."
mkdir -p /srv/nfs/k8s-storage
chmod 777 /srv/nfs/k8s-storage

# --- Configuración del archivo /etc/exports ---
echo ">>> Configurando /etc/exports..."
EXPORT_LINE="/srv/nfs/k8s-storage ${NFS_NETWORK}(rw,sync,no_subtree_check,no_root_squash)"
grep -qxF "$EXPORT_LINE" /etc/exports || echo "$EXPORT_LINE" >> /etc/exports

# --- Exportar recursos NFS ---
echo ">>> Exportando recursos..."
exportfs -arv
exportfs -v

# --- Instalación de Helm ---
echo ">>> Instalando Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
/usr/local/bin/helm version

# --- Instalar CSI Driver NFS ---
echo ">>> Agregando repositorio CSI NFS y desplegando..."
/usr/local/bin/helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
/usr/local/bin/helm repo update

/usr/local/bin/helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --version v4.5.0 || {
    echo "CSI NFS ya puede estar instalado. Continuando..."
}

# --- Esperar a que los pods del driver estén listos ---
echo ">>> Verificando estado del driver NFS..."
kubectl get pods -n kube-system -l app=csi-nfs-controller
kubectl get pods -n kube-system -l app=csi-nfs-node
kubectl get csidrivers

# --- Crear StorageClass ---
echo ">>> Creando StorageClass con IP ${NFS_SERVER_IP}..."
cat > nfs-storageclass.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: ${NFS_SERVER_IP}
  share: /srv/nfs/k8s-storage
reclaimPolicy: Retain
volumeBindingMode: Immediate
mountOptions:
  - hard
  - nfsvers=4.1
  - timeo=600
  - retrans=2
EOF

kubectl apply -f nfs-storageclass.yaml

echo ">>> Verificando StorageClass..."
kubectl get storageclass
kubectl describe storageclass nfs-csi

echo "✅ Instalación y configuración completada correctamente."


sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --permanent --add-service=mountd
sudo firewall-cmd --reload