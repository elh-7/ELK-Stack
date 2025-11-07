#!/bin/bash
# ==========================================================
# Script de instalación automatizada de Kubernetes
# Uso:
#   ./script.sh [m|w] [numero] [ip_inicial] [num_masters] [num_workers]
# Ejemplo:
#   ./script.sh m 2 192.168.1.2 2 5
# ==========================================================

set -e

# --- Validación de argumentos ---
if [ $# -ne 5 ]; then
    echo "Uso: $0 [m|w] [numero] [ip_inicial] [num_masters] [num_workers]"
    exit 1
fi

tipo=$1
num=$2
ip_base=$3
num_masters=$4
num_workers=$5

if [[ "$tipo" == "m" ]]; then
    nodo="master"
elif [[ "$tipo" == "w" ]]; then
    nodo="worker"
else
    echo "Error: tipo inválido. Usa 'm' para master o 'w' para worker."
    exit 1
fi

hostname="k8s-${nodo}$(printf '%02d' $num)"
echo "Configurando nodo: $hostname"

# --- Configurar hostname ---
sudo hostnamectl set-hostname "$hostname"
export HOSTNAME=$(hostname)
echo $HOSTNAME

# --- Deshabilitar swap ---
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# --- Deshabilitar SELinux ---
sudo setenforce 0 || true
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

# --- Configurar firewall ---
if [[ "$tipo" == "m" ]]; then
    echo "Configurando firewall para master..."
    sudo firewall-cmd --permanent --add-port={6443,2379,2380,10250,10251,10252,10257,10259,179}/tcp
    sudo firewall-cmd --permanent --add-port=4789/udp
else
    echo "Configurando firewall para worker..."
    sudo firewall-cmd --permanent --add-port={179,10250,30000-32767}/tcp
    sudo firewall-cmd --permanent --add-port=4789/udp
fi
sudo firewall-cmd --reload

# --- Configurar módulos del kernel ---
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# --- Configurar sysctl ---
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# --- Instalar containerd ---
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo -y
sudo dnf install -y containerd.io
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# --- Agregar repositorio de Kubernetes ---
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# --- Instalar Kubernetes ---
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# --- Agregar entradas a /etc/hosts ---
echo "Agregando entradas a /etc/hosts..."

# Extraer los primeros tres octetos de la IP base
IFS='.' read -r o1 o2 o3 o4 <<< "$ip_base"

total_nodos=$((num_masters + num_workers))
ip_octeto=$o4

for ((i=1; i<=total_nodos; i++)); do
    ip="${o1}.${o2}.${o3}.${ip_octeto}"
    if (( i <= num_masters )); then
        nombre="k8s-master$(printf '%02d' $i)"
    else
        idx=$((i - num_masters))
        nombre="k8s-worker$(printf '%02d' $idx)"
    fi

    if ! grep -q "$nombre" /etc/hosts; then
        echo "$ip $nombre" | sudo tee -a /etc/hosts > /dev/null
    fi

    ip_octeto=$((ip_octeto + 1))
done

echo "✅ Entradas agregadas a /etc/hosts correctamente."

# --- Inicializar master o preparar worker ---
if [[ "$tipo" == "m" ]]; then
    echo "Inicializando el nodo master..."
    sudo kubeadm init --control-plane-endpoint=$hostname

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo "✅ Master inicializado correctamente."
else
    echo "✅ Worker preparado. Use el comando 'kubeadm join' del master para unir este nodo."
fi
