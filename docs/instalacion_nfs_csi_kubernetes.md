# 🗂️ Instalación y Configuración Automática de NFS + CSI Driver para Kubernetes

## 🎯 Propósito del Script

Este documento describe el procedimiento técnico para la **instalación y configuración automatizada del servicio NFS (Network File System)** junto con el **controlador CSI (Container Storage Interface)** para **Kubernetes**, permitiendo el **almacenamiento persistente de volúmenes dinámicos** dentro del clúster.

El proceso se realiza mediante un **script Bash** que ejecuta paso a paso todas las operaciones necesarias de instalación, configuración y despliegue.

NOTA IMPORTANTE: Instalar nfs utils en todos los nodos. 

---

## 📜 Descripción del Script

**Nombre del archivo:** `setup-nfs-csi.sh`

### 🧭 Modo de ejecución:
```bash
sudo ./setup-nfs-csi.sh <RED> <IP_SERVIDOR>
````

**Ejemplo:**

```bash
sudo ./setup-nfs-csi.sh 192.168.109.0/24 192.168.109.210
```

**Parámetros:**

* `<RED>` → Rango de red de los nodos Kubernetes (ej. `192.168.109.0/24`)
* `<IP_SERVIDOR>` → Dirección IP del servidor NFS (el nodo donde se ejecutará el script)

---

## ⚙️ Descripción Detallada del Proceso

### 🧩 Validación de parámetros

Antes de iniciar, el script verifica que se hayan proporcionado los dos parámetros requeridos (**red** e **IP del servidor**).
Si no se cumplen, muestra un mensaje de ayuda y se detiene la ejecución.

```bash
if [ "$#" -ne 2 ]; then
  echo "Uso: $0 <RED> <IP_SERVIDOR>"
  exit 1
fi
```

---

### 📦 Instalación y habilitación del servicio NFS

El script instala el paquete `nfs-utils`, habilita y arranca el servicio `nfs-server`.

```bash
dnf install -y nfs-utils
systemctl enable --now nfs-server
systemctl start nfs-server
systemctl status nfs-server --no-pager
```

**Propósito:** Permitir compartir directorios del servidor con los nodos Kubernetes para almacenamiento persistente.

---

### 📁 Creación del directorio compartido

Se crea el punto de montaje `/srv/nfs/k8s-storage` con permisos amplios para facilitar el acceso desde los nodos del clúster.

```bash
mkdir -p /srv/nfs/k8s-storage
chmod 777 /srv/nfs/k8s-storage
```

---

### 🧾 Configuración del archivo `/etc/exports`

El script agrega la línea de exportación correspondiente a la red definida:

```
/srv/nfs/k8s-storage <RED>(rw,sync,no_subtree_check,no_root_squash)
```

Esto permite que los clientes dentro de la red `<RED>` puedan montar el recurso compartido con permisos de lectura y escritura.

```bash
grep -qxF "$EXPORT_LINE" /etc/exports || echo "$EXPORT_LINE" >> /etc/exports
exportfs -arv
exportfs -v
```

---

### 🚀 Instalación de Helm

Se descarga e instala **Helm**, el gestor de paquetes para Kubernetes.

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
/usr/local/bin/helm version
```

**Propósito:** Helm simplifica la instalación del **CSI Driver NFS** y otros componentes de Kubernetes.

---

### 📦 Instalación del CSI Driver NFS

Se agrega el repositorio oficial del controlador NFS y se despliega mediante Helm:

```bash
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --version v4.5.0
```

El script maneja el caso en que el driver ya esté instalado y continúa la ejecución.

---

### 🔍 Verificación del despliegue del CSI Driver

Se verifica que los Pods del driver estén activos y funcionando correctamente:

```bash
kubectl get pods -n kube-system -l app=csi-nfs-controller
kubectl get pods -n kube-system -l app=csi-nfs-node
kubectl get csidrivers
```

---

### 🗂️ Creación del StorageClass

El script genera automáticamente un archivo YAML (`nfs-storageclass.yaml`) con los parámetros correctos, incluyendo la **IP del servidor** y el **directorio compartido**:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: <IP_SERVIDOR>
  share: /srv/nfs/k8s-storage
reclaimPolicy: Retain
volumeBindingMode: Immediate
mountOptions:
  - hard
  - nfsvers=4.1
  - timeo=600
  - retrans=2
```

Luego, se aplica el manifiesto al clúster:

```bash
kubectl apply -f nfs-storageclass.yaml
kubectl get storageclass
kubectl describe storageclass nfs-csi
```

**Propósito:** Definir la política de aprovisionamiento dinámico de volúmenes NFS para los pods del clúster.

---

### 🔥 Configuración del Firewall

Finalmente, se habilitan los servicios necesarios en **firewalld** para permitir el tráfico NFS:

```bash
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=mountd
firewall-cmd --reload
```

---

## ✅ Resultado Final

Al concluir el proceso, el sistema quedará con:

* Servidor **NFS** configurado y exportando `/srv/nfs/k8s-storage`
* Controlador **CSI NFS** desplegado en el clúster
* **StorageClass** `nfs-csi` disponible para el aprovisionamiento de volúmenes persistentes
* **Firewall** correctamente configurado

---

## 🧪 Validación final

Puedes verificar la correcta creación del `StorageClass` con:

```bash
kubectl get storageclass
```

Y probar su funcionamiento creando un **PersistentVolumeClaim (PVC)** asociado al `nfs-csi`.

---

📘 **Autor:** Axel Bautista y Emanuel López
📅 **Versión:** 1.0
🧭 **Compatibilidad:** Kubernetes v1.28 / Rocky Linux / Fedora / RHEL-like

