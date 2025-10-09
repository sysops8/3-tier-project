# 🚀 Production-Ready инфраструктура E-Commerce на Proxmox

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)](https://argo-cd.readthedocs.io/)

> Полная DevOps инфраструктура с K3s, CI/CD, мониторингом и логированием для e-commerce приложений

---

## 📑 Содержание

- [Архитектура](#-архитектура)
- [Технологический стек](#-технологический-стек)
- [Спецификации инфраструктуры](#-спецификации-инфраструктуры)
- [Предварительные требования](#-предварительные-требования)
- [Руководство по установке](#-руководство-по-установке)
  - [1. Сетевая инфраструктура](#1-сетевая-инфраструктура)
  - [2. DNS сервер (BIND9)](#2-dns-сервер-bind9)
  - [3. NAT шлюз](#3-nat-шлюз)
  - [4. Объектное хранилище (MinIO)](#4-объектное-хранилище-minio)
  - [5. Kubernetes кластер (K3s)](#5-kubernetes-кластер-k3s)
  - [6. Постоянное хранилище (Longhorn)](#6-постоянное-хранилище-longhorn)
  - [7. LoadBalancer (MetalLB)](#7-loadbalancer-metallb)
  - [8. Ingress контроллер (Traefik)](#8-ingress-контроллер-traefik)
  - [9. Внешний доступ (ngrok Tunnel)](#9-внешний-доступ-ngrok-tunnel)
  - [10. CI/CD (Jenkins)](#10-cicd-jenkins)
  - [11. Мониторинг (Prometheus Stack)](#11-мониторинг-prometheus-stack)
  - [12. Логирование (ELK Stack)](#12-логирование-elk-stack)
  - [13. GitOps (ArgoCD)](#13-gitops-argocd)
  - [14. Развертывание приложения](#14-развертывание-приложения)
- [Проверка инфраструктуры](#-проверка-инфраструктуры)
- [Устранение неполадок](#-устранение-неполадок)

---

## 🎯 Архитектура

```
Интернет (серый IP)
    ↓
ngrok Cloud (автоматический TLS)
    ↓ [HTTP/HTTPS туннель]
    ↓
ngrok Agent (ngrok-tunnel VM)
    ↓ [внутренняя сеть]
    ↓
MetalLB LoadBalancer (192.168.100.100)
    ↓
Traefik Ingress контроллер
    ↓
┌──────────────────────────────────────────────────┐
│   K3s кластер (192.168.100.0/24)                │
│  ┌──────────┬──────────┬──────────┐             │
│  │ Master   │ Worker-1 │ Worker-2 │             │
│  │ 4C/8GB   │ 4C/10GB  │ 4C/10GB  │             │
│  └──────────┴──────────┴──────────┘             │
│                                                  │
│  Приложения:                                     │
│  - EzyShop (E-commerce)                         │
│  - ArgoCD (GitOps развертывание)                │
│  - Prometheus/Grafana (Метрики)                 │
│  - Elasticsearch/Kibana (Логи)                  │
│  - AlertManager → Slack                         │
└──────────────────────────────────────────────────┘
    ↓                    ↓
Jenkins CI          MinIO S3
(192.168.100.101)   (192.168.100.20)

Инфраструктурные сервисы:
- BIND9 DNS (192.168.100.53)
- NAT шлюз (192.168.100.50)
- MetalLB LoadBalancer (192.168.100.100)
- ngrok Tunnel (192.168.100.60)
- Jumphost (192.168.100.5)
```

### Сетевая топология

```
10.0.10.0/24 (vmbr0) - Внешняя сеть
├── 10.0.10.1        - ISP шлюз
├── 10.0.10.50       - nat-gateway (eth0)
├── 10.0.10.53       - dns-server (eth0)
├── 10.0.10.60       - ngrok-tunnel (eth0)
├── 10.0.10.102      - jumphost (eth0)
└── 10.0.10.200      - Proxmox хост

192.168.100.0/24 (vmbr1) - Внутренняя сеть
├── 192.168.100.1      - Proxmox vmbr1
├── 192.168.100.5      - jumphost (eth1)
├── 192.168.100.10     - k3s-master
├── 192.168.100.11     - k3s-worker-1
├── 192.168.100.12     - k3s-worker-2
├── 192.168.100.20     - minio
├── 192.168.100.50     - nat-gateway (eth1)
├── 192.168.100.53     - dns-server (eth1)
├── 192.168.100.60     - ngrok-tunnel (eth1)
├── 192.168.100.100    - MetalLB LoadBalancer (виртуальный IP)
├── 192.168.100.101    - jenkins
└── 192.168.100.100-110 - MetalLB пул IP
```

---

## 🛠️ Технологический стек

### Инфраструктура
- **Виртуализация**: Proxmox VE 8.x
- **ОС**: Ubuntu Server 22.04 LTS

### Оркестрация
- **Оркестрация контейнеров**: K3s (облегченный Kubernetes)
- **Менеджер пакетов**: Helm 3
- **GitOps**: ArgoCD

### CI/CD
- **CI сервер**: Jenkins
- **Git**: GitHub/GitLab
- **Container Registry**: Docker Hub

### Хранилище
- **Постоянное хранилище**: Longhorn
- **Объектное хранилище**: MinIO (S3-совместимое)
- **База данных**: PostgreSQL 15

### Сеть
- **DNS**: BIND9
- **Ingress**: Traefik 2.x
- **LoadBalancer**: MetalLB (режим L2)
- **Внешний доступ**: ngrok Tunnel

### Мониторинг и логирование
- **Метрики**: Prometheus + Grafana
- **Оповещения**: AlertManager
- **Логирование**: Elasticsearch + Kibana
- **Сбор логов**: Filebeat

---

## 📊 Спецификации инфраструктуры

### Виртуальные машины

| Hostname | vCPU | RAM | Диск | Сеть | IP | Роль |
|----------|------|-----|------|---------|-----|------|
| dns-server | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.53<br>192.168.100.53 | DNS сервер (BIND9) |
| nat-gateway | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.50<br>192.168.100.50 | NAT шлюз |
| ngrok-tunnel | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.60<br>192.168.100.60 | ngrok туннель |
| k3s-master | 4 | 8GB | 60GB (SSD) | vmbr1 | 192.168.100.10 | K3s Control Plane |
| k3s-worker-1 | 4 | 10GB | 80GB (SSD) | vmbr1 | 192.168.100.11 | K3s рабочий узел |
| k3s-worker-2 | 4 | 10GB | 80GB (SSD) | vmbr1 | 192.168.100.12 | K3s рабочий узел |
| jenkins | 2 | 4GB | 40GB | vmbr1 | 192.168.100.101 | CI сервер |
| minio | 2 | 4GB | 20GB+100GB (HDD) | vmbr1 | 192.168.100.20 | Объектное хранилище |
| jumphost | 1 | 2GB | 20GB | vmbr0+vmbr1 | 10.0.10.102<br>192.168.100.5 | Хост управления |

**Всего ресурсов**: 19 vCPU, 40GB RAM, 420GB диск

### Карта сервисов

| Сервис | Внутренний домен | Внешний доступ (ngrok) | Порт |
|---------|----------------|-----------------|------|
| EzyShop | ezyshop.local.lab | https://YOUR-DOMAIN.ngrok.io | 80/443 |
| ArgoCD | argocd.local.lab | https://YOUR-DOMAIN.ngrok.io/argocd | 80/443 |
| Grafana | grafana.local.lab | https://YOUR-DOMAIN.ngrok.io/grafana | 80/443 |
| Prometheus | prometheus.local.lab | https://YOUR-DOMAIN.ngrok.io/prometheus | 80/443 |
| Kibana | kibana.local.lab | https://YOUR-DOMAIN.ngrok.io/kibana | 80/443 |
| Jenkins | jenkins.local.lab | - (только внутри) | 8080 |
| MinIO консоль | minio.local.lab | - (только внутри) | 9001 |
| Longhorn UI | longhorn.local.lab | - (только внутри) | 80 |

---

## ✅ Предварительные требования

- Установленный и настроенный Proxmox VE 8.x
- Загруженный ISO Ubuntu 22.04 в Proxmox
- Аккаунт ngrok (бесплатный: https://ngrok.com)
- Аккаунт GitHub/GitLab
- Базовые знания Linux, Kubernetes и CI/CD

---

## 📖 Руководство по установке

### 1. Сетевая инфраструктура

#### Настройка сети Proxmox

SSH к хосту Proxmox:

```bash
ssh root@10.0.10.200
```

Редактирование конфигурации сети:

```bash
nano /etc/network/interfaces
```

Добавьте конфигурацию внутреннего моста:

```
auto vmbr1
iface vmbr1 inet static
    address 192.168.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    comment "Внутренняя сеть"
```

Применить изменения:

```bash
ifreload -a
ip addr show vmbr1  # Проверка
```

#### Создание виртуальных машин

Создайте все VM через Proxmox Web UI или используйте Terraform. Настройте сеть:
- **Внешний интерфейс (eth0)**: vmbr0, статический IP из 10.0.10.0/24
- **Внутренний интерфейс (eth1)**: vmbr1, статический IP из 192.168.100.0/24

---

### 2. DNS сервер (BIND9)

#### Установка BIND9

SSH к dns-server:

```bash
ssh admin@10.0.10.53
```

Установка пакетов:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y bind9 bind9utils bind9-doc dnsutils

# Остановить systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo rm -f /etc/resolv.conf
```

#### Настройка BIND9

Создание основной конфигурации:

```bash
sudo bash -c 'cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    # Слушать на всех интерфейсах
    listen-on { 192.168.100.53; 10.0.10.53; };
    listen-on-v6 { none; };

    # Разрешить запросы из локальных сетей
    allow-query { 
        localhost; 
        192.168.100.0/24; 
        10.0.10.0/24; 
    };

    # Рекурсия для локальных сетей
    recursion yes;
    allow-recursion { 
        localhost; 
        192.168.100.0/24; 
        10.0.10.0/24; 
    };

    # Переадресация на публичный DNS
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    dnssec-validation auto;
    auth-nxdomain no;
};
EOF'
```

Настройка зон:

```bash
sudo bash -c 'cat > /etc/bind/named.conf.local <<EOF
# Прямая зона для local.lab
zone "local.lab" {
    type master;
    file "/etc/bind/zones/db.local.lab";
    allow-update { none; };
};

# Обратная зона для 192.168.100.0/24
zone "100.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.100";
    allow-update { none; };
};

# Обратная зона для 10.0.10.0/24
zone "10.0.10.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.10.0.10";
    allow-update { none; };
};
EOF'
```

#### Создание файлов зон

Создать директорию зон:

```bash
sudo mkdir -p /etc/bind/zones
```

**Прямая зона (db.local.lab):**

```bash
sudo bash -c 'cat > /etc/bind/zones/db.local.lab <<EOF
\$TTL    604800
@       IN      SOA     ns1.local.lab. admin.local.lab. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL

; Name серверы
@       IN      NS      ns1.local.lab.
ns1     IN      A       192.168.100.53

; Инфраструктурные VM
dns-server      IN      A       192.168.100.53
nat-gateway     IN      A       192.168.100.50
ngrok-tunnel    IN      A       192.168.100.60
jumphost        IN      A       192.168.100.5

; Kubernetes кластер
k3s-master      IN      A       192.168.100.10
k3s-worker-1    IN      A       192.168.100.11
k3s-worker-2    IN      A       192.168.100.12

; Дополнительные сервисы
jenkins         IN      A       192.168.100.101
minio           IN      A       192.168.100.20

; Записи сервисов (Ingress)
ezyshop         IN      A       192.168.100.100
argocd          IN      A       192.168.100.100
grafana         IN      A       192.168.100.100
prometheus      IN      A       192.168.100.100
alertmanager    IN      A       192.168.100.100
kibana          IN      A       192.168.100.100
longhorn        IN      A       192.168.100.100
traefik         IN      A       192.168.100.100

; CNAME алиасы
www.ezyshop     IN      CNAME   ezyshop.local.lab.
ci              IN      CNAME   jenkins.local.lab.
s3              IN      CNAME   minio.local.lab.
EOF'
```

#### Запуск BIND9

```bash
# Проверка конфигурации
sudo named-checkconf
sudo named-checkzone local.lab /etc/bind/zones/db.local.lab

# Установка прав
sudo chown -R bind:bind /etc/bind/zones

# Запуск сервиса
sudo systemctl restart bind9
sudo systemctl enable bind9
sudo systemctl status bind9
```

#### Настройка DNS на всех VM

Создайте скрипт для настройки DNS:

```bash
# На jumphost создайте файл set-dns.sh
cat > /tmp/set-dns.sh <<'EOF'
#!/bin/bash

echo "Настройка DNS..."

# Остановка systemd-resolved
sudo systemctl disable systemd-resolved 2>/dev/null
sudo systemctl stop systemd-resolved 2>/dev/null
sudo rm -f /etc/resolv.conf

# Создание resolv.conf
sudo bash -c 'cat > /etc/resolv.conf <<EOL
nameserver 192.168.100.53
nameserver 8.8.8.8
search local.lab
EOL'

sudo chattr +i /etc/resolv.conf

echo "Настройка завершена!"

# Тестирование
echo "Тестирование DNS..."
nslookup k3s-master.local.lab
EOF

chmod +x /tmp/set-dns.sh
```

Примените скрипт на всех VM:

```bash
# Список всех внутренних хостов
HOSTS="k3s-master.local.lab k3s-worker-1.local.lab k3s-worker-2.local.lab jenkins.local.lab minio.local.lab nat-gateway.local.lab ngrok-tunnel.local.lab"

for host in $HOSTS; do
    echo "Настройка $host..."
    scp /tmp/set-dns.sh admin@${host}:/tmp/
    ssh admin@${host} "sudo bash /tmp/set-dns.sh"
    echo ""
done
```

---

### 3. NAT шлюз

#### Настройка NAT на nat-gateway

SSH к nat-gateway:

```bash
ssh admin@10.0.10.50
```

Включить IP forwarding:

```bash
# Временно
sudo sysctl -w net.ipv4.ip_forward=1

# Постоянно
sudo bash -c 'echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'
sudo sysctl -p
```

Настройка NAT с iptables:

```bash
# Установка iptables-persistent
sudo apt update
sudo apt install -y iptables-persistent

# Настройка NAT
# eth0 - внешняя сеть (10.0.10.0/24)
# eth1 - внутренняя сеть (192.168.100.0/24)

sudo iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранить правила
sudo netfilter-persistent save

# Проверка
sudo iptables -t nat -L -v -n
sudo iptables -L FORWARD -v -n
```

#### Настройка сети на nat-gateway

```bash
# Настройка через netplan
sudo tee /etc/netplan/00-installer-config.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [10.0.10.50/24]
      routes:
        - to: 0.0.0.0/0
          via: 10.0.10.1
      nameservers:
        addresses: [192.168.100.53, 8.8.8.8]
        search: [local.lab]
    eth1:
      dhcp4: no
      addresses: [192.168.100.50/24]
      nameservers:
        addresses: [192.168.100.53]
        search: [local.lab]
EOF

sudo netplan apply
```

---

### 4. Объектное хранилище (MinIO)

#### Подготовка диска данных

SSH к minio:

```bash
ssh admin@minio.local.lab
```

Форматирование и монтирование второго диска:

```bash
# Проверка дисков
lsblk  # sda (20GB) - система, sdb (100GB) - данные

# Форматирование /dev/sdb
sudo mkfs.ext4 /dev/sdb

# Создание точки монтирования
sudo mkdir -p /mnt/minio-data

# Монтирование
sudo mount /dev/sdb /mnt/minio-data

# Получить UUID
UUID=$(sudo blkid -s UUID -o value /dev/sdb)

# Добавить в fstab для автомонтирования
echo "UUID=$UUID /mnt/minio-data ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Проверка
df -h | grep minio
sudo mount -a
```

#### Установка MinIO

```bash
# Скачать бинарник
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Проверка
minio --version

# Создать пользователя
sudo useradd -r minio-user -s /sbin/nologin

# Создать директории
sudo mkdir -p /mnt/minio-data/{buckets,config}
sudo chown -R minio-user:minio-user /mnt/minio-data
```

#### Настройка Systemd сервиса

```bash
sudo tee /etc/systemd/system/minio.service > /dev/null <<EOF
[Unit]
Description=MinIO объектное хранилище
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
User=minio-user
Group=minio-user
ProtectSystem=full
PrivateDevices=true
PrivateTmp=true

Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin123"
Environment="MINIO_SERVER_URL=http://minio.local.lab:9000"
Environment="MINIO_BROWSER_REDIRECT_URL=http://minio.local.lab:9001"

ExecStart=/usr/local/bin/minio server /mnt/minio-data --console-address ":9001" --address ":9000"

Restart=always
RestartSec=5s
LimitNOFILE=65536
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
```

Запуск MinIO:

```bash
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
sudo systemctl status minio

# Проверка
curl -I http://minio.local.lab:9000/minio/health/live  # Должен вернуть 200 OK
```

---

### 5. Kubernetes кластер (K3s)

#### Подготовка всех узлов

На **всех узлах** (master + workers):

```bash
# Отключить swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Загрузить модули ядра
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k3s.conf > /dev/null <<EOF
overlay
br_netfilter
EOF

# Настроить sysctl
sudo tee /etc/sysctl.d/k3s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Установить базовые пакеты
sudo apt update
sudo apt install -y curl wget git vim
```

#### Установка K3s Master

SSH к k3s-master:

```bash
ssh admin@k3s-master.local.lab
```

Установка:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --node-name k3s-master \
  --cluster-domain local.lab \
  --node-ip 192.168.100.10 \
  --node-external-ip 192.168.100.10 \
  --tls-san k3s-master.local.lab \
  --tls-san 192.168.100.10 \
  --kube-apiserver-arg="--service-node-port-range=80-32767"

# Подождать запуска (30-60 секунд)
sleep 60

# Проверка
sudo systemctl status k3s
sudo kubectl get nodes
```

Получить токен присоединения:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
# Сохраните этот токен! Пример: K10abc123def456ghi789jkl012mno345::server:abc123def456
```

#### Установка K3s Workers

**Worker 1:**

```bash
ssh admin@k3s-worker-1.local.lab

# Замените <TOKEN> токеном от master
TOKEN="<TOKEN_FROM_MASTER>"
curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master.local.lab:6443 \
  K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="agent" sh -s - \
  --node-name k3s-worker-1 \
  --node-ip 192.168.100.11

sudo systemctl status k3s-agent
```

**Worker 2:**

```bash
ssh admin@k3s-worker-2.local.lab

TOKEN="<TOKEN_FROM_MASTER>"
curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master.local.lab:6443 \
  K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="agent" sh -s - \
  --node-name k3s-worker-2 \
  --node-ip 192.168.100.12

sudo systemctl status k3s-agent
```

#### Проверка кластера

На master:

```bash
sudo kubectl get nodes -o wide
# Ожидается: Все 3 узла в статусе Ready

sudo kubectl get pods -A
```

#### Настройка доступа с jumphost

SSH к jumphost:

```bash
ssh admin@jumphost.local.lab
```

Установка kubectl и настройка доступа:

```bash
# Установка kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Копирование kubeconfig
mkdir -p ~/.kube
scp admin@k3s-master.local.lab:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Замена адреса сервера
sed -i 's/127.0.0.1/k3s-master.local.lab/g' ~/.kube/config

# Установка правильных прав
chmod 600 ~/.kube/config

# Проверка доступа
kubectl get nodes
kubectl cluster-info
```

---

### 6. Постоянное хранилище (Longhorn)

#### Подготовка рабочих узлов

На **всех рабочих узлах**:

```bash
# Worker 1
ssh admin@k3s-worker-1.local.lab
sudo apt update
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
sudo systemctl status iscsid

# Worker 2
ssh admin@k3s-worker-2.local.lab
sudo apt update
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
sudo systemctl status iscsid
```

#### Установка Longhorn

С jumphost:

```bash
# Добавить Helm repo
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Создать namespace
kubectl create namespace longhorn-system

# Установить Longhorn
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --set defaultSettings.defaultDataPath="/var/lib/longhorn" \
  --set defaultSettings.replicaAutoBalance="best-effort"

# Подождать готовности (2-5 минут)
kubectl -n longhorn-system wait --for=condition=ready pod -l app=longhorn --timeout=300s
```

#### Настройка Longhorn как default StorageClass

```bash
# Установка Longhorn как default
kubectl patch storageclass longhorn \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Удаление default с local-path
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Проверка
kubectl get storageclass
```

#### Создание Ingress для Longhorn UI

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: longhorn.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
EOF
```

---

### 7. LoadBalancer (MetalLB)

#### Установка MetalLB

```bash
# Добавить Helm репозиторий
helm repo add metallb https://metallb.github.io/metallb
helm repo update

# Создать namespace
kubectl create namespace metallb-system

# Установить MetalLB
helm install metallb metallb/metallb \
  --namespace metallb-system

# Подождать готовности (30-60 секунд)
kubectl -n metallb-system wait --for=condition=ready pod -l app=metallb --timeout=120s
```

#### Настройка пула IP адресов

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: main-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.100.100-192.168.100.110  # 10 IP для сервисов
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - main-pool
EOF
```

#### Проверка MetalLB

```bash
# Проверка подов
kubectl -n metallb-system get pods

# Проверка пула IP
kubectl -n metallb-system get ipaddresspool
kubectl -n metallb-system get l2advertisement
```

---

### 8. Ingress контроллер (Traefik)

#### Создание файла значений с LoadBalancer

```bash
cat > /tmp/traefik-values.yaml <<EOF
# Использовать LoadBalancer вместо NodePort
service:
  type: LoadBalancer
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.100.100

ports:
  web:
    port: 80
    exposedPort: 80
  websecure:
    port: 443
    exposedPort: 443

ingressRoute:
  dashboard:
    enabled: true

logs:
  general:
    level: INFO
  access:
    enabled: true

metrics:
  prometheus:
    enabled: true
    addEntryPointsLabels: true
    addServicesLabels: true

persistence:
  enabled: true
  size: 1Gi
  storageClass: longhorn

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Перенаправление HTTP на HTTPS
additionalArguments:
  - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
  - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
  - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
EOF
```

#### Установка Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

kubectl create namespace traefik

helm install traefik traefik/traefik \
  --namespace traefik \
  --values /tmp/traefik-values.yaml

# Подождать готовности
kubectl -n traefik wait --for=condition=ready pod -l app.kubernetes.io/name=traefik --timeout=120s
```

#### Проверка Traefik LoadBalancer

```bash
kubectl -n traefik get pods
kubectl -n traefik get svc

# Должен показать EXTERNAL-IP: 192.168.100.100
# NAME      TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)
# traefik   LoadBalancer   10.43.x.x       192.168.100.100   80:xxx/TCP,443:xxx/TCP
```

#### Обновление DNS записей

Все сервисы теперь указывают на IP MetalLB LoadBalancer:

```bash
ssh admin@dns-server.local.lab

# Обновить файл зоны
sudo sed -i 's/192.168.100.10/192.168.100.100/g' /etc/bind/zones/db.local.lab

# Увеличить Serial
sudo sed -i 's/Serial.*$/Serial: 2/' /etc/bind/zones/db.local.lab

# Проверка синтаксиса
sudo named-checkzone local.lab /etc/bind/zones/db.local.lab

# Перезагрузить зону
sudo rndc reload local.lab

exit

# Тест разрешения DNS
dig @192.168.100.53 ezyshop.local.lab +short
# Должен вернуть: 192.168.100.100
```

---

### 9. Внешний доступ (ngrok Tunnel)

#### Установка ngrok

SSH к ngrok-tunnel:

```bash
ssh admin@ngrok-tunnel.local.lab

# Обновить систему
sudo apt update && sudo apt upgrade -y

# Установить ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list && \
  sudo apt update && \
  sudo apt install ngrok

# Проверка
ngrok version
```

#### Настройка ngrok

```bash
# Авторизация (замените YOUR_AUTHTOKEN на ваш токен из https://dashboard.ngrok.com)
ngrok config add-authtoken YOUR_AUTHTOKEN

# Создать конфигурацию
mkdir -p ~/.config/ngrok
cat > ~/.config/ngrok/ngrok.yml <<EOF
version: "2"
authtoken: YOUR_AUTHTOKEN

tunnels:
  ezyshop:
    proto: http
    addr: 192.168.100.100:80
    host_header: rewrite
#    bind_tls: true

region: us
log_level: info
log_format: json
log: /var/log/ngrok.log
EOF

# Создать systemd service
sudo tee /etc/systemd/system/ngrok.service > /dev/null <<EOF
[Unit]
Description=ngrok tunnel
After=network.target

[Service]
Type=simple
User=admin
WorkingDirectory=/home/admin
ExecStart=/usr/local/bin/ngrok start --all --config /home/admin/.config/ngrok/ngrok.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Создать файл логов
sudo touch /var/log/ngrok.log
sudo chown admin:admin /var/log/ngrok.log

# Запустить ngrok
sudo systemctl daemon-reload
sudo systemctl enable ngrok
sudo systemctl start ngrok

# Проверка статуса
sudo systemctl status ngrok

# Посмотреть активные туннели
curl -s http://localhost:4040/api/tunnels | jq
```

#### Получение ngrok URL

```bash
# Получить публичный URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "Ваш ngrok URL: $NGROK_URL"

# Сохранить в файл
echo $NGROK_URL > ~/ngrok-url.txt
```

#### Настройка NAT для внутреннего доступа

На ngrok-tunnel VM:

```bash
# Включить IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Настроить iptables
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранить правила
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
sudo sysctl -p
```

---

### 10. CI/CD (Jenkins)

#### Установка Jenkins

SSH к jenkins:

```bash
ssh admin@jenkins.local.lab
```

Установка Java:

```bash
sudo apt update
sudo apt install -y fontconfig openjdk-17-jre
java -version
```

Установка Jenkins:

```bash
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```

Получить начальный пароль:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
# Сохраните этот пароль!
```

**Доступ**: `http://jenkins.local.lab:8080`

#### Установка дополнительных инструментов

```bash
# Docker
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker jenkins

# Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Maven
sudo apt install -y maven

# Git
sudo apt install -y git

# Перезапуск Jenkins
sudo systemctl restart jenkins
```

#### Настройка kubectl для Jenkins

```bash
sudo mkdir -p /var/lib/jenkins/.kube
sudo scp admin@k3s-master.local.lab:/etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config
sudo sed -i 's/127.0.0.1/k3s-master.local.lab/g' /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config

# Тест
sudo -u jenkins kubectl get nodes
```

---

### 11. Мониторинг (Prometheus Stack)

#### Установка kube-prometheus-stack

С jumphost:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

cat > /tmp/prometheus-values.yaml <<EOF
prometheus:
  prometheusSpec:
    retention: 15d
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi

grafana:
  adminPassword: admin123
  persistence:
    enabled: true
    storageClassName: longhorn
    size: 10Gi
  ingress:
    enabled: true
    hosts:
      - grafana.local.lab

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true
EOF

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/prometheus-values.yaml

# Ожидание готовности
kubectl -n monitoring wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --timeout=300s
```

#### Создание Ingress для сервисов мониторинга

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
spec:
  rules:
  - host: prometheus.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alertmanager-ingress
  namespace: monitoring
spec:
  rules:
  - host: alertmanager.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-alertmanager
            port:
              number: 9093
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
spec:
  rules:
  - host: grafana.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
EOF
```

**Доступ**:
- Grafana: `http://grafana.local.lab` (admin/admin123)
- Prometheus: `http://prometheus.local.lab`
- AlertManager: `http://alertmanager.local.lab`

---

### 12. Логирование (ELK Stack)

#### Установка Elasticsearch

```bash
helm repo add elastic https://helm.elastic.co
helm repo update

kubectl create namespace logging

cat > /tmp/elasticsearch-values.yaml <<EOF
replicas: 1
minimumMasterNodes: 1

resources:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: 1000m
    memory: 4Gi

volumeClaimTemplate:
  storageClassName: longhorn
  accessModes: [ "ReadWriteOnce" ]
  resources:
    requests:
      storage: 30Gi

esJavaOpts: "-Xmx2g -Xms2g"
EOF

helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values /tmp/elasticsearch-values.yaml

# Ожидание готовности
kubectl -n logging wait --for=condition=ready pod -l app=elasticsearch-master --timeout=300s
```

#### Установка Kibana

```bash
cat > /tmp/kibana-values.yaml <<EOF
resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi

service:
  type: ClusterIP
  port: 5601
EOF

helm install kibana elastic/kibana \
  --namespace logging \
  --values /tmp/kibana-values.yaml

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana-ingress
  namespace: logging
spec:
  rules:
  - host: kibana.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kibana-kibana
            port:
              number: 5601
EOF
```

#### Установка Filebeat

```bash
cat > /tmp/filebeat-values.yaml <<EOF
daemonset:
  enabled: true
  
filebeatConfig:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
      - add_kubernetes_metadata:
          host: \${NODE_NAME}
          matchers:
          - logs_path:
              logs_path: "/var/log/containers/"

    output.elasticsearch:
      host: 'elasticsearch-master.logging.svc.cluster.local:9200'
      indices:
        - index: "filebeat-%{+yyyy.MM.dd}"

resources:
  requests:
    cpu: 100m
    memory: 100Mi
  limits:
    cpu: 200m
    memory: 200Mi
EOF

helm install filebeat elastic/filebeat \
  --namespace logging \
  --values /tmp/filebeat-values.yaml
```

**Доступ**: `http://kibana.local.lab`

---

### 13. GitOps (ArgoCD)

#### Установка ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Ожидание готовности
kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s
```

#### Создание Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: argocd.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
```

#### Получить пароль

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Сохраните этот пароль!
```

**Доступ**: `http://argocd.local.lab`  
**Учетные данные**: admin / <пароль>

---

### 14. Развертывание приложения

#### Создание namespace и deployment

```bash
kubectl create namespace ezyshop

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ezyshop-frontend
  namespace: ezyshop
  labels:
    app: ezyshop
    component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ezyshop
      component: frontend
  template:
    metadata:
      labels:
        app: ezyshop
        component: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-frontend
  namespace: ezyshop
spec:
  selector:
    app: ezyshop
    component: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ezyshop-ingress
  namespace: ezyshop
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  rules:
  - host: ezyshop.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ezyshop-frontend
            port:
              number: 80
EOF
```

#### Проверка приложения

```bash
kubectl -n ezyshop get pods
kubectl -n ezyshop get svc
kubectl -n ezyshop get ingress

# Тест доступа внутри сети
curl http://ezyshop.local.lab

# Тест через ngrok (замените YOUR_URL на ваш ngrok URL)
NGROK_URL=$(ssh admin@ngrok-tunnel.local.lab 'curl -s http://localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url"')
curl $NGROK_URL
```

---

## ✅ Проверка инфраструктуры

Создайте скрипт для проверки всей инфраструктуры:

```bash
cat > /tmp/check-infrastructure.sh <<'EOF'
#!/bin/bash
echo "=== Проверка Production Infrastructure ==="
echo ""

# 1. Проверка DNS
echo "1. Testing DNS..."
dig @192.168.100.53 k3s-master.local.lab +short >/dev/null && echo "✅ DNS working" || echo "❌ DNS failed"

# 2. Проверка K3s кластера
echo "2. Testing K3s cluster..."
kubectl get nodes >/dev/null && echo "✅ K3s cluster accessible" || echo "❌ K3s cluster failed"

# 3. Проверка MetalLB
echo "3. Testing MetalLB..."
LB_IP=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ ! -z "$LB_IP" ]; then
    echo "✅ MetalLB assigned IP: $LB_IP"
else
    echo "❌ MetalLB failed"
fi

# 4. Проверка ngrok
echo "4. Testing ngrok tunnel..."
NGROK_URL=$(ssh admin@ngrok-tunnel.local.lab 'curl -s http://localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url" 2>/dev/null')
if [ ! -z "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    echo "✅ ngrok tunnel UP: $NGROK_URL"
else
    echo "❌ ngrok tunnel failed"
fi

# 5. Проверка сервисов
echo "5. Testing services..."
SERVICES="prometheus.local.lab grafana.local.lab alertmanager.local.lab kibana.local.lab argocd.local.lab ezyshop.local.lab"
for service in $SERVICES; do
    if curl -s -o /dev/null -w "%{http_code}" http://$service | grep -q "200\|301\|302"; then
        echo "✅ $service accessible"
    else
        echo "❌ $service failed"
    fi
done

# 6. Проверка storage
echo "6. Testing storage..."
kubectl get storageclass longhorn >/dev/null && echo "✅ Longhorn storage available" || echo "❌ Longhorn failed"

# 7. Итоговая статистика
echo ""
echo "=== Summary ==="
echo "Cluster nodes: $(kubectl get nodes --no-headers 2>/dev/null | wc -l)"
echo "Total pods: $(kubectl get pods -A --no-headers 2>/dev/null | wc -l)"
echo "Running pods: $(kubectl get pods -A --no-headers 2>/dev/null | grep Running | wc -l)"
if [ ! -z "$NGROK_URL" ]; then
    echo "Public URL: $NGROK_URL"
fi
echo ""
echo "Infrastructure check completed!"
EOF

chmod +x /tmp/check-infrastructure.sh
/tmp/check-infrastructure.sh
```

---

## 🔧 Устранение неполадок

### Общие проблемы

**Поды не запускаются:**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**Проблемы с DNS:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

**Ingress не работает:**
```bash
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
kubectl describe ingress <ingress-name> -n <namespace>
```

**ngrok туннель не работает:**
```bash
ssh admin@ngrok-tunnel.local.lab
sudo journalctl -u ngrok -n 50
curl http://localhost:4040/api/tunnels
```

### Полезные команды

```bash
# Просмотр всех ресурсов
kubectl get all -A

# Проверка состояния узлов
kubectl top nodes

# Проверка состояния подов
kubectl top pods -A

# Просмотр логов Traefik
kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=50

# Проверка сертификатов
kubectl get certificates -A
```

---

## 🎯 Заключение

Вы успешно развернули полную production-ready DevOps инфраструктуру включающую:

- ✅ **Kubernetes кластер** (K3s) с высокой доступностью
- ✅ **Постоянное хранилище** (Longhorn) для stateful приложений
- ✅ **LoadBalancer** (MetalLB) для внешнего доступа к сервисам
- ✅ **Ingress контроллер** (Traefik) для маршрутизации трафика
- ✅ **Внешний доступ** (ngrok) с автоматическим TLS
- ✅ **CI/CD** (Jenkins) для автоматизации сборки и развертывания
- ✅ **Мониторинг** (Prometheus + Grafana) для наблюдения за инфраструктурой
- ✅ **Логирование** (ELK Stack) для централизованного сбора логов
- ✅ **GitOps** (ArgoCD) для декларативного управления развертываниями
- ✅ **E-commerce приложение** готовое к работе

### Доступ к сервисам

- **Приложение**: `https://YOUR-NGROK-URL.ngrok.io`
- **ArgoCD**: `http://argocd.local.lab` (admin / <password>)
- **Grafana**: `http://grafana.local.lab` (admin / admin123)
- **Prometheus**: `http://prometheus.local.lab`
- **Kibana**: `http://kibana.local.lab`
- **Jenkins**: `http://jenkins.local.lab:8080`
- **Longhorn**: `http://longhorn.local.lab`

### Следующие шаги

1. Настройте домен вместо ngrok (опционально)
2. Настройте SSL сертификаты для внутренних сервисов
3. Настройте backup стратегию для кластера и данных
4. Настройте оповещения в Slack/Telegram
5. Настройте мониторинг бизнес-метрик

**Поздравляем! Ваша production-ready инфраструктура готова к работе! 🚀**
