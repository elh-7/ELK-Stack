# 🧩 Instalación Automática de Kubernetes (v1.28)

## 🎯 Propósito general

Este script automatiza la instalación y configuración básica de un clúster de **Kubernetes (v1.28)** en sistemas Linux tipo **RHEL** (Rocky, Alma, CentOS, Fedora).

Permite configurar tanto nodos **master** como **worker**, incluyendo:

- Ajustes del sistema operativo: `hostname`, `swap`, `SELinux`, `firewall`, `kernel`
- Instalación de **containerd**
- Instalación de los componentes principales de Kubernetes: `kubeadm`, `kubelet`, `kubectl`
- Configuración de red, repositorios y archivo `/etc/hosts`
- Inicialización automática del nodo master

---

## ⚙️ Uso del script

```bash
./script.sh [m|w] [numero] [ip_inicial] [num_masters] [num_workers]
````

### Ejemplo:

```bash
./script.sh m 2 192.168.1.2 2 5
```

### Parámetros:

* `m|w` → Indica si el nodo será **master (m)** o **worker (w)**
* `numero` → Número secuencial del nodo (ej. `1`, `2`, `3`…)
* `ip_inicial` → IP base para generar las direcciones de todos los nodos
* `num_masters` → Número total de nodos master
* `num_workers` → Número total de nodos worker

---

## 🧱 Encabezado y control de errores

```bash
#!/bin/bash
set -e
```

* Define que el script se ejecute con **Bash**.
* `set -e`: hace que el script se detenga si ocurre cualquier error, evitando configuraciones incompletas.

---

## 🧩 Validación de argumentos

```bash
if [ $# -ne 5 ]; then
    echo "Uso: $0 [m|w] [numero] [ip_inicial] [num_masters] [num_workers]"
    exit 1
fi
```

* Verifica que se pasen los 5 argumentos requeridos.
* Si no se cumple, muestra un mensaje de uso y finaliza.

---

## 📦 Asignación de variables

```bash
tipo=$1
num=$2
ip_base=$3
num_masters=$4
num_workers=$5
```

Guarda los parámetros pasados en variables internas del script.

---

## 🧠 Definir tipo de nodo y nombre

```bash
if [[ "$tipo" == "m" ]]; then
    nodo="master"
elif [[ "$tipo" == "w" ]]; then
    nodo="worker"
else
    echo "Error: tipo inválido. Usa 'm' para master o 'w' para worker."
    exit 1
fi
```

* Determina si se trata de un nodo **master** o **worker**.
* Si no coincide con “m” o “w”, aborta la ejecución.

---

## 🖥️ Asignación del hostname

```bash
hostname="k8s-${nodo}$(printf '%02d' $num)"
sudo hostnamectl set-hostname "$hostname"
```

* Crea un nombre estándar para el nodo, ejemplo: `k8s-master01` o `k8s-worker02`.
* Lo aplica con `hostnamectl`.

---

## 🚫 Deshabilitar SWAP

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

* Desactiva la memoria swap temporalmente y comenta su entrada en `/etc/fstab`.
* Kubernetes no funciona correctamente con swap habilitado.

---

## 🛡️ Configurar SELinux

```bash
sudo setenforce 0 || true
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
```

* Cambia SELinux a modo **permissive**.
* Evita conflictos de permisos con pods y contenedores.

---

## 🔥 Configurar firewall

Bloques diferenciados según el tipo de nodo:

### Master:

```bash
sudo firewall-cmd --permanent --add-port={6443,2379,2380,10250,10251,10252,10257,10259,179}/tcp
sudo firewall-cmd --permanent --add-port=4789/udp
```

**Puertos abiertos:**

* `6443` → API Server
* `2379–2380` → etcd
* `10250–10259` → Componentes del plano de control
* `179`, `4789` → Calico / VXLAN networking

### Worker:

```bash
sudo firewall-cmd --permanent --add-port={179,10250,30000-32767}/tcp
sudo firewall-cmd --permanent --add-port=4789/udp
```

**Puertos abiertos:**

* `10250` → Kubelet
* `30000–32767` → Servicios NodePort
* `179`, `4789` → Tráfico de red entre pods

```bash
sudo firewall-cmd --reload
```

* Aplica los cambios del firewall.

---

## ⚙️ Cargar módulos del kernel

```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

* Habilita los módulos `overlay` (archivos de contenedores) y `br_netfilter` (tráfico en bridges).
* Necesarios para containerd y la red de Kubernetes.

---

## 🌐 Ajustes de red con sysctl

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
```

* Habilita el reenvío IPv4 y filtrado de tráfico en bridges.
* Requerido para el enrutamiento del tráfico de pods.

---

## 🧰 Instalación y configuración de Containerd

```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo -y
sudo dnf install -y containerd.io
```

* Agrega el repositorio oficial de Docker e instala **containerd**.

```bash
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

* Genera la configuración por defecto.
* Activa el uso de `systemd` como gestor de cgroups (requerido por Kubernetes).
* Reinicia y habilita el servicio.

---

## 📦 Agregar repositorio oficial de Kubernetes

```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
EOF
```

* Crea el archivo del repositorio oficial de Kubernetes (versión estable **1.28**).

---

## 🧱 Instalación de componentes principales

```bash
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
```

Instala los binarios esenciales:

* `kubelet`: agente del nodo
* `kubeadm`: inicializa el clúster
* `kubectl`: cliente de administración

---

## 🗺️ Configurar `/etc/hosts`

```bash
IFS='.' read -r o1 o2 o3 o4 <<< "$ip_base"
total_nodos=$((num_masters + num_workers))
# ...
echo "$ip $nombre" | sudo tee -a /etc/hosts
```

* Genera entradas para todos los nodos en `/etc/hosts` usando la IP base.

**Ejemplo:**

```
192.168.1.2  k8s-master01
192.168.1.3  k8s-master02
192.168.1.4  k8s-worker01
```

Permite la resolución de nombres interna entre nodos.

---

## 🚀 Inicializar el nodo

### Nodo Master:

```bash
sudo kubeadm init --control-plane-endpoint=$hostname
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

* Inicializa el plano de control.
* Crea la configuración para `kubectl`.
* Permite al usuario administrar el clúster.

### Nodo Worker:

```bash
echo "Worker preparado. Use el comando 'kubeadm join' del master..."
```

* Indica que el nodo está listo para unirse mediante el comando `kubeadm join` generado por el master.

---

📘 **Autor:** Axel Bautista y Emanuel López
📅 **Versión:** 1.0
🧭 **Compatibilidad:** RHEL / Rocky / AlmaLinux / Fedora

```
