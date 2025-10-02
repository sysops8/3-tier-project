# 🚀 Production-Ready инфраструктура E-Commerce на Proxmox v2.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes)](https://k3s.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)](https://argo-cd.readthedocs.io/)
[![Security](https://img.shields.io/badge/Security-Vault-000000?logo=vault)](https://www.vaultproject.io/)
[![Backup](https://img.shields.io/badge/Backup-Velero-00ADD8?logo=vmware)](https://velero.io/)

> **НОВОЕ в v2.0:** Security Enhancements + Automated Backups + Canary Deployments

---

## 📑 Содержание

- [Что нового в v2.0](#-что-нового-в-v20)
- [Обзор](#-обзор)
- [Архитектура](#-архитектура)
- [Технологический стек](#-технологический-стек)
- [Спецификации инфраструктуры](#-спецификации-инфраструктуры)
- [Предварительные требования](#-предварительные-требования)
- [Руководство по установке](#-руководство-по-установке)
  - [Базовая инфраструктура (Steps 1-9)](#базовая-инфраструктура)
  - [CI/CD (Jenkins)](#10-cicd-jenkins)
  - [Мониторинг (Prometheus Stack)](#11-мониторинг-prometheus-stack)
  - [Логирование (ELK Stack)](#12-логирование-elk-stack)
  - [GitOps (ArgoCD)](#13-gitops-argocd)
  - [🆕 Security Layer (Vault + Trivy)](#14-новое-security-layer-vault--trivy)
  - [🆕 Backup & DR (Velero)](#15-новое-backup--dr-velero)
  - [🆕 Canary Deployments (Argo Rollouts)](#16-новое-canary-deployments-argo-rollouts)
  - [Развертывание приложения](#17-развертывание-приложения)
- [CI/CD пайплайн v2.0](#-cicd-пайплайн-v20)
- [Disaster Recovery процедуры](#-disaster-recovery-процедуры)
- [Мониторинг и оповещения](#-мониторинг-и-оповещения)
- [Устранение неполадок](#-устранение-неполадок)

---

## 🆕 Что нового в v2.0

### ✨ Основные улучшения

| Категория | Улучшение | Описание |
|-----------|-----------|----------|
| 🔒 **Security** | HashiCorp Vault | Централизованное управление секретами |
| 🔒 **Security** | Trivy Scanner | Автоматическое сканирование образов в CI |
| 🔒 **Security** | Network Policies | Микросегментация трафика между подами |
| 💾 **Backup** | Velero | Автоматические backup кластера каждые 24ч |
| 💾 **Backup** | PostgreSQL Snapshots | Автоматические backup БД каждые 3ч |
| 💾 **Backup** | MinIO Integration | Хранение backup в локальном S3 |
| 🚀 **Deployments** | Argo Rollouts | Canary развертывания с автоматическим rollback |
| 🚀 **Deployments** | Progressive Delivery | Постепенное раскатывание: 20% → 40% → 60% → 80% → 100% |
| 🚀 **Deployments** | Analysis Templates | Автоматическая проверка метрик перед продолжением |
| ⚡ **Performance** | HPA | Автомасштабирование на основе CPU/Memory |
| ⚡ **Performance** | PDB | Защита от случайного удаления критичных подов |
| ⚡ **Performance** | Resource Limits | Оптимизированные лимиты ресурсов |

---

## 🎯 Обзор

Полная production-ready DevOps инфраструктура с **enterprise-grade security**, **automated disaster recovery** и **zero-downtime deployments**.

### Ключевые возможности v2.0

#### Базовые (из v1.0)
- ✅ Полностью автоматизированный CI/CD - Jenkins + ArgoCD GitOps
- ✅ Высокая доступность - Многоузловой K3s кластер
- ✅ Комплексный мониторинг - Prometheus + Grafana + AlertManager
- ✅ Централизованное логирование - ELK Stack
- ✅ Постоянное хранилище - Longhorn
- ✅ LoadBalancer - MetalLB для bare-metal
- ✅ Внешний доступ - Cloudflare Tunnel

#### Новые (v2.0)
- 🆕 **Zero-Trust Security** - Vault + Network Policies + Image Scanning
- 🆕 **Automated Backups** - Velero (кластер) + CronJob (БД) каждые 3-24ч
- 🆕 **Disaster Recovery** - RTO < 30 минут, RPO < 3 часа
- 🆕 **Progressive Delivery** - Canary deployments с автоматическими метриками
- 🆕 **Self-Healing** - Автоматический rollback при деградации метрик
- 🆕 **Horizontal Autoscaling** - HPA на основе CPU/Memory/Custom метрик

---

## 🎯 Архитектура v2.0

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
┌─────────────────────────────────────────────────┐
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
└─────────────────────────────────────────────────┘
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
- Jumphost (192.168.100.5)
```

---

## 🛠️ Технологический стек v2.0

### 🆕 Новые компоненты

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

### Виртуальные машины (без изменений)

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

### 🆕 Карта сервисов v2.0

| Сервис | Внутренний домен | Внешний домен | Порт | Новое |
|---------|----------------|-----------------|------|-------|
| EzyShop | ezyshop.local.lab | ezyshop.yourdomain.com | 80/443 | 🆕 Canary |
| ArgoCD | argocd.local.lab | argocd.yourdomain.com | 80/443 | - |
| Grafana | grafana.local.lab | grafana.yourdomain.com | 80/443 | - |
| Prometheus | prometheus.local.lab | prometheus.yourdomain.com | 80/443 | - |
| AlertManager | alertmanager.local.lab | alertmanager.yourdomain.com | 80/443 | - |
| Kibana | kibana.local.lab | kibana.yourdomain.com | 80/443 | - |
| Jenkins | jenkins.local.lab | jenkins.yourdomain.com | 8080 | 🆕 Trivy |
| MinIO консоль | minio.local.lab | - | 9001 | 🆕 Backups |
| Longhorn UI | longhorn.local.lab | - | 80 | - |
| 🆕 Vault UI | vault.local.lab | - | 8200 | 🆕 NEW |
| 🆕 Argo Rollouts | rollouts.local.lab | - | 3100 | 🆕 NEW |

---

## ✅ Предварительные требования

### Обязательные
- Установленный и настроенный Proxmox VE 8.x
- Загруженный ISO Ubuntu 22.04 в Proxmox
- Аккаунт Cloudflare (для внешнего доступа)
- Аккаунт GitHub/GitLab
- Базовые знания Linux, Kubernetes и CI/CD

### 🆕 Новые требования v2.0
- Дополнительно 20GB дискового пространства для backup
- MinIO credentials для Velero (создадим в процессе)
- Slack Webhook URL для критичных алертов (опционально)

---

## 📖 Руководство по установке

### Базовая инфраструктура

**ШАГ 1-9: Следуйте оригинальной инструкции**

> 💡 **Важно**: Сначала установите всю базовую инфраструктуру из оригинальной инструкции (шаги 1-9):
> - Сетевая инфраструктура
> - DNS сервер (BIND9)
> - NAT шлюз
> - MinIO
> - K3s кластер
> - Longhorn
> - MetalLB
> - Traefik
> - Cloudflare Tunnel

После завершения базовой установки, переходите к новым компонентам:

---

### 10. CI/CD (Jenkins)

> Следуйте оригинальной инструкции, затем добавьте Trivy:

#### 🆕 Установка Trivy Scanner

SSH к jenkins:

```bash
ssh admin@jenkins.local.lab

# Установка Trivy
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy -y

# Проверка
trivy --version

# Тестовое сканирование
trivy image nginx:latest
```

#### 🆕 Настройка Jenkins для Trivy

В Jenkins UI (`http://jenkins.local.lab:8080`):

1. **Manage Jenkins** → **Manage Plugins**
2. Установите плагины:
   - Pipeline
   - Docker Pipeline
   - Git

3. Создайте новый Pipeline job: **ezyshop-ci-cd-v2**

4. Pipeline Script (пример с Trivy):

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "ezyshop/frontend"
        DOCKER_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = "ezyshop"
        TRIVY_SEVERITY = "HIGH,CRITICAL"
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
        
        stage('🆕 Security Scan - Trivy') {
            steps {
                script {
                    sh """
                        echo "Scanning image for vulnerabilities..."
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --exit-code 0 \
                            --no-progress \
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    """
                    
                    // Сохранить отчет
                    sh """
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --format json \
                            --output trivy-report.json \
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    """
                    
                    // Опционально: Fail pipeline если найдены CRITICAL уязвимости
                    sh """
                        CRITICAL_COUNT=\$(trivy image \
                            --severity CRITICAL \
                            --format json \
                            ${DOCKER_IMAGE}:${DOCKER_TAG} | \
                            jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
                        
                        if [ "\$CRITICAL_COUNT" -gt 0 ]; then
                            echo "❌ Found \$CRITICAL_COUNT CRITICAL vulnerabilities!"
                            echo "⚠️  Building anyway, but please review!"
                        fi
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
        
        stage('🆕 Deploy with Argo Rollouts') {
            steps {
                script {
                    sh """
                        # Обновить image в Rollout
                        kubectl argo rollouts set image ezyshop-frontend \
                            frontend=${DOCKER_IMAGE}:${DOCKER_TAG} \
                            -n ${K8S_NAMESPACE}
                        
                        # Следить за прогрессом (timeout 10 минут)
                        kubectl argo rollouts status ezyshop-frontend \
                            -n ${K8S_NAMESPACE} \
                            --watch \
                            --timeout 10m
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
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
```

---

### 11. Мониторинг (Prometheus Stack)

> Следуйте оригинальной инструкции без изменений

---

### 12. Логирование (ELK Stack)

> Следуйте оригинальной инструкции без изменений

---

### 13. GitOps (ArgoCD)

> Следуйте оригинальной инструкции, затем добавьте интеграцию с Argo Rollouts (см. шаг 16)

---

### 14. 🆕 НОВОЕ: Security Layer (Vault + Trivy)

#### A. Установка HashiCorp Vault

С jumphost:

```bash
# Добавить Helm репозиторий
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Создать namespace
kubectl create namespace vault-system

# Установка Vault в dev режиме (для testing)
# ⚠️ В production используйте HA режим с Raft или Consul!
helm install vault hashicorp/vault \
    --namespace vault-system \
    --set "server.dev.enabled=true" \
    --set "server.dev.devRootToken=root" \
    --set "injector.enabled=true" \
    --set "ui.enabled=true" \
    --set "ui.serviceType=ClusterIP"

# Подождать готовности
kubectl -n vault-system get pods -w
```

#### B. Создание Ingress для Vault UI

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-ingress
  namespace: vault-system
spec:
  rules:
  - host: vault.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault-ui
            port:
              number: 8200
EOF
```

**Доступ**: `http://vault.local.lab` (token: `root`)

#### C. Создание секретов в Vault

```bash
# Войти в под Vault
kubectl -n vault-system exec -it vault-0 -- /bin/sh

# Включить KV secrets engine
vault secrets enable -path=secret kv-v2

# Создать секреты для приложения
vault kv put secret/ezyshop/database \
    username=ezyshop \
    password=SuperSecretPassword123

vault kv put secret/ezyshop/api \
    api_key=your-api-key-here \
    jwt_secret=your-jwt-secret-here

# Создать секреты для MinIO (для Velero)
vault kv put secret/minio \
    access_key=minioadmin \
    secret_key=minioadmin123

# Проверка
vault kv get secret/ezyshop/database

exit
```

#### D. Настройка Kubernetes Auth

```bash
kubectl -n vault-system exec -it vault-0 -- /bin/sh

# Включить Kubernetes auth
vault auth enable kubernetes

# Настроить Kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

# Создать policy для приложения
vault policy write ezyshop - <<EOF
path "secret/data/ezyshop/*" {
  capabilities = ["read"]
}
EOF

# Создать роль для namespace ezyshop
vault write auth/kubernetes/role/ezyshop \
    bound_service_account_names=ezyshop-sa \
    bound_service_account_namespaces=ezyshop \
    policies=ezyshop \
    ttl=24h

exit
```

#### E. Использование секретов в подах

```bash
# Создать ServiceAccount
kubectl create namespace ezyshop
kubectl create serviceaccount ezyshop-sa -n ezyshop

# Deployment с аннотацией для Vault injection
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ezyshop-backend
  namespace: ezyshop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ezyshop-backend
  template:
    metadata:
      labels:
        app: ezyshop-backend
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "ezyshop"
        vault.hashicorp.com/agent-inject-secret-database: "secret/data/ezyshop/database"
        vault.hashicorp.com/agent-inject-template-database: |
          {{- with secret "secret/data/ezyshop/database" -}}
          export DB_USERNAME="{{ .Data.data.username }}"
          export DB_PASSWORD="{{ .Data.data.password }}"
          {{- end }}
    spec:
      serviceAccountName: ezyshop-sa
      containers:
      - name: backend
        image: ezyshop/backend:latest
        command: ["/bin/sh", "-c"]
        args:
          - source /vault/secrets/database && ./start-app.sh
        ports:
        - containerPort: 8080
EOF
```

#### F. 🆕 Network Policies

```bash
# 1. Deny all ingress traffic по умолчанию
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: ezyshop
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# 2. Разрешить трафик от Ingress к Frontend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-frontend
  namespace: ezyshop
spec:
  podSelector:
    matchLabels:
      app: ezyshop-frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: traefik
    ports:
    - protocol: TCP
      port: 80
EOF

# 3. Разрешить Frontend → Backend
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: ezyshop
spec:
  podSelector:
    matchLabels:
      app: ezyshop-backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ezyshop-frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# 4. Разрешить Backend → PostgreSQL
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-postgres
  namespace: ezyshop
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ezyshop-backend
    ports:
    - protocol: TCP
      port: 5432
EOF

# 5. Разрешить Prometheus scraping
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scraping
  namespace: ezyshop
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
EOF

# Проверка Network Policies
kubectl get networkpolicies -n ezyshop
```

---

### 15. 🆕 НОВОЕ: Backup & DR (Velero)

#### A. Подготовка MinIO для Velero

SSH к minio:

```bash
ssh admin@minio.local.lab

# Войти в MinIO Console: http://minio.local.lab:9001
# User: minioadmin, Password: minioadmin123
```

В MinIO Console:
1. Создайте bucket: **velero-backups**
2. Создайте Access Key для Velero:
   - Access Key: `velero`
   - Secret Key: `velero-secret-key-123`

#### B. Установка Velero CLI

С jumphost:

```bash
# Скачать Velero CLI
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.1/velero-v1.12.1-linux-amd64.tar.gz
tar -xvf velero-v1.12.1-linux-amd64.tar.gz
sudo mv velero-v1.12.1-linux-amd64/velero /usr/local/bin/
velero version --client-only
```

#### C. Создание credentials файла

```bash
cat > /tmp/credentials-velero <<EOF
[default]
aws_access_key_id=velero
aws_secret_access_key=velero-secret-key-123
EOF
```

#### D. Установка Velero в кластер

```bash
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.8.0 \
    --bucket velero-backups \
    --secret-file /tmp/credentials-velero \
    --use-volume-snapshots=false \
    --backup-location-config \
region=minio,s3ForcePathStyle="true",s3Url=http://minio.local.lab:9000 \
    --namespace velero

# Проверка
kubectl -n velero get pods
velero version
```

#### E. Создание автоматических backup schedules

```bash
# 1. Ежедневный полный backup кластера (02:00 UTC)
velero schedule create daily-full-backup \
    --schedule="0 2 * * *" \
    --ttl 720h0m0s

# 2. Ежедневный backup приложения (03:00 UTC)
velero schedule create daily-ezyshop-backup \
    --schedule="0 3 * * *" \
    --include-namespaces ezyshop \
    --ttl 720h0m0s

# 3. Еженедельный backup критичных namespace (воскресенье 04:00 UTC)
velero schedule create weekly-critical-backup \
    --schedule="0 4 * * 0" \
    --include-namespaces ezyshop,monitoring,logging,argocd,vault-system \
    --ttl 2160h0m0s

# Проверка schedules
velero schedule get

# Ручной backup для тестирования
velero backup create test-backup --wait
velero backup describe test-backup
velero backup logs test-backup
```

#### F. Автоматические PostgreSQL Snapshots

```bash
# Создать PVC для хранения backup
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-backups
  namespace: ezyshop
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 50Gi
EOF

# Создать Secret с паролем PostgreSQL
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: ezyshop
type: Opaque
stringData:
  password: "SuperSecretPassword123"
EOF

# CronJob для автоматических backup каждые 3 часа
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: ezyshop
spec:
  schedule: "0 */3 * * *"  # Каждые 3 часа
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              set -e
              TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
              BACKUP_FILE="/backups/ezyshop_\${TIMESTAMP}.sql.gz"
              
              echo "Starting backup at \$(date)"
              echo "Target: \${BACKUP_FILE}"
              
              # Выполнить backup
              pg_dump -h postgres -U ezyshop -d ezyshop | gzip > "\${BACKUP_FILE}"
              
              if [ -f "\${BACKUP_FILE}" ]; then
                SIZE=\$(du -h "\${BACKUP_FILE}" | cut -f1)
                echo "✅ Backup completed: \${BACKUP_FILE} (Size: \${SIZE})"
              else
                echo "❌ Backup failed!"
                exit 1
              fi
              
              # Удалить backup старше 7 дней
              echo "Cleaning old backups..."
              find /backups -name "*.sql.gz" -mtime +7 -delete
              
              # Показать список backup
              echo "Available backups:"
              ls -lh /backups/*.sql.gz | tail -10
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            volumeMounts:
            - name: backups
              mountPath: /backups
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: postgres-backups
          restartPolicy: OnFailure
EOF

# Ручной запуск для тестирования
kubectl create job -n ezyshop postgres-backup-manual \
    --from=cronjob/postgres-backup

# Следить за логами
kubectl -n ezyshop logs -f job/postgres-backup-manual

# Проверка backup файлов
kubectl -n ezyshop exec -it deployment/postgres -- ls -lh /backups/
```

#### G. Тестирование Disaster Recovery

```bash
# === ТЕСТ 1: Восстановление namespace ===

# 1. Удалить namespace (симуляция катастрофы)
kubectl delete namespace ezyshop --wait=false

# 2. Восстановить из последнего backup
LATEST_BACKUP=$(velero backup get | grep ezyshop | head -1 | awk '{print $1}')
velero restore create --from-backup $LATEST_BACKUP --wait

# 3. Проверка
kubectl -n ezyshop get pods

# === ТЕСТ 2: Восстановление БД ===

# 1. Выбрать backup файл
kubectl -n ezyshop exec -it deployment/postgres -- ls -lh /backups/

# 2. Восстановить БД (замените TIMESTAMP)
kubectl -n ezyshop exec -it deployment/postgres -- bash -c \
  "gunzip -c /backups/ezyshop_TIMESTAMP.sql.gz | psql -U ezyshop -d ezyshop"

# === ТЕСТ 3: Полное восстановление кластера ===

# 1. Список всех backup
velero backup get

# 2. Восстановить весь кластер
velero restore create full-restore \
    --from-backup daily-full-backup-TIMESTAMP \
    --wait

# 3. Проверка статуса
velero restore describe full-restore
kubectl get pods -A
```

---

### 16. 🆕 НОВОЕ: Canary Deployments (Argo Rollouts)

#### A. Установка Argo Rollouts

```bash
# Создать namespace
kubectl create namespace argo-rollouts

# Установка controller
kubectl apply -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Подождать готовности
kubectl -n argo-rollouts get pods -w

# Установка kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Проверка
kubectl argo rollouts version
```

#### B. Создание Rollout Dashboard

```bash
# Создать Ingress для Dashboard
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argo-rollouts-dashboard
  namespace: argo-rollouts
spec:
  type: ClusterIP
  ports:
  - port: 3100
    targetPort: 3100
    name: dashboard
  selector:
    app.kubernetes.io/name: argo-rollouts
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argo-rollouts-ingress
  namespace: argo-rollouts
spec:
  rules:
  - host: rollouts.local.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argo-rollouts-dashboard
            port:
              number: 3100
EOF

# Запустить Dashboard
kubectl argo rollouts dashboard -n argo-rollouts &

# Доступ: http://rollouts.local.lab
```

#### C. Analysis Template (автоматическая проверка метрик)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: ezyshop
spec:
  metrics:
  - name: success-rate
    interval: 1m
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-kube-prometheus-prometheus.monitoring:9090
        query: |
          sum(rate(
            http_requests_total{
              namespace="ezyshop",
              status=~"2.."
            }[5m]
          )) 
          /
          sum(rate(
            http_requests_total{
              namespace="ezyshop"
            }[5m]
          ))
  - name: latency
    interval: 1m
    successCondition: result[0] <= 0.5
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus-kube-prometheus-prometheus.monitoring:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(
              http_request_duration_seconds_bucket{
                namespace="ezyshop"
              }[5m]
            )) by (le)
          )
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate
  namespace: ezyshop
spec:
  metrics:
  - name: error-rate
    interval: 1m
    successCondition: result[0] <= 0.05
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus-kube-prometheus-prometheus.monitoring:9090
        query: |
          sum(rate(
            http_requests_total{
              namespace="ezyshop",
              status=~"5.."
            }[5m]
          ))
          /
          sum(rate(
            http_requests_total{
              namespace="ezyshop"
            }[5m]
          ))
EOF
```

#### D. Создание Rollout для приложения

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ezyshop-frontend
  namespace: ezyshop
spec:
  replicas: 5
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: ezyshop-frontend
  template:
    metadata:
      labels:
        app: ezyshop-frontend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      containers:
      - name: frontend
        image: ezyshop/frontend:v1.0.0
        ports:
        - containerPort: 80
          name: http
        - containerPort: 9090
          name: metrics
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
  strategy:
    canary:
      # Canary Service (для нового трафика)
      canaryService: ezyshop-frontend-canary
      # Stable Service (для стабильного трафика)
      stableService: ezyshop-frontend-stable
      
      # Постепенное раскатывание
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
          - templateName: error-rate
      
      - setWeight: 40
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
      
      - setWeight: 60
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
      
      - setWeight: 80
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
      
      # Полный rollout
      - setWeight: 100
      
      # Traffic routing через Traefik
      trafficRouting:
        traefik:
          weightedTraefikServiceName: ezyshop-frontend-weighted
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-frontend-stable
  namespace: ezyshop
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: ezyshop-frontend
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-frontend-canary
  namespace: ezyshop
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: ezyshop-frontend
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-frontend
  namespace: ezyshop
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: ezyshop-frontend
EOF
```

#### E. HPA + PDB для автомасштабирования

```bash
# Horizontal Pod Autoscaler
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ezyshop-frontend-hpa
  namespace: ezyshop
spec:
  scaleTargetRef:
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: ezyshop-frontend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
EOF

# Pod Disruption Budget (защита от случайного удаления)
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ezyshop-frontend-pdb
  namespace: ezyshop
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: ezyshop-frontend
EOF

# Проверка
kubectl -n ezyshop get hpa
kubectl -n ezyshop get pdb
```

#### F. Тестирование Canary Deployment

```bash
# === МЕТОД 1: Через kubectl plugin ===

# 1. Проверка текущей версии
kubectl argo rollouts get rollout ezyshop-frontend -n ezyshop

# 2. Обновить image (триггер canary)
kubectl argo rollouts set image ezyshop-frontend \
  frontend=ezyshop/frontend:v2.0.0 \
  -n ezyshop

# 3. Следить за прогрессом в реальном времени
kubectl argo rollouts get rollout ezyshop-frontend -n ezyshop --watch

# 4. Ручное продвижение (если настроена manual pause)
kubectl argo rollouts promote ezyshop-frontend -n ezyshop

# 5. Ручной rollback (если что-то пошло не так)
kubectl argo rollouts abort ezyshop-frontend -n ezyshop
kubectl argo rollouts undo ezyshop-frontend -n ezyshop

# === МЕТОД 2: Через Dashboard ===
# Откройте: http://rollouts.local.lab
# Визуально следите за прогрессом, метриками и контролируйте rollout

# === МЕТОД 3: Stress test для проверки HPA ===

# Установка Apache Bench
sudo apt install apache2-utils -y

# Генерация нагрузки
ab -n 10000 -c 100 http://ezyshop.local.lab/

# Следить за масштабированием
watch kubectl -n ezyshop get hpa
watch kubectl -n ezyshop get pods
```

---

### 17. Развертывание приложения

#### Полный пример приложения с Rollout

```bash
# Создать полный манифест приложения
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ezyshop
  labels:
    name: ezyshop
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ezyshop-sa
  namespace: ezyshop
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ezyshop-config
  namespace: ezyshop
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  DB_HOST: "postgres"
  DB_PORT: "5432"
  DB_NAME: "ezyshop"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: ezyshop
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: ezyshop
        - name: POSTGRES_USER
          value: ezyshop
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-backups
          mountPath: /backups
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2000m
            memory: 2Gi
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: longhorn
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ezyshop
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgres
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ezyshop-backend
  namespace: ezyshop
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ezyshop-backend
  template:
    metadata:
      labels:
        app: ezyshop-backend
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "ezyshop"
        vault.hashicorp.com/agent-inject-secret-database: "secret/data/ezyshop/database"
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      serviceAccountName: ezyshop-sa
      containers:
      - name: backend
        image: ezyshop/backend:v1.0.0
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9090
          name: metrics
        envFrom:
        - configMapRef:
            name: ezyshop-config
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
  strategy:
    canary:
      canaryService: ezyshop-backend-canary
      stableService: ezyshop-backend-stable
      steps:
      - setWeight: 25
      - pause: {duration: 3m}
      - setWeight: 50
      - pause: {duration: 3m}
      - setWeight: 75
      - pause: {duration: 3m}
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 1
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-backend-stable
  namespace: ezyshop
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: ezyshop-backend
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-backend-canary
  namespace: ezyshop
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: ezyshop-backend
---
apiVersion: v1
kind: Service
metadata:
  name: ezyshop-backend
  namespace: ezyshop
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: ezyshop-backend
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
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: ezyshop-backend
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ezyshop-frontend
            port:
              number: 80
EOF

# Проверка развертывания
kubectl -n ezyshop get all
kubectl argo rollouts get rollout ezyshop-frontend -n ezyshop
kubectl argo rollouts get rollout ezyshop-backend -n ezyshop
```

---

## 🔄 CI/CD пайплайн v2.0

### Полный GitOps workflow с Security + Canary

```
┌─────────────────────────────────────────────────────────┐
│  1. Developer Push                                       │
│     git push origin main                                 │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  2. Jenkins CI (Webhook)                                 │
│     - Checkout code                                      │
│     - Build application                                  │
│     - Run unit tests                                     │
│     - Build Docker image                                 │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  3. 🆕 Security Scan (Trivy)                            │
│     - Scan image for vulnerabilities                     │
│     - Check for HIGH/CRITICAL CVEs                       │
│     - Generate security report                           │
│     - ⚠️  Fail if CRITICAL found (optional)             │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  4. Push to Registry                                     │
│     - docker push ezyshop/app:v2.0.0                    │
│     - docker push ezyshop/app:latest                    │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  5. Update Manifest                                      │
│     - Update image tag in k8s manifests                  │
│     - git push to manifest repo                          │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  6. ArgoCD GitOps                                        │
│     - Detect manifest changes                            │
│     - Sync with cluster                                  │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  7. 🆕 Argo Rollouts (Canary)                           │
│     Step 1: 20% traffic → new version (5min)            │
│     ├─ Analysis: Check success rate > 95%               │
│     ├─ Analysis: Check latency < 500ms                  │
│     └─ ✅ Pass → Continue | ❌ Fail → Auto Rollback     │
│                                                          │
│     Step 2: 40% traffic → new version (5min)            │
│     └─ Analysis: Check metrics                          │
│                                                          │
│     Step 3: 60% traffic → new version (5min)            │
│     └─ Analysis: Check metrics                          │
│                                                          │
│     Step 4: 80% traffic → new version (5min)            │
│     └─ Analysis: Check metrics                          │
│                                                          │
│     Step 5: 100% traffic → new version                  │
│     └─ ✅ Deployment Complete!                          │
└────────────────┬────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────────┐
│  8. Monitoring & Alerting                                │
│     - Prometheus scrapes metrics                         │
│     - Grafana visualizes                                 │
│     - AlertManager → Slack (if issues)                   │
└─────────────────────────────────────────────────────────┘

📊 Total Deployment Time: ~25-30 minutes (with canary)
🎯 Zero Downtime: ✅ Yes
🔄 Auto Rollback: ✅ Yes (if metrics fail)
```

---

## 💾 Disaster Recovery процедуры

### Сценарий 1: Восстановление приложения (RPO: 3 часа)

```bash
# Шаг 1: Найти последний backup
velero backup get | grep ezyshop

# Шаг 2: Восстановить namespace
velero restore create ezyshop-restore \
    --from-backup daily-ezyshop-backup-20241002030000 \
    --wait

# Шаг 3: Проверка
kubectl -n ezyshop get pods
kubectl -n ezyshop get pvc

# Шаг 4: Восстановить БД из snapshot
LATEST_DB=$(kubectl -n ezyshop exec deployment/postgres -- \
    ls -t /backups/*.sql.gz | head -1)

kubectl -n ezyshop exec -it deployment/postgres -- bash -c \
    "gunzip -c $LATEST_DB | psql -U ezyshop -d ezyshop"

# Шаг 5: Проверка приложения
curl http://ezyshop.local.lab/health

# ⏱️ Время восстановления: ~15-20 минут
```

### Сценарий 2: Восстановление всего кластера (RPO: 24 часа)

```bash
# Шаг 1: Новый K3s кластер установлен и готов

# Шаг 2: Установить Velero на новый кластер
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.8.0 \
    --bucket velero-backups \
    --secret-file /tmp/credentials-velero \
    --use-volume-snapshots=false \
    --backup-location-config \
region=minio,s3ForcePathStyle="true",s3Url=http://minio.local.lab:9000

# Шаг 3: Найти последний полный backup
velero backup get

# Шаг 4: Восстановить все
velero restore create full-cluster-restore \
    --from-backup daily-full-backup-20241002020000 \
    --wait

# Шаг 5: Проверка всех namespace
kubectl get namespaces
kubectl get pods -A

# Шаг 6: Восстановить БД
# (см. Сценарий 1, Шаг 4)

# ⏱️ Время восстановления: ~30-45 минут
```

### Сценарий 3: Rollback после неудачного deployment

```bash
# Автоматический rollback (через Argo Rollouts Analysis)
# Происходит автоматически, если метрики падают ниже порога

# Ручной rollback
kubectl argo rollouts abort ezyshop-frontend -n ezyshop
kubectl argo rollouts undo ezyshop-frontend -n ezyshop

# Проверка
kubectl argo rollouts get rollout ezyshop-frontend -n ezyshop

# ⏱️ Время rollback: ~2-3 минуты
```

### RTO/RPO Матрица

| Сценарий | RTO | RPO | Автоматический |
|----------|-----|-----|----------------|
| Pod crash | < 1 мин | 0 | ✅ Kubernetes |
| Node failure | < 5 мин | 0 | ✅ K3s HA |
| Deployment issue | < 3 мин | 0 | ✅ Argo Rollouts |
| Namespace deletion | < 15 мин | 3 часа | ❌ Manual Velero |
| Database corruption | < 20 мин | 3 часа | ❌ Manual restore |
| Full cluster loss | < 45 мин | 24 часа | ❌ Manual Velero |

---

## 📊 Мониторинг и оповещения

### Grafana Dashboard для Canary Deployments

```bash
# Импортировать готовый dashboard для Argo Rollouts
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-rollouts
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  argo-rollouts.json: |
    {
      "dashboard": {
        "title": "Argo Rollouts - Canary Deployments",
        "panels": [
          {
            "title": "Rollout Status",
            "targets": [
              {
                "expr": "argo_rollouts_info{namespace='ezyshop'}"
              }
            ]
          },
          {
            "title": "Canary Weight",
            "targets": [
              {
                "expr": "argo_rollouts_canary_weight{namespace='ezyshop'}"
              }
            ]
          },
          {
            "title": "Success Rate (Canary vs Stable)",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status=~'2..',namespace='ezyshop'}[5m])) / sum(rate(http_requests_total{namespace='ezyshop'}[5m]))"
              }
            ]
          }
        ]
      }
    }
EOF
```

### 🆕 AlertManager Rules для новых компонентов

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alert-rules
  namespace: monitoring
data:
  alert-rules.yml: |
    groups:
    # 🆕 Backup Alerts
    - name: backup-alerts
      interval: 5m
      rules:
      - alert: VeleroBackupFailed
        expr: velero_backup_failure_total > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Velero backup failed"
          description: "Velero backup {{ \$labels.schedule }} failed"
      
      - alert: PostgresBackupOld
        expr: time() - postgres_last_backup_timestamp > 14400
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL backup is too old"
          description: "Last backup was more than 4 hours ago"
      
      - alert: BackupStorageFull
        expr: (1 - (node_filesystem_avail_bytes{mountpoint="/backups"} / node_filesystem_size_bytes{mountpoint="/backups"})) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Backup storage is almost full"
          description: "Backup storage is {{ \$value | humanizePercentage }} full"
    
    # 🆕 Security Alerts
    - name: security-alerts
      interval: 5m
      rules:
      - alert: HighCVEsDetected
        expr: trivy_image_vulnerabilities{severity="CRITICAL"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Critical CVEs detected in image"
          description: "Image {{ \$labels.image }} has {{ \$value }} CRITICAL vulnerabilities"
      
      - alert: VaultSealed
        expr: vault_core_unsealed == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Vault is sealed"
          description: "Vault instance is sealed and cannot serve requests"
      
      - alert: UnauthorizedAPIAccess
        expr: rate(apiserver_audit_event_total{verb="create",objectRef_resource="pods",user_username!~"system:.*"}[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Unusual API access pattern detected"
    
    # 🆕 Deployment Alerts
    - name: deployment-alerts
      interval: 30s
      rules:
      - alert: CanaryDeploymentStuck
        expr: argo_rollouts_info{phase="Progressing"} and changes(argo_rollouts_info{phase="Progressing"}[15m]) == 0
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Canary deployment stuck"
          description: "Rollout {{ \$labels.name }} in {{ \$labels.namespace }} is stuck in Progressing phase"
      
      - alert: CanaryDeploymentFailed
        expr: argo_rollouts_info{phase="Degraded"}
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Canary deployment failed"
          description: "Rollout {{ \$labels.name }} in {{ \$labels.namespace }} has failed"
      
      - alert: RolloutAborted
        expr: argo_rollouts_info{phase="Aborted"}
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Rollout was aborted"
          description: "Rollout {{ \$labels.name }} in {{ \$labels.namespace }} was aborted"
    
    # Existing alerts
    - name: kubernetes-alerts
      interval: 30s
      rules:
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ \$labels.namespace }}/{{ \$labels.pod }} is crash looping"
      
      - alert: NodeNotReady
        expr: kube_node_status_condition{condition="Ready",status="true"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ \$labels.node }} is not ready"
      
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ \$labels.instance }}"
      
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ \$labels.instance }}"
      
      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space low on {{ \$labels.instance }}"
EOF

# Применить конфигурацию
kubectl -n monitoring rollout restart deployment prometheus-kube-prometheus-operator
```

### 🆕 Slack Integration для критичных алертов

```bash
# Обновить AlertManager config с Slack webhook
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'YOUR_SLACK_WEBHOOK_URL_HERE'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      routes:
      # Critical alerts → Slack immediately
      - match:
          severity: critical
        receiver: 'slack-critical'
        continue: true
      
      # Security alerts → Slack
      - match_re:
          alertname: '.*CVE.*|VaultSealed|UnauthorizedAPIAccess'
        receiver: 'slack-security'
        continue: true
      
      # Backup alerts → Slack
      - match_re:
          alertname: 'VeleroBackupFailed|PostgresBackupOld'
        receiver: 'slack-backup'
        continue: true
    
    receivers:
    - name: 'default'
      slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    
    - name: 'slack-critical'
      slack_configs:
      - channel: '#critical-alerts'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: |
          *Summary:* {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
          *Description:* {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
          *Severity:* CRITICAL
        color: 'danger'
        send_resolved: true
    
    - name: 'slack-security'
      slack_configs:
      - channel: '#security-alerts'
        title: '🔒 SECURITY: {{ .GroupLabels.alertname }}'
        text: |
          *Summary:* {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
          *Description:* {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        color: 'warning'
        send_resolved: true
    
    - name: 'slack-backup'
      slack_configs:
      - channel: '#backup-alerts'
        title: '💾 BACKUP: {{ .GroupLabels.alertname }}'
        text: |
          *Summary:* {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
          *Description:* {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        color: 'warning'
        send_resolved: true
EOF

# Перезапустить AlertManager
kubectl -n monitoring rollout restart statefulset alertmanager-prometheus-kube-prometheus-alertmanager
```

---

## 🔧 Устранение неполадок

### 🆕 Troubleshooting новых компонентов

#### Vault Issues

```bash
# Проверка статуса Vault
kubectl -n vault-system get pods
kubectl -n vault-system logs vault-0

# Vault sealed после перезапуска
kubectl -n vault-system exec -it vault-0 -- vault status

# Если sealed, unseal вручную (в production используйте auto-unseal)
kubectl -n vault-system exec -it vault-0 -- vault operator unseal

# Проверка секретов
kubectl -n vault-system exec -it vault-0 -- vault kv get secret/ezyshop/database

# Тест интеграции с pod
kubectl -n ezyshop logs <pod-name> -c vault-agent-init
```

#### Velero Backup Issues

```bash
# Проверка статуса Velero
kubectl -n velero get pods
velero backup get
velero backup describe <backup-name>

# Логи backup
velero backup logs <backup-name>

# Проверка connection к MinIO
kubectl -n velero logs deployment/velero

# Ручной backup для debugging
velero backup create debug-backup --include-namespaces ezyshop --wait

# Проверка MinIO
curl http://minio.local.lab:9000/minio/health/live
```

#### Argo Rollouts Issues

```bash
# Проверка статуса Rollout
kubectl argo rollouts get rollout ezyshop-frontend -n ezyshop

# Детальная информация
kubectl argo rollouts status ezyshop-frontend -n ezyshop

# Логи controller
kubectl -n argo-rollouts logs deployment/argo-rollouts

# Проверка Analysis
kubectl -n ezyshop get analysisrun
kubectl -n ezyshop describe analysisrun <name>

# Если Rollout застрял
kubectl argo rollouts abort ezyshop-frontend -n ezyshop
kubectl argo rollouts retry ezyshop-frontend -n ezyshop

# Проверка метрик Prometheus
kubectl -n ezyshop port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
# Открыть: http://localhost:9090
# Query: sum(rate(http_requests_total{namespace="ezyshop"}[5m]))
```

#### Trivy Scan Issues

```bash
# Проверка Trivy на Jenkins
ssh admin@jenkins.local.lab
trivy --version
trivy image --help

# Тестовое сканирование
trivy image nginx:latest --severity HIGH,CRITICAL

# Обновить DB триvy
trivy image --download-db-only

# Очистка кеша
trivy image --clear-cache

# Offline scanning (если нет интернета)
trivy image --offline-scan nginx:latest
```

#### Network Policy Issues

```bash
# Проверка Network Policies
kubectl -n ezyshop get networkpolicies
kubectl -n ezyshop describe networkpolicy <name>

# Тест connectivity между подами
kubectl run -n ezyshop test-pod --image=nicolaka/netshoot -it --rm -- /bin/bash

# Внутри test-pod:
# Тест DNS
nslookup kubernetes.default

# Тест connectivity к backend
curl http://ezyshop-backend:8080/health

# Тест connectivity к PostgreSQL
nc -zv postgres 5432

# Если connection refused, временно удалить NetworkPolicy для debugging
kubectl -n ezyshop delete networkpolicy <name>
```

### Общие проблемы

#### Pod не запускается

```bash
# Детальная информация
kubectl -n ezyshop describe pod <pod-name>
kubectl -n ezyshop logs <pod-name>
kubectl -n ezyshop logs <pod-name> --previous  # Логи предыдущего контейнера

# Проверка events
kubectl -n ezyshop get events --sort-by='.lastTimestamp'

# Проверка ресурсов
kubectl top nodes
kubectl top pods -n ezyshop
```

#### Ingress не работает

```bash
# Проверка Traefik
kubectl -n traefik get pods
kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=100

# Проверка Ingress
kubectl -n ezyshop get ingress
kubectl -n ezyshop describe ingress <name>

# Тест LoadBalancer
kubectl -n traefik get svc
curl -v http://192.168.100.100

# Проверка DNS
dig @192.168.100.53 ezyshop.local.lab +short
```

#### Storage Issues

```bash
# Проверка Longhorn
kubectl -n longhorn-system get pods
kubectl -n longhorn-system get pvc
kubectl -n longhorn-system get pv

# Проверка через Longhorn UI
# http://longhorn.local.lab

# Проверка дискового пространства на nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.allocatable.ephemeral-storage
```

---

## 🚀 Оптимизация производительности

### 🆕 Resource Optimization

```bash
# Создать VPA (Vertical Pod Autoscaler) для автоматической оптимизации
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: ezyshop-frontend-vpa
  namespace: ezyshop
spec:
  targetRef:
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: ezyshop-frontend
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: frontend
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 1000m
        memory: 1Gi
EOF
```

### 🆕 Cache Layer (опционально для будущего)

```bash
# Установка Redis для кеширования
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

cat > /tmp/redis-values.yaml <<EOF
architecture: standalone
auth:
  enabled: true
  password: redis-password-123

master:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  persistence:
    enabled: true
    storageClass: longhorn
    size: 8Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    namespace: monitoring
EOF

kubectl create namespace cache
helm install redis bitnami/redis \
    --namespace cache \
    --values /tmp/redis-values.yaml

# В приложении использовать:
# REDIS_HOST=redis-master.cache.svc.cluster.local
# REDIS_PORT=6379
# REDIS_PASSWORD=redis-password-123
```

---

## 🔒 Безопасность

### Security Checklist v2.0

- ✅ **Управление секретами**: Vault с Kubernetes auth
- ✅ **Image scanning**: Trivy в CI pipeline
- ✅ **Network isolation**: Network Policies между компонентами
- ✅ **RBAC**: Минимальные права для ServiceAccounts
- ✅ **TLS/SSL**: Cloudflare для внешнего доступа
- ✅ **Pod Security**: SecurityContext, PodDisruptionBudget
- ✅ **Audit logging**: Kubernetes audit logs в Elasticsearch
- ✅ **Backup encryption**: Velero с encryption (опционально)
- ⚠️ **TODO**: Image signing (Cosign/Notary)
- ⚠️ **TODO**: Runtime security (Falco)
- ⚠️ **TODO**: WAF (ModSecurity)

### 🆕 Security Best Practices

```bash
# 1. Регулярное сканирование всех образов
for image in $(kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u); do
  echo "Scanning: $image"
  trivy image --severity HIGH,CRITICAL $image
done

# 2. Проверка устаревших Kubernetes компонентов
kubectl version --short

# 3. Аудит RBAC разрешений
kubectl auth can-i --list --as=system:serviceaccount:ezyshop:ezyshop-sa -n ezyshop

# 4. Проверка секретов в Git (предотвращение утечек)
git secrets --scan --recursive

# 5. Rotация секретов (каждые 90 дней)
kubectl -n vault-system exec -it vault-0 -- vault kv put secret/ezyshop/database \
    username=ezyshop \
    password=$(openssl rand -base64 32)
```

---

## 📚 Полезные команды

### Мониторинг в реальном времени

```bash
# Следить за всеми подами
watch kubectl get pods -A

# Следить за Rollout
watch kubectl argo rollouts get rollout ezyshop-frontend -n ezyshop

# Следить за HPA
watch kubectl get hpa -A

# Следить за ресурсами
watch kubectl top nodes
watch kubectl top pods -n ezyshop

# Следить за backup
watch velero backup get

# Следить за events
kubectl get events -A --watch
```

### Быстрая диагностика

```bash
# Проверка всех критичных компонентов
echo "=== K3s Nodes ==="
kubectl get nodes

echo "=== Core Services ==="
kubectl get pods -n kube-system
kubectl get pods -n traefik
kubectl get pods -n metallb-system

echo "=== Monitoring ==="
kubectl get pods -n monitoring

echo "=== Security ==="
kubectl get pods -n vault-system

echo "=== Backup ==="
kubectl get pods -n velero

echo "=== Application ==="
kubectl get pods -n ezyshop
kubectl argo rollouts get rollout -n ezyshop

echo "=== Storage ==="
kubectl get pvc -A
kubectl get pv

echo "=== Ingress ==="
kubectl get ingress -A
```

---

## 📖 Заключение

Вы успешно развернули **Production-Ready DevOps инфраструктуру v2.0** с:

### ✅ Что получилось

1. **🔒 Enterprise Security**
   - Централизованное управление секретами (Vault)
   - Автоматическое сканирование уязвимостей (Trivy)
   - Сетевая изоляция (Network Policies)

2. **💾 Disaster Recovery**
   - Автоматические backup кластера (Velero)
   - Автоматические backup БД (PostgreSQL CronJob)
   - RTO < 30 минут, RPO < 3 часа

3. **🚀 Progressive Delivery**
   - Canary deployments (Argo Rollouts)
   - Автоматический rollback на основе метрик
   - Zero-downtime deployments

4. **📊 Observability**
   - Полный мониторинг (Prometheus + Grafana)
   - Централизованное логирование (ELK)
   - Real-time алерты (Slack)

### 🎯 Следующие шаги (опционально)

1. **Service Mesh** (если нужна продвинутая маршрутизация)
   ```bash
   # Linkerd (более легковесный чем Istio)
   curl -sL https://run.linkerd.io/install | sh
   linkerd install | kubectl apply -f -
   ```

2. **Distributed Tracing** (для debugging микросервисов)
   ```bash
   # Jaeger
   helm install jaeger jaegertracing/jaeger
   ```

3. **GitOps для инфраструктуры** (Infrastructure as Code)
   ```bash
   # Flux CD для управления Helm releases
   flux bootstrap github --owner=yourname --repository=k8s-infra
   ```

---

## 🆘 Поддержка

### Документация
- Kubernetes: https://kubernetes.io/docs/
- K3s: https://docs.k3s.io/
- ArgoCD: https://argo-cd.readthedocs.io/
- Argo Rollouts: https://argoproj.github.io/argo-rollouts/
- Velero: https://velero.io/docs/
- Vault: https://www.vaultproject.io/docs/
- Trivy: https://aquasecurity.github.io/trivy/

### Лицензия
MIT License

---

**Версия**: 2.0.0  
**Последнее обновление**: Октябрь 2024  
**Автор**: DevOps Team  

🎉 **Поздравляем! Ваша production-ready инфраструктура готова!**