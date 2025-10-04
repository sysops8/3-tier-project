# 🚀 Production-Ready инфраструктура E-Commerce на Proxmox

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)](https://argo-cd.readthedocs.io/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus)](https://prometheus.io/)

> Полная DevOps инфраструктура с K3s, CI/CD, мониторингом и логированием для e-commerce приложений

---

## 📑 Содержание

- [Обзор](#-обзор)
- [Архитектура](#-архитектура)
- [Технологический стек](#-технологический-стек)
- [Спецификации инфраструктуры](#-спецификации-инфраструктуры)
- [Предварительные требования](#-предварительные-требования)
- [Руководство по установке](#-руководство-по-установке)
  - [Сетевая инфраструктура](#1-сетевая-инфраструктура)
  - [DNS сервер (BIND9)](#2-dns-сервер-bind9)
  - [NAT шлюз](#3-nat-шлюз)
  - [Объектное хранилище (MinIO)](#4-объектное-хранилище-minio)
  - [Kubernetes кластер (K3s)](#5-kubernetes-кластер-k3s)
  - [Постоянное хранилище (Longhorn)](#6-постоянное-хранилище-longhorn)
  - [LoadBalancer (MetalLB)](#7-loadbalancer-metallb)
  - [Ingress контроллер (Traefik)](#8-ingress-контроллер-traefik)
  - [Внешний доступ (Cloudflare Tunnel)](#9-внешний-доступ-cloudflare-tunnel)
  - [CI/CD (Jenkins)](#10-cicd-jenkins)
  - [Мониторинг (Prometheus Stack)](#11-мониторинг-prometheus-stack)
  - [Логирование (ELK Stack)](#12-логирование-elk-stack)
  - [GitOps (ArgoCD)](#13-gitops-argocd)
  - [Развертывание приложения](#14-развертывание-приложения)
- [CI/CD пайплайн](#-cicd-пайплайн)
- [Мониторинг и оповещения](#-мониторинг-и-оповещения)
- [Устранение неполадок](#-устранение-неполадок)
- [Резервное копирование и восстановление](#-резервное-копирование-и-восстановление)
- [Оптимизация производительности](#-оптимизация-производительности)
- [Безопасность](#-безопасность)

---

## 🎯 Обзор

Этот проект демонстрирует полную production-ready DevOps инфраструктуру, развернутую на платформе виртуализации Proxmox. Включает автоматизированные CI/CD пайплайны, комплексный мониторинг, централизованное логирование и высокую доступность для e-commerce приложений.

### Ключевые возможности

- ✅ **Полностью автоматизированный CI/CD** - Jenkins + ArgoCD GitOps
- ✅ **Высокая доступность** - Многоузловой K3s кластер с автомасштабированием
- ✅ **Комплексный мониторинг** - Prometheus + Grafana + AlertManager
- ✅ **Централизованное логирование** - ELK Stack (Elasticsearch, Logstash, Kibana)
- ✅ **Постоянное хранилище** - Распределенное хранилище Longhorn
- ✅ **LoadBalancer** - MetalLB для bare-metal Kubernetes
- ✅ **Внешний доступ** - Cloudflare Tunnel для безопасного внешнего подключения
- ✅ **Инфраструктура как код** - Terraform для provisioning VM
- ✅ **GitOps развертывание** - ArgoCD для декларативного развертывания

---

## 🎯 Архитектура

```
Интернет (серый IP)
    ↓
Cloudflare Tunnel (cf-tunnel VM)
    ↓ [NAT шлюз]
    ↓
MetalLB LoadBalancer (192.168.100.100)
    ↓
Traefik Ingress контроллер
    ↓
┌────────────────────────────────────────────┐
│   K3s кластер (192.168.100.0/24)           │
│  ┌──────────┬──────────┬──────────┐        │
│  │ Master   │ Worker-1 │ Worker-2 │        │
│  │ 4C/8GB   │ 4C/10GB  │ 4C/10GB  │        │
│  └──────────┴──────────┴──────────┘        │
│                                             │
│  Приложения:                                │
│  - EzyShop (E-commerce)                    │
│  - ArgoCD (GitOps развертывание)           │
│  - Prometheus/Grafana (Метрики)            │
│  - Elasticsearch/Kibana (Логи)             │
│  - AlertManager → Slack                    │
└────────────────────────────────────────────┘
    ↓                    ↓
Jenkins CI          MinIO S3
(192.168.100.101)   (192.168.100.20)

Инфраструктурные сервисы:
- BIND9 DNS (192.168.100.53)
- NAT шлюз (192.168.100.50)
- MetalLB LoadBalancer (192.168.100.100)
- Jumphost (192.168.100.5)
```

### Сетевая топология

```
10.0.10.0/24 (vmbr0) - Внешняя сеть
├── 10.0.10.1        - ISP шлюз
├── 10.0.10.50       - cf-tunnel (eth0)
├── 10.0.10.53       - dns-server (eth0)
├── 10.0.10.102      - jumphost (eth0)
└── 10.0.10.200      - Proxmox хост

192.168.100.0/24 (vmbr1) - Внутренняя сеть
├── 192.168.100.1      - Proxmox vmbr1
├── 192.168.100.5      - jumphost (eth1)
├── 192.168.100.10     - k3s-master
├── 192.168.100.11     - k3s-worker-1
├── 192.168.100.12     - k3s-worker-2
├── 192.168.100.20     - minio
├── 192.168.100.50     - cf-tunnel (eth1) [NAT шлюз]
├── 192.168.100.53     - dns-server (eth1)
├── 192.168.100.100    - MetalLB LoadBalancer (виртуальный IP)
├── 192.168.100.101    - jenkins
└── 192.168.100.100-110 - MetalLB пул IP
```

---

## 🛠️ Технологический стек

### Инфраструктура
- **Виртуализация**: Proxmox VE 8.x
- **IaC**: Terraform
- **ОС**: Ubuntu Server 22.04 LTS

### Оркестрация
- **Оркестрация контейнеров**: K3s (облегченный Kubernetes)
- **Менеджер пакетов**: Helm 3
- **GitOps**: ArgoCD

### CI/CD
- **CI сервер**: Jenkins
- **Git**: GitHub/GitLab
- **Container Registry**: Docker Hub / MinIO

### Хранилище
- **Постоянное хранилище**: Longhorn
- **Объектное хранилище**: MinIO (S3-совместимое)
- **База данных**: PostgreSQL 15

### Сеть
- **DNS**: BIND9
- **Ingress**: Traefik 2.x
- **LoadBalancer**: MetalLB (режим L2)
- **Внешний доступ**: Cloudflare Tunnel
- **Балансировка нагрузки**: MetalLB L2 Advertisement

### Мониторинг и логирование
- **Метрики**: Prometheus + Grafana
- **Оповещения**: AlertManager + Slack
- **Логирование**: Elasticsearch + Kibana
- **Сбор логов**: Filebeat

### Безопасность
- **Управление секретами**: Kubernetes Secrets
- **TLS/SSL**: Let's Encrypt (через Cloudflare)
- **Сетевая изоляция**: Частный VLAN

---

## 📊 Спецификации инфраструктуры

### Виртуальные машины

| Hostname | vCPU | RAM | Диск | Сеть | IP | Роль |
|----------|------|-----|------|---------|-----|------|
| dns-server | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.53<br>192.168.100.53 | DNS сервер (BIND9) |
| cf-tunnel | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.50<br>192.168.100.50 | NAT шлюз + туннель |
| k3s-master | 4 | 8GB | 60GB (SSD) | vmbr1 | 192.168.100.10 | K3s Control Plane |
| k3s-worker-1 | 4 | 10GB | 80GB (SSD) | vmbr1 | 192.168.100.11 | K3s рабочий узел |
| k3s-worker-2 | 4 | 10GB | 80GB (SSD) | vmbr1 | 192.168.100.12 | K3s рабочий узел |
| jenkins | 2 | 4GB | 40GB | vmbr1 | 192.168.100.101 | CI сервер |
| minio | 2 | 4GB | 20GB+100GB (HDD) | vmbr1 | 192.168.100.20 | Объектное хранилище |
| jumphost | 1 | 2GB | 20GB | vmbr0+vmbr1 | 10.0.10.102<br>192.168.100.5 | Хост управления |

**Всего ресурсов**: 19 vCPU, 40GB RAM, 420GB диск

### Карта сервисов

| Сервис | Внутренний домен | Внешний домен | Порт |
|---------|----------------|-----------------|------|
| EzyShop | ezyshop.local.lab | ezyshop.yourdomain.com | 80/443 |
| ArgoCD | argocd.local.lab | argocd.yourdomain.com | 80/443 |
| Grafana | grafana.local.lab | grafana.yourdomain.com | 80/443 |
| Prometheus | prometheus.local.lab | prometheus.yourdomain.com | 80/443 |
| AlertManager | alertmanager.local.lab | alertmanager.yourdomain.com | 80/443 |
| Kibana | kibana.local.lab | kibana.yourdomain.com | 80/443 |
| Jenkins | jenkins.local.lab | jenkins.yourdomain.com | 8080 |
| MinIO консоль | minio.local.lab | - | 9001 |
| Longhorn UI | longhorn.local.lab | - | 80 |

---

## ✅ Предварительные требования

- Установленный и настроенный Proxmox VE 8.x
- Загруженный ISO Ubuntu 22.04 в Proxmox
- Аккаунт Cloudflare (для внешнего доступа)
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

# Остановить systemd-resolved (конфликтует с BIND)
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
cf-tunnel       IN      A       192.168.100.50
jumphost        IN      A       192.168.100.5

; Kubernetes кластер
k3s-master      IN      A       192.168.100.10
k3s-worker-1    IN      A       192.168.100.11
k3s-worker-2    IN      A       192.168.100.12

# Дополнительные сервисы
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

#### Тестирование DNS

```bash
# Прямые запросы
dig @192.168.100.53 k3s-master.local.lab +short
dig @192.168.100.53 ezyshop.local.lab +short

# Обратные запросы
dig @192.168.100.53 -x 192.168.100.10 +short

# Тест рекурсии
dig @192.168.100.53 google.com +short
```

---

### 3. NAT шлюз

#### Настройка NAT на cf-tunnel

SSH к cf-tunnel:

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
sudo bash -c 'cat > /etc/systemd/system/minio.service <<EOF
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
EOF'
```

Запуск MinIO:

```bash
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
sudo systemctl status minio
curl http://minio.local.lab:9000/minio/health/live  # Должен вернуть 200 OK
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

cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

# Настроить sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k3s.conf
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
# Сохраните этот токен!
```

#### Установка K3s Workers

**Worker 1:**

```bash
ssh admin@k3s-worker-1.local.lab

# Замените <TOKEN> токеном от master
curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master.local.lab:6443 \
  K3S_TOKEN="<TOKEN_FROM_MASTER>" \
  INSTALL_K3S_EXEC="agent" sh -s - \
  --node-name k3s-worker-1 \
  --node-ip 192.168.100.11

sudo systemctl status k3s-agent
```

**Worker 2:**

```bash
ssh admin@k3s-worker-2.local.lab

curl -sfL https://get.k3s.io | K3S_URL=https://k3s-master.local.lab:6443 \
  K3S_TOKEN="<TOKEN_FROM_MASTER>" \
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
kubectl -n longhorn-system get pods -w
```

---

### 7. LoadBalancer (MetalLB)

MetalLB предоставляет тип сервиса LoadBalancer для bare-metal Kubernetes кластеров, устраняя необходимость в NodePort сервисах.

#### Почему MetalLB?

**Без MetalLB (NodePort):**
- Нестандартные порты (30080, 30443)
- Сервис привязан к конкретному узлу
- Сложная конфигурация для внешнего доступа

**С MetalLB (LoadBalancer):**
- ✅ Стандартные порты (80, 443)
- ✅ Плавающие виртуальные IP
- ✅ Production-ready подход
- ✅ Простое предоставление внешних сервисов

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
kubectl -n metallb-system get pods -w
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

# Просмотр логов
kubectl -n metallb-system logs -l app=metallb -l component=controller
kubectl -n metallb-system logs -l app=metallb -l component=speaker
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
kubectl -n traefik get pods -w
```

#### Проверка Traefik LoadBalancer

```bash
kubectl -n traefik get pods
kubectl -n traefik get svc

# Должен показать EXTERNAL-IP: 192.168.100.100
# NAME      TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)
# traefik   LoadBalancer   10.43.x.x       192.168.100.100   80:xxx/TCP,443:xxx/TCP

kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=50
```

#### Обновление DNS записей

Все сервисы теперь указывают на IP MetalLB LoadBalancer:

```bash
ssh admin@dns-server.local.lab

# Редактировать файл зоны
sudo nano /etc/bind/zones/db.local.lab

# Обновить все записи сервисов на IP LoadBalancer:
# Изменить с: 192.168.100.10 (k3s-master)
# На: 192.168.100.100 (MetalLB LoadBalancer)

# Увеличить Serial (очень важно!)
# Изменить: Serial: 2
# На: Serial: 3

# Проверка синтаксиса
sudo named-checkzone local.lab /etc/bind/zones/db.local.lab

# Перезагрузить зону
sudo rndc reload local.lab

exit

# Тест разрешения DNS
dig @192.168.100.53 ezyshop.local.lab +short
# Должен вернуть: 192.168.100.100
```

#### Тест Ingress с LoadBalancer

Создать тестовое приложение:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  namespace: test
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test
  namespace: test
spec:
  rules:
  - host: test.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test
            port:
              number: 80
EOF

# Добавление DNS записи
ssh admin@dns-server.local.lab
sudo bash -c 'echo "test           IN      A       192.168.100.10" >> /etc/bind/zones/db.local.lab'
sudo sed -i 's/Serial.*$/Serial: 3/' /etc/bind/zones/db.local.lab
sudo rndc reload local.lab
exit

# Тест доступа (порт не нужен!)
curl http://test.local.lab
# Ожидается: Welcome to nginx!

# Очистка
kubectl delete namespace test
```

---

### 9. Внешний доступ (Cloudflare Tunnel)

#### Установка cloudflared

SSH к cf-tunnel:

```bash
ssh admin@cf-tunnel.local.lab
```

Установка:

```bash
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt update
sudo apt install -y cloudflared
cloudflared --version
```

#### Аутентификация

```bash
cloudflared tunnel login
# Откроется браузер - выберите ваш домен
```

#### Создание туннеля

```bash
cloudflared tunnel create homelab-tunnel

# Сохранить Tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep homelab-tunnel | awk '{print $1}')
echo "Tunnel ID: $TUNNEL_ID"
```

#### Настройка туннеля

Обновить конфигурацию туннеля для использования LoadBalancer IP:

```bash
sudo mkdir -p /etc/cloudflared

sudo bash -c "cat > /etc/cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

ingress:
  # Все сервисы теперь используют IP LoadBalancer без портов!
  - hostname: ezyshop.yourdomain.com
    service: http://192.168.100.100
    originRequest:
      noTLSVerify: true
  
  - hostname: argocd.yourdomain.com
    service: http://192.168.100.100
    originRequest:
      noTLSVerify: true
  
  - hostname: grafana.yourdomain.com
    service: http://192.168.100.100
    originRequest:
      noTLSVerify: true
  
  - hostname: prometheus.yourdomain.com
    service: http://192.168.100.100
    originRequest:
      noTLSVerify: true
  
  - hostname: kibana.yourdomain.com
    service: http://192.168.100.100
    originRequest:
      noTLSVerify: true
  
  - hostname: jenkins.yourdomain.com
    service: http://jenkins.local.lab:8080
  
  # Правило по умолчанию (должно быть последним)
  - service: http_status:404
EOF"

sudo cp ~/.cloudflared/${TUNNEL_ID}.json /etc/cloudflared/
```

#### Маршрутизация DNS в Cloudflare

```bash
# Создать DNS записи через CLI (замените yourdomain.com)
cloudflared tunnel route dns homelab-tunnel ezyshop.yourdomain.com
cloudflared tunnel route dns homelab-tunnel argocd.yourdomain.com
cloudflared tunnel route dns homelab-tunnel grafana.yourdomain.com
cloudflared tunnel route dns homelab-tunnel prometheus.yourdomain.com
cloudflared tunnel route dns homelab-tunnel kibana.yourdomain.com
cloudflared tunnel route dns homelab-tunnel jenkins.yourdomain.com
```

#### Запуск как сервиса

```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
sudo systemctl status cloudflared

# Просмотр логов
sudo journalctl -u cloudflared -f
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

1. Введите начальный пароль
2. Установите предложенные плагины
3. Создайте пользователя admin
4. Подтвердите URL: `http://jenkins.local.lab:8080`

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
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack'
    receivers:
    - name: 'slack'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: 'Оповещение кластера'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

nodeExporter:
  enabled: true

kubeStateMetrics:
  enabled: true
EOF

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/prometheus-values.yaml

kubectl -n monitoring get pods -w
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
replicas: 2
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

kubectl -n logging get pods -w
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

**Доступ**: `http://kibana.local.lab`

---

### 13. GitOps (ArgoCD)

#### Установка ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd get pods -w
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

#### Развертывание с ArgoCD

```bash
argocd app create ezyshop \
  --repo https://github.com/yourusername/ezyshop-k8s-manifests.git \
  --path overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ezyshop \
  --sync-policy automated \
  --auto-prune \
  --self-heal

argocd app sync ezyshop
argocd app get ezyshop
```

---

## 🔄 CI/CD пайплайн

### Архитектура с MetalLB

```
Push разработчика
    ↓
GitHub/GitLab
    ↓
Jenkins (Webhook)
    ↓
Сборка и тестирование
    ↓
Docker сборка и push
    ↓
Обновление манифестов
    ↓
ArgoCD (GitOps)
    ↓
Развертывание в K3s
    ↓
MetalLB назначает IP LoadBalancer
    ↓
Traefik маршрутизирует трафик
    ↓
Приложение доступно на http://app.local.lab
```

---

## 📊 Мониторинг и оповещения

### Запросы Prometheus

```promql
# Использование CPU
rate(container_cpu_usage_seconds_total[5m])

# Использование памяти
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Частота HTTP запросов
rate(http_requests_total[5m])

# Количество перезапусков подов
kube_pod_container_status_restarts_total
```

---

## 🔧 Устранение неполадок

### Распространенные проблемы

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

**Проблемы с MetalLB:**
```bash
# Проверка подов MetalLB
kubectl -n metallb-system get pods
kubectl -n metallb-system logs -l component=controller
kubectl -n metallb-system logs -l component=speaker

# Проверка назначения IP адреса
kubectl get svc -A | grep LoadBalancer

# Проверка L2 advertisement
kubectl -n metallb-system get l2advertisement
kubectl -n metallb-system describe l2advertisement l2-advert
```

**Ingress не работает:**
```bash
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
kubectl describe ingress <ingress-name> -n <namespace>
```

---

## 💾 Резервное копирование и восстановление

### Резервное копирование K3s etcd

```bash
ssh admin@k3s-master.local.lab
sudo k3s etcd-snapshot save
sudo k3s etcd-snapshot ls
```

### Резервное копирование PostgreSQL

```bash
kubectl -n ezyshop exec -it <postgres-pod> -- pg_dump -U ezyshop ezyshop > backup.sql
```

### Восстановление из резервной копии

```bash
sudo k3s etcd-snapshot restore <snapshot-name>
kubectl -n ezyshop cp backup.sql <postgres-pod>:/tmp/
kubectl -n ezyshop exec -it <postgres-pod> -- psql -U ezyshop ezyshop < /tmp/backup.sql
```

---

## ⚡ Оптимизация производительности

### Оптимизация Kubernetes

```bash
# Увеличить лимиты etcd
sudo nano /etc/systemd/system/k3s.service
# Добавить: --etcd-arg="--quota-backend-bytes=8589934592"
```

---

## 🔒 Безопасность

### Лучшие практики

- ✅ Секреты хранятся в Kubernetes Secrets (не в Git)
- ✅ RBAC включен и настроен
- ✅ Сетевая изоляция с частным VLAN
- ✅ TLS/SSL через Cloudflare
- ✅ Регулярные обновления безопасности
- ✅ Сканирование образов (рекомендуется Trivy)

---

## 📚 Дополнительная информация

### Операции MetalLB

#### Проверка статуса LoadBalancer

```bash
# Список всех LoadBalancer сервисов
kubectl get svc -A -o wide | grep LoadBalancer

# Проверка назначений IP
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Логи MetalLB speaker (один на узел)
kubectl -n metallb-system logs -l component=speaker --tail=50

# Логи контроллера
kubectl -n metallb-system logs -l component=controller --tail=50
```

#### Предоставление дополнительных сервисов через LoadBalancer

**Пример: Предоставление PostgreSQL внешне**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-external
  namespace: ezyshop
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.100.105
spec:
  type: LoadBalancer
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
EOF

# Подключение с любой машины в сети
psql -h 192.168.100.105 -U ezyshop -d ezyshop
```

---

