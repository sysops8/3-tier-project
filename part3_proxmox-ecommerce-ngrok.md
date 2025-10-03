# 🚀 Production-Ready инфраструктура E-Commerce на Proxmox v2.1

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)](https://argo-cd.readthedocs.io/)
[![Security](https://img.shields.io/badge/Security-Vault-000000?logo=vault)](https://www.vaultproject.io/)
[![Backup](https://img.shields.io/badge/Backup-Velero-00ADD8?logo=vmware)](https://velero.io/)

> **НОВОЕ в v2.1:** Замена Cloudflare на ngrok + Упрощенная настройка внешнего доступа

---

## 📑 Содержание

- [Что нового в v2.1](#-что-нового-в-v21)
- [Обзор](#-обзор)
- [Архитектура](#-архитектура)
- [Технологический стек](#-технологический-стек)
- [Спецификации инфраструктуры](#-спецификации-инфраструктуры)
- [Предварительные требования](#-предварительные-требования)
- [Руководство по установке](#-руководство-по-установке)

---

## 🆕 Что нового в v2.1

### ✨ Основные изменения

| Категория | Улучшение | Описание |
|-----------|-----------|----------|
| 🌐 **External Access** | ngrok заместо Cloudflare | Более простая настройка без DNS |
| 🌐 **External Access** | Автоматический TLS | Встроенные SSL сертификаты от ngrok |
| 🌐 **External Access** | Единый туннель | Один ngrok tunnel для всех сервисов |
| 🔧 **Setup** | Упрощенная конфигурация | Меньше шагов настройки |

---

## 🎯 Обзор

Полная production-ready DevOps инфраструктура с **enterprise-grade security**, **automated disaster recovery** и **zero-downtime deployments**.

### Ключевые возможности v2.1

#### Базовые (из v2.0)
- ✅ Полностью автоматизированный CI/CD - Jenkins + ArgoCD GitOps
- ✅ Высокая доступность - Многоузловой K3s кластер
- ✅ Комплексный мониторинг - Prometheus + Grafana + AlertManager
- ✅ Централизованное логирование - ELK Stack
- ✅ Постоянное хранилище - Longhorn
- ✅ LoadBalancer - MetalLB для bare-metal
- 🆕 **Внешний доступ - ngrok Tunnel (вместо Cloudflare)**

#### Новые (v2.0)
- 🆕 **Zero-Trust Security** - Vault + Network Policies + Image Scanning
- 🆕 **Automated Backups** - Velero (кластер) + CronJob (БД) каждые 3-24ч
- 🆕 **Disaster Recovery** - RTO < 30 минут, RPO < 3 часа
- 🆕 **Progressive Delivery** - Canary deployments с автоматическими метриками
- 🆕 **Self-Healing** - Автоматический rollback при деградации метрик
- 🆕 **Horizontal Autoscaling** - HPA на основе CPU/Memory/Custom метрик

---

## 🎯 Архитектура v2.1

```
Интернет (серый IP)
    ↓
🆕 ngrok Cloud (автоматический TLS)
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
│  🆕 Security Layer:                              │
│  - Vault (секреты)                               │
│  - Network Policies (изоляция)                   │
│  - Trivy (сканирование образов)                  │
│                                                  │
│  🆕 Backup Layer:                                │
│  - Velero (backup кластера → MinIO)              │
│  - PostgreSQL CronJob (backup БД → PVC)          │
│                                                  │
│  🆕 Deployment Layer:                            │
│  - Argo Rollouts (Canary deployments)            │
│  - Analysis Templates (автопроверка метрик)      │
│  - HPA (автомасштабирование)                     │
│                                                  │
│  Приложения:                                     │
│  - EzyShop (E-commerce) - Canary ready           │
│  - ArgoCD (GitOps развертывание)                 │
│  - Prometheus/Grafana (Метрики)                  │
│  - Elasticsearch/Kibana (Логи)                   │
│  - AlertManager → Slack                          │
└──────────────────────────────────────────────────┘
    ↓                    ↓
Jenkins CI          MinIO S3
(192.168.100.101)   (192.168.100.20)
    ↓                    ↓
Trivy Scanner       Velero Backups
                    PostgreSQL Backups

Инфраструктурные сервисы:
- BIND9 DNS (192.168.100.53)
- NAT шлюз (192.168.100.50)
- MetalLB LoadBalancer (192.168.100.100)
- 🆕 ngrok Tunnel (192.168.100.60)
- Jumphost (192.168.100.5)
```

---

## 🛠️ Технологический стек v2.1

### 🆕 Новые компоненты

#### External Access
- **Туннель**: ngrok (заместо Cloudflare)
- **TLS**: Автоматические сертификаты от ngrok
- **DNS**: Динамический поддомен ngrok.io
- **Преимущества**: Не требуется домен, проще настройка

#### Security
- **Управление секретами**: HashiCorp Vault
- **Сканирование образов**: Trivy
- **Сетевая безопасность**: Kubernetes Network Policies
- **Pod Security**: PodDisruptionBudget + SecurityContext

#### Backup & DR
- **Кластер backup**: Velero 1.12+
- **БД backup**: PostgreSQL CronJob
- **Хранилище backup**: MinIO S3
- **Retention**: 7 дней для БД, 30 дней для кластера

#### Deployment
- **Progressive Delivery**: Argo Rollouts
- **Canary Analysis**: Prometheus-based metrics
- **Autoscaling**: Horizontal Pod Autoscaler (HPA)
- **Traffic Management**: TrafficRouting via Traefik

---

## 📊 Спецификации инфраструктуры

### Виртуальные машины (обновлено)

| Hostname | vCPU | RAM | Диск | Сеть | IP | Роль |
|----------|------|-----|------|---------|-----|------|
| dns-server | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.53<br>192.168.100.53 | DNS сервер (BIND9) |
| 🆕 ngrok-tunnel | 1 | 1GB | 10GB | vmbr0+vmbr1 | 10.0.10.60<br>192.168.100.60 | ngrok туннель |
| k3s-master | 4 | 8GB | 60GB (SSD) | vmbr1 | 192.168.100.10 | K3s Control Plane |
| k3s-worker-1 | 4 | 10GB | 80GB (SSD) | vmbr1 | 192.168.100.11 | K3s рабочий узел |
| k3s-worker-2 | 4 | 10GB | 80GB (SSD) | vmbr1 | 192.168.100.12 | K3s рабочий узел |
| jenkins | 2 | 4GB | 40GB | vmbr1 | 192.168.100.101 | CI сервер |
| minio | 2 | 4GB | 20GB+100GB (HDD) | vmbr1 | 192.168.100.20 | Объектное хранилище |
| jumphost | 1 | 2GB | 20GB | vmbr0+vmbr1 | 10.0.10.102<br>192.168.100.5 | Хост управления |

**Всего ресурсов**: 19 vCPU, 40GB RAM, 420GB диск

### 🆕 Карта сервисов v2.1

| Сервис | Внутренний домен | 🆕 Внешний доступ (ngrok) | Порт |
|---------|----------------|-----------------|------|
| EzyShop | ezyshop.local.lab | https://YOUR-DOMAIN.ngrok.io | 80/443 |
| ArgoCD | argocd.local.lab | https://YOUR-DOMAIN.ngrok.io/argocd | 80/443 |
| Grafana | grafana.local.lab | https://YOUR-DOMAIN.ngrok.io/grafana | 80/443 |
| Prometheus | prometheus.local.lab | https://YOUR-DOMAIN.ngrok.io/prometheus | 80/443 |
| Kibana | kibana.local.lab | https://YOUR-DOMAIN.ngrok.io/kibana | 80/443 |
| Jenkins | jenkins.local.lab | - (только внутри) | 8080 |
| MinIO консоль | minio.local.lab | - (только внутри) | 9001 |
| Longhorn UI | longhorn.local.lab | - (только внутри) | 80 |
| Vault UI | vault.local.lab | - (только внутри) | 8200 |
| Argo Rollouts | rollouts.local.lab | - (только внутри) | 3100 |

---

## ✅ Предварительные требования

### Обязательные
- Установленный и настроенный Proxmox VE 8.x
- Загруженный ISO Ubuntu 22.04 в Proxmox
- 🆕 **Аккаунт ngrok** (бесплатный: https://ngrok.com)
- Аккаунт GitHub/GitLab
- Базовые знания Linux, Kubernetes и CI/CD

### 🆕 Новые требования v2.1
- ngrok authtoken (получите на https://dashboard.ngrok.com)
- Дополнительно 20GB дискового пространства для backup
- MinIO credentials для Velero (создадим в процессе)
- Slack Webhook URL для критичных алертов (опционально)

---

## 📖 Руководство по установке

### Базовая инфраструктура

**ШАГ 1-7: Следуйте оригинальной инструкции**

> 💡 **Важно**: Сначала установите базовую инфраструктуру из оригинальной инструкции (шаги 1-7):
> - Сетевая инфраструктура
> - DNS сервер (BIND9)
> - MinIO
> - K3s кластер
> - Longhorn
> - MetalLB
> - Traefik

---

### 🆕 ШАГ 8: Настройка ngrok туннеля (вместо Cloudflare)

#### A. Создание VM для ngrok

В Proxmox:

```bash
# Создать VM
qm create 106 \
  --name ngrok-tunnel \
  --memory 1024 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1 \
  --ide2 local:iso/ubuntu-22.04-server-amd64.iso,media=cdrom \
  --scsi0 local-lvm:10

# Запустить установку
qm start 106
```

**Настройка сети во время установки Ubuntu:**
- ens18 (vmbr0): 10.0.10.60/24, gateway 10.0.10.1
- ens19 (vmbr1): 192.168.100.60/24, no gateway

#### B. Установка ngrok

SSH к ngrok-tunnel:

```bash
ssh admin@10.0.10.60

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

#### C. Настройка ngrok

```bash
# Авторизация (замените YOUR_AUTHTOKEN на ваш токен из https://dashboard.ngrok.com)
ngrok config add-authtoken YOUR_AUTHTOKEN

# Создать конфигурацию для множественных сервисов
cat > ~/.config/ngrok/ngrok.yml <<EOF
version: "2"
authtoken: YOUR_AUTHTOKEN

tunnels:
  ezyshop-web:
    proto: http
    addr: 192.168.100.100:80    
    inspect: false
    host_header: rewrite

  ezyshop-services:
    proto: http
    addr: 192.168.100.100:80    
    inspect: false
    host_header: rewrite
    
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
ExecStart=/usr/local/bin/ngrok start --all --config ~/.config/ngrok/ngrok.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Создать пользователя
sudo useradd -r ngrok-user -s /sbin/nologin

# Создать директории
sudo touch /var/log/ngrok.log
sudo chown -R ngrok-user:ngrok-user /var/log/ngrok.log

# Запустить ngrok
sudo systemctl daemon-reload
sudo systemctl enable ngrok
sudo systemctl start ngrok

# Проверка статуса
sudo systemctl status ngrok

# Посмотреть активные туннели
curl http://localhost:4040/api/tunnels | jq
```

#### D. Получение ngrok URL

```bash
# Получить публичный URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "Ваш ngrok URL: $NGROK_URL"

# Сохранить в файл для использования
echo $NGROK_URL > /tmp/ngrok-url.txt
```

**Важно**: Сохраните этот URL! Например: `https://abc123.ngrok.io`

#### E. Настройка NAT для внутреннего доступа

На ngrok-tunnel VM:

```bash
# Включить IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Настроить iptables
sudo iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE
sudo iptables -A FORWARD -i ens19 -o ens18 -j ACCEPT
sudo iptables -A FORWARD -i ens18 -o ens19 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранить правила
sudo apt install iptables-persistent -y
sudo netfilter-persistent save
```

---

### 🆕 ШАГ 9: Обновление DNS для ngrok

#### A. Обновить BIND9 зоны

SSH к dns-server:

```bash
ssh admin@192.168.100.53

# Создать зону для внешнего доступа (опционально, для внутренних записей)
sudo tee -a /etc/bind/db.local.lab <<EOF

; ngrok tunnel endpoint
ngrok           IN      A       192.168.100.60
EOF

# Перезагрузить BIND9
sudo systemctl reload bind9

# Проверка
dig @192.168.100.53 ngrok.local.lab +short
```

#### B. Документация URL

Создайте файл с URL для команды:

```bash
# На jumphost
cat > ~/ngrok-endpoints.txt <<EOF
=== ngrok Public Endpoints ===

Main Application:
- EzyShop: ${NGROK_URL}

Admin Interfaces (через Traefik path-based routing):
- ArgoCD: ${NGROK_URL}/argocd
- Grafana: ${NGROK_URL}/grafana
- Prometheus: ${NGROK_URL}/prometheus
- Kibana: ${NGROK_URL}/kibana

Internal Access (через local.lab):
- Jenkins: http://jenkins.local.lab:8080
- MinIO: http://minio.local.lab:9001
- Vault: http://vault.local.lab:8200
- Longhorn: http://longhorn.local.lab

Note: ngrok URL динамический и меняется при перезапуске (бесплатный план)
Для статического URL используйте ngrok paid план.
EOF

cat ~/ngrok-endpoints.txt
```

---

### 🆕 ШАГ 10: Обновление Traefik для ngrok

Обновите Traefik Ingress для работы с ngrok path-based routing:

```bash
# На jumphost
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-config
  namespace: traefik
data:
  traefik.yml: |
    entryPoints:
      web:
        address: ":80"
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
      websecure:
        address: ":443"
        http:
          tls: {}
    
    providers:
      kubernetesIngress:
        ingressClass: traefik
    
    api:
      dashboard: true
      insecure: true
    
    log:
      level: INFO
    
    accessLog: {}
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: strip-prefix
  namespace: traefik
spec:
  stripPrefix:
    prefixes:
      - /argocd
      - /grafana
      - /prometheus
      - /kibana
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: dashboard
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: PathPrefix(`/traefik`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
      middlewares:
        - name: strip-prefix
EOF

# Перезапустить Traefik
kubectl -n traefik rollout restart deployment traefik
```

---

### ШАГ 11-17: Следуйте оригинальной инструкции

Продолжайте установку остальных компонентов:
- CI/CD (Jenkins) - Шаг 10
- Мониторинг (Prometheus Stack) - Шаг 11
- Логирование (ELK Stack) - Шаг 12
- GitOps (ArgoCD) - Шаг 13
- Security Layer (Vault + Trivy) - Шаг 14
- Backup & DR (Velero) - Шаг 15
- Canary Deployments (Argo Rollouts) - Шаг 16
- Развертывание приложения - Шаг 17

---

## 🆕 Обновленные Ingress для ngrok

### A. EzyShop Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ezyshop-ingress
  namespace: ezyshop
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ezyshop-frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: ezyshop-backend
            port:
              number: 8080
EOF
```

### B. ArgoCD Ingress (с путем /argocd)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-strip-prefix@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /argocd
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
```

### C. Grafana Ingress (с путем /grafana)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: traefik-strip-prefix@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /grafana
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
EOF

# Обновить Grafana config для работы с subpath
kubectl -n monitoring patch configmap prometheus-grafana -p '{"data":{"grafana.ini":"[server]\nroot_url = %(protocol)s://%(domain)s/grafana/\nserve_from_sub_path = true"}}'
kubectl -n monitoring rollout restart deployment prometheus-grafana
```

---

## 🔧 Преимущества ngrok над Cloudflare

### ✅ Плюсы ngrok

1. **Простота настройки**: Один агент, одна команда
2. **Не нужен домен**: Бесплатный поддомен ngrok.io
3. **Автоматический TLS**: Сертификаты из коробки
4. **Встроенный инспектор**: Web UI на localhost:4040
5. **Быстрый старт**: От установки до работы за 5 минут

### ⚠️ Ограничения ngrok (бесплатный план)

1. **Динамический URL**: Меняется при перезапуске (решение: paid план)
2. **Лимит соединений**: 40 connections/min (достаточно для dev/test)
3. **Один процесс**: Нужно запускать несколько туннелей
4. **Нет кастомного домена**: Только *.ngrok.io (решение: paid план $10/мес)

---

## 🆕 Мониторинг ngrok туннеля

### Проверка статуса туннеля

```bash
# Web UI (на ngrok-tunnel VM)
curl http://localhost:4040

# API запрос
curl -s http://localhost:4040/api/tunnels | jq '.tunnels[] | {name: .name, public_url: .public_url, status: .status}'

# Логи
sudo journalctl -u ngrok -f

# Тест доступности
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
curl -I $NGROK_URL
```

### Alert для падения туннеля

```bash
# На jumphost: создать скрипт проверки
cat > /usr/local/bin/check-ngrok.sh <<'EOF'
#!/bin/bash
NGROK_HOST="192.168.100.60"
NGROK_URL=$(ssh admin@$NGROK_HOST 'curl -s http://localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url"')

if [ -z "$NGROK_URL" ] || [ "$NGROK_URL" == "null" ]; then
    echo "❌ ngrok tunnel DOWN!"
    # Опционально: отправить alert в Slack
    exit 1
else
    echo "✅ ngrok tunnel UP: $NGROK_URL"
    exit 0
fi
EOF

chmod +x /usr/local/bin/check-ngrok.sh

# Добавить в cron (проверка каждые 5 минут)
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-ngrok.sh >> /var/log/ngrok-check.log 2>&1") | crontab -
```

---

## 🆕 Upgrade на платный план ngrok (опционально)

Если нужен статический URL и больше features:

```bash
# На ngrok-tunnel VM
# 1. Купить план на https://dashboard.ngrok.com/billing/subscription

# 2. Зарезервировать домен
ngrok http 80 --domain=your-static-name.ngrok.app

# 3. Обновить конфиг
cat > ~/.ngrok2/ngrok.yml <<EOF
version: "2"
authtoken: YOUR_AUTHTOKEN

tunnels:
  ezyshop:
    proto: http
    addr: 192.168.100.100:80
    domain: your-static-name.ngrok.app
    bind_tls: true
    inspect: false

region: us
EOF

# 4. Перезапустить
sudo systemctl restart ngrok
```

---

## 📚 Дополнительные ресурсы

### Документация ngrok
- Официальный сайт: https://ngrok.com
- Документация: https://ngrok.com/docs
- Dashboard: https://dashboard.ngrok.com
- Pricing: https://ngrok.com/pricing

### Альтернативы ngrok
- **Cloudflare Tunnel** (бесплатно, но нужен домен)
- **Tailscale** (VPN-подход)
- **LocalTunnel** (open-source)
- **Serveo** (SSH-based)

---

## 🔧 Устранение неполадок ngrok

### ngrok туннель не запускается

```bash
# Проверка логов
sudo journalctl -u ngrok -n 50

# Проверка конфига
ngrok config check

# Проверка authtoken
ngrok config check --log=stdout

# Переустановка
sudo apt remove ngrok
sudo apt install ngrok
ngrok config add-authtoken YOUR_AUTHTOKEN
```

### Приложение недоступно через ngrok

```bash
# 1. Проверить ngrok туннель
curl http://localhost:4040/api/tunnels

# 2. Проверить доступность MetalLB изнутри
curl -I http://192.168.100.100

# 3. Проверить Traefik
kubectl -n traefik get svc
kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=50

# 4. Проверить Ingress
kubectl get ingress -A

# 5. Тест напрямую
curl -H "Host: ezyshop.local.lab" http://192.168.100.100
```

### Медленная работа через ngrok

```bash
# Смена региона (для улучшения латентности)
# Доступные регионы: us, eu, ap, au, sa, jp, in
ngrok config edit
# Изменить: region: eu  (для Европы)

# Перезапустить с новым регионом
sudo systemctl restart ngrok
```

---

## CI/CD Pipeline с ngrok

### Обновленный Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "ezyshop/frontend"
        DOCKER_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = "ezyshop"
        TRIVY_SEVERITY = "HIGH,CRITICAL"
        NGROK_URL = credentials('ngrok-url')
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                    url: 'https://github.com/yourusername/ezyshop.git'
            }
        }
        
        stage('Build') {
            steps {
                script {
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        stage('Security Scan - Trivy') {
            steps {
                script {
                    sh """
                        echo "Scanning image for vulnerabilities..."
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --exit-code 0 \
                            --no-progress \
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                        
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --format json \
                            --output trivy-report.json \
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    sh """
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
            }
        }
        
        stage('Deploy with Argo Rollouts') {
            steps {
                script {
                    sh """
                        kubectl argo rollouts set image ezyshop-frontend \
                            frontend=${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE}
                        
                        kubectl argo rollouts status ezyshop-frontend \
                            -n ${K8S_NAMESPACE} \
                            --watch \
                            --timeout 10m
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                        echo "Testing deployment via ngrok..."
                        curl -f ${NGROK_URL}/health || exit 1
                        echo "Deployment successful!"
                    """
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
        }
        success {
            echo "Pipeline completed successfully!"
            echo "Application available at: ${NGROK_URL}"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
```

---

## Тестирование инфраструктуры

### Полный тест всех компонентов

```bash
#!/bin/bash
# test-infrastructure.sh

echo "=== Testing Production Infrastructure v2.1 ==="
echo ""

# 1. Тест ngrok туннеля
echo "1. Testing ngrok tunnel..."
NGROK_URL=$(ssh admin@192.168.100.60 'curl -s http://localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url"')
if [ ! -z "$NGROK_URL" ]; then
    echo "✅ ngrok tunnel UP: $NGROK_URL"
    
    # Тест доступности через интернет
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $NGROK_URL)
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "301" ] || [ "$HTTP_CODE" == "302" ]; then
        echo "✅ Application accessible via ngrok"
    else
        echo "❌ Application not accessible (HTTP $HTTP_CODE)"
    fi
else
    echo "❌ ngrok tunnel DOWN"
fi
echo ""

# 2. Тест K3s кластера
echo "2. Testing K3s cluster..."
if kubectl get nodes | grep -q "Ready"; then
    echo "✅ K3s cluster healthy"
    kubectl get nodes
else
    echo "❌ K3s cluster issues"
fi
echo ""

# 3. Тест MetalLB
echo "3. Testing MetalLB LoadBalancer..."
LB_IP=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ ! -z "$LB_IP" ]; then
    echo "✅ MetalLB assigned IP: $LB_IP"
    if curl -s -o /dev/null -w "%{http_code}" http://$LB_IP | grep -q "200\|301\|302"; then
        echo "✅ LoadBalancer responding"
    else
        echo "⚠️  LoadBalancer not responding"
    fi
else
    echo "❌ MetalLB not working"
fi
echo ""

# 4. Тест Storage (Longhorn)
echo "4. Testing Longhorn storage..."
if kubectl -n longhorn-system get pods | grep -q "Running"; then
    echo "✅ Longhorn running"
    kubectl get storageclass longhorn
else
    echo "❌ Longhorn issues"
fi
echo ""

# 5. Тест Vault
echo "5. Testing HashiCorp Vault..."
if kubectl -n vault-system get pods | grep -q "Running"; then
    VAULT_STATUS=$(kubectl -n vault-system exec vault-0 -- vault status -format=json | jq -r '.sealed')
    if [ "$VAULT_STATUS" == "false" ]; then
        echo "✅ Vault running and unsealed"
    else
        echo "⚠️  Vault sealed"
    fi
else
    echo "❌ Vault not running"
fi
echo ""

# 6. Тест Velero (Backups)
echo "6. Testing Velero backups..."
if kubectl -n velero get pods | grep -q "Running"; then
    echo "✅ Velero running"
    BACKUP_COUNT=$(velero backup get | grep -c "Completed")
    echo "   Completed backups: $BACKUP_COUNT"
else
    echo "❌ Velero not running"
fi
echo ""

# 7. Тест Argo Rollouts
echo "7. Testing Argo Rollouts..."
if kubectl -n argo-rollouts get pods | grep -q "Running"; then
    echo "✅ Argo Rollouts running"
    kubectl argo rollouts list -A
else
    echo "❌ Argo Rollouts not running"
fi
echo ""

# 8. Тест мониторинга
echo "8. Testing monitoring stack..."
if kubectl -n monitoring get pods | grep prometheus-kube-prometheus-operator | grep -q "Running"; then
    echo "✅ Prometheus running"
else
    echo "❌ Prometheus issues"
fi
if kubectl -n monitoring get pods | grep grafana | grep -q "Running"; then
    echo "✅ Grafana running"
else
    echo "❌ Grafana issues"
fi
echo ""

# 9. Тест приложения
echo "9. Testing application..."
if kubectl -n ezyshop get pods | grep -q "Running"; then
    echo "✅ Application pods running"
    kubectl -n ezyshop get rollouts
else
    echo "❌ Application issues"
fi
echo ""

# 10. Итоговая статистика
echo "=== Summary ==="
echo "Cluster nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Total pods: $(kubectl get pods -A --no-headers | wc -l)"
echo "Running pods: $(kubectl get pods -A --no-headers | grep Running | wc -l)"
echo "Public URL: $NGROK_URL"
echo ""
echo "Test completed!"
```

Сохранить и запустить:

```bash
chmod +x test-infrastructure.sh
./test-infrastructure.sh
```

---

## Производительность и оптимизация

### Настройка ngrok для production

```bash
# На ngrok-tunnel VM: оптимизация для стабильности

# 1. Увеличить лимиты файловых дескрипторов
cat >> /etc/security/limits.conf <<EOF
admin soft nofile 65536
admin hard nofile 65536
EOF

# 2. Настроить TCP keepalive
cat >> /etc/sysctl.conf <<EOF
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
EOF
sudo sysctl -p

# 3. Настроить автоматический перезапуск при сбое
sudo mkdir -p /etc/systemd/system/ngrok.service.d/
cat > /etc/systemd/system/ngrok.service.d/restart.conf <<EOF
[Service]
Restart=always
RestartSec=10
StartLimitInterval=0
EOF

sudo systemctl daemon-reload
sudo systemctl restart ngrok
```

### Кэширование для ускорения

```bash
# Установить nginx кэш перед ngrok (опционально)
sudo apt install nginx -y

cat > /etc/nginx/sites-available/ngrok-cache <<'EOF'
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=ngrok_cache:10m max_size=1g inactive=60m;

server {
    listen 8080;
    server_name localhost;
    
    location / {
        proxy_pass http://192.168.100.100;
        proxy_cache ngrok_cache;
        proxy_cache_valid 200 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_bypass $http_pragma $http_authorization;
        
        add_header X-Cache-Status $upstream_cache_status;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/ngrok-cache /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Обновить ngrok config для использования кэша
# addr: 127.0.0.1:8080 вместо 192.168.100.100:80
```

---

## Безопасность с ngrok

### Ограничение доступа по IP (платный план)

```yaml
# В ngrok.yml (требуется Business план)
tunnels:
  ezyshop-secure:
    proto: http
    addr: 192.168.100.100:80
    domain: your-domain.ngrok.app
    ip_restriction:
      allow_cidrs:
        - 1.2.3.4/32  # Ваш офисный IP
        - 5.6.7.0/24  # Корпоративная сеть
      deny_cidrs:
        - 0.0.0.0/0   # Блокировать все остальные
```

### Basic Auth для дополнительной защиты

```bash
# Добавить в ngrok config
tunnels:
  ezyshop-protected:
    proto: http
    addr: 192.168.100.100:80
    basic_auth:
      - "admin:secretpassword"
      - "user:anotherpassword"
```

### Webhook для уведомлений о доступе

```yaml
# Настройка webhook в ngrok.yml
webhooks:
  - url: https://your-slack-webhook-url
    events:
      - tunnel_started
      - tunnel_stopped
```

---

## Миграция с ngrok на другие решения

### Если нужно перейти обратно на Cloudflare

```bash
# 1. Остановить ngrok
sudo systemctl stop ngrok
sudo systemctl disable ngrok

# 2. Установить cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# 3. Авторизация
cloudflared tunnel login

# 4. Создать туннель
cloudflared tunnel create k8s-tunnel

# 5. Настроить маршрутизацию
cloudflared tunnel route dns k8s-tunnel ezyshop.yourdomain.com

# 6. Запустить
cloudflared tunnel run k8s-tunnel
```

### Переход на Tailscale (VPN-подход)

```bash
# 1. Установить Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Аутентификация
sudo tailscale up

# 3. Включить subnet routing
sudo tailscale up --advertise-routes=192.168.100.0/24 --accept-routes

# 4. На клиентских машинах также установить Tailscale
# Теперь доступ к 192.168.100.100 из любой точки мира
```

---

## Мониторинг стоимости ngrok

### Отслеживание использования API

```bash
# Скрипт для проверки лимитов
cat > /usr/local/bin/ngrok-usage.sh <<'EOF'
#!/bin/bash
NGROK_API_KEY="your-api-key"

curl -s -H "Authorization: Bearer $NGROK_API_KEY" \
     https://api.ngrok.com/account/usage \
     | jq '{
         total_connections: .connections.total,
         limit: .connections.limit,
         percentage: ((.connections.total / .connections.limit) * 100)
       }'
EOF

chmod +x /usr/local/bin/ngrok-usage.sh
```

---

## Заключение v2.1

Вы успешно заменили Cloudflare Tunnel на ngrok в вашей Production-Ready инфраструктуре!

### Преимущества текущей конфигурации

1. **Простота**: Один агент, минимальная конфигурация
2. **Скорость**: Готово к работе за 10 минут
3. **Безопасность**: Автоматический TLS из коробки
4. **Гибкость**: Легко переключаться между решениями

### Следующие шаги

1. Настройте мониторинг ngrok туннеля
2. Добавьте alerts для падения туннеля
3. Рассмотрите переход на платный план для статического URL
4. Настройте backup стратегию для ngrok конфигурации

### Полезные команды

```bash
# Проверка статуса
ssh admin@192.168.100.60 'sudo systemctl status ngrok'

# Получение URL
ssh admin@192.168.100.60 'curl -s http://localhost:4040/api/tunnels | jq -r ".tunnels[0].public_url"'

# Перезапуск туннеля
ssh admin@192.168.100.60 'sudo systemctl restart ngrok'

# Проверка логов
ssh admin@192.168.100.60 'sudo journalctl -u ngrok -f'
```

---

**Версия**: 2.1.0  
**Последнее обновление**: Октябрь 2024  
**Изменения**: Замена Cloudflare на ngrok для упрощенного внешнего доступа  

Поздравляем! Ваша инфраструктура готова к работе с упрощенным доступом через ngrok!
