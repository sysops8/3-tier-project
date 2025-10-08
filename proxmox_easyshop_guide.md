# EasyShop DevOps на Proxmox - Полная инструкция

## 📋 Оглавление
1. [Архитектура решения](#архитектура-решения)
2. [Подготовка инфраструктуры](#подготовка-инфраструктуры)
3. [Настройка DNS и сетевого доступа](#настройка-dns-и-сетевого-доступа)
4. [Развертывание K3s кластера](#развертывание-k3s-кластера)
5. [Настройка Jenkins](#настройка-jenkins)
6. [Настройка MinIO](#настройка-minio)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Развертывание ArgoCD](#развертывание-argocd)
9. [Мониторинг (Prometheus + Grafana)](#мониторинг)
10. [Логирование (EFK Stack)](#логирование)
11. [Проверка работоспособности](#проверка-работоспособности)

---

## 🏗️ Архитектура решения

### Инфраструктура
```
┌─────────────────────────────────────────────────────────┐
│                    PROXMOX СЕРВЕР                        │
├─────────────────────────────────────────────────────────┤
│  Network: vmbr0 (10.0.10.0/24) - External/Management    │
│  Network: vmbr1 (192.168.100.0/24) - Internal/Cluster   │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  DNS Server  │  │  CF-Tunnel   │  │ Ngrok-Tunnel │  │
│  │  10.0.10.53  │  │  10.0.10.50  │  │  10.0.10.60  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │            K3s Kubernetes Cluster                 │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐ │   │
│  │  │ k3s-master │  │ k3s-worker │  │ k3s-worker │ │   │
│  │  │   .100.10  │  │   .100.11  │  │   .100.12  │ │   │
│  │  └────────────┘  └────────────┘  └────────────┘ │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Jenkins    │  │    MinIO     │  │   Jumphost   │  │
│  │  .100.101    │  │   .100.20    │  │  10.0.10.102 │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Компоненты
- **DNS Server**: Локальный DNS для разрешения доменов (*.local.dev)
- **Ngrok Tunnel**: Webhook для GitHub → Jenkins
- **Cloudflare Tunnel**: Внешний доступ к приложению (опционально)
- **K3s Cluster**: Легковесный Kubernetes (1 master + 2 worker)
- **Jenkins**: CI/CD сервер
- **MinIO**: S3-совместимое хранилище для артефактов
- **Jumphost**: Bastion host для управления

---

## 🚀 Подготовка инфраструктуры

### 1. Предварительные требования

#### На вашей рабочей машине:
```bash
# Установка Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Проверка
terraform -v
```

#### Создание SSH ключа:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/proxmox-vms -N ""
```

### 2. Подготовка Proxmox шаблона

На Proxmox хосте создайте базовый Ubuntu 22.04 шаблон:

```bash
# Скачать Ubuntu Cloud Image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Создать VM
qm create 9000 --name ubuntu-22.04-template --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# Конвертировать в шаблон
qm template 9000
```

### 3. Настройка Terraform переменных

Создайте файл `terraform.tfvars`:

```hcl
proxmox_api_url      = "https://10.0.10.1:8006"
proxmox_username     = "root@pam"
proxmox_password     = "your-password"
proxmox_node         = "pve"
template_vm_id       = 9000
storage_ssd          = "local-lvm"
storage_hdd          = "local"
admin_user           = "ubuntu"
admin_password       = "ubuntu"
ssh_public_key_path  = "~/.ssh/proxmox-vms.pub"
```

Создайте файл `variables.tf`:

```hcl
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "template_vm_id" {
  description = "Template VM ID"
  type        = number
}

variable "storage_ssd" {
  description = "SSD storage name"
  type        = string
}

variable "storage_hdd" {
  description = "HDD storage name"
  type        = string
}

variable "admin_user" {
  description = "Admin username"
  type        = string
}

variable "admin_password" {
  description = "Admin password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
}
```

### 4. Развертывание инфраструктуры

```bash
# Инициализация Terraform
terraform init

# Проверка плана
terraform plan

# Применение конфигурации
terraform apply -auto-approve

# Сохранение IP адресов
terraform output -json > infrastructure.json
```

---

## 🌐 Настройка DNS и сетевого доступа

### 1. Настройка DNS сервера (dns-server VM)

```bash
# Подключение к DNS серверу
ssh -i ~/.ssh/proxmox-vms ubuntu@10.0.10.53

# Установка Bind9
sudo apt update
sudo apt install -y bind9 bind9utils bind9-doc

# Конфигурация зоны
sudo nano /etc/bind/named.conf.local
```

Добавьте:
```
zone "local.dev" {
    type master;
    file "/etc/bind/db.local.dev";
};

zone "100.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.100";
};
```

Создайте файл зоны:
```bash
sudo nano /etc/bind/db.local.dev
```

```
$TTL    604800
@       IN      SOA     ns.local.dev. admin.local.dev. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.local.dev.
ns      IN      A       10.0.10.53

; K3s Cluster
k3s-master      IN      A       192.168.100.10
k3s-worker-1    IN      A       192.168.100.11
k3s-worker-2    IN      A       192.168.100.12

; Services
jenkins         IN      A       192.168.100.101
minio           IN      A       192.168.100.20
jumphost        IN      A       192.168.100.5

; Application endpoints (будут указывать на Ingress)
easyshop        IN      A       192.168.100.10
argocd          IN      A       192.168.100.10
grafana         IN      A       192.168.100.10
prometheus      IN      A       192.168.100.10
alertmanager    IN      A       192.168.100.10
kibana          IN      A       192.168.100.10

; Wildcard для приложений
*.apps          IN      A       192.168.100.10
```

```bash
# Проверка конфигурации
sudo named-checkconf
sudo named-checkzone local.dev /etc/bind/db.local.dev

# Перезапуск DNS
sudo systemctl restart bind9
sudo systemctl enable bind9
```

### 2. Настройка Ngrok для Jenkins Webhooks

```bash
# Подключение к ngrok-tunnel VM
ssh -i ~/.ssh/proxmox-vms ubuntu@10.0.10.60

# Установка Ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list && \
  sudo apt update && sudo apt install ngrok

# Авторизация (получите токен на https://dashboard.ngrok.com)
ngrok config add-authtoken YOUR_NGROK_TOKEN

# Создание systemd сервиса
sudo nano /etc/systemd/system/ngrok.service
```

```ini
[Unit]
Description=Ngrok Tunnel
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/bin/ngrok http 192.168.100.101:8080 --log=stdout
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable ngrok
sudo systemctl start ngrok

# Получить публичный URL
curl http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'
# Сохраните этот URL - он понадобится для GitHub webhook
```

### 3. Настройка DNS на вашей рабочей машине

```bash
# Linux
sudo nano /etc/resolv.conf
```
Добавьте в начало:
```
nameserver 10.0.10.53
```

Или через NetworkManager:
```bash
nmcli connection modify "ваше-подключение" ipv4.dns "10.0.10.53"
nmcli connection up "ваше-подключение"
```

---

## ☸️ Развертывание K3s кластера

### 1. Установка K3s Master

```bash
# Подключение к jumphost
ssh -i ~/.ssh/proxmox-vms ubuntu@10.0.10.102

# Затем к master ноде
ssh ubuntu@192.168.100.10

# Установка K3s без Traefik (будем использовать Nginx Ingress)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --cluster-cidr=10.42.0.0/16 \
  --service-cidr=10.43.0.0/16 \
  --write-kubeconfig-mode=644 \
  --node-name=k3s-master" sh -

# Получение токена для worker нод
sudo cat /var/lib/rancher/k3s/server/node-token
# Сохраните этот токен!

# Копирование kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config
```

### 2. Подключение Worker нод

На каждой worker ноде (k3s-worker-1 и k3s-worker-2):

```bash
# Worker 1
ssh ubuntu@192.168.100.11

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.100.10:6443 \
  K3S_TOKEN="ваш-токен-из-master" \
  INSTALL_K3S_EXEC="agent --node-name=k3s-worker-1" sh -

# Worker 2
ssh ubuntu@192.168.100.12

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.100.10:6443 \
  K3S_TOKEN="ваш-токен-из-master" \
  INSTALL_K3S_EXEC="agent --node-name=k3s-worker-2" sh -
```

### 3. Проверка кластера

На master ноде:
```bash
kubectl get nodes
# Должны увидеть 3 ноды в статусе Ready

kubectl get pods -A
```

### 4. Установка MetalLB (LoadBalancer для bare-metal)

```bash
# На master ноде
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

# Дождитесь готовности подов
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# Создание IP пула
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.100.200-192.168.100.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
```

### 5. Установка Nginx Ingress Controller

```bash
# Установка через Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=192.168.100.200

# Проверка
kubectl get svc -n ingress-nginx
# Должны увидеть External-IP: 192.168.100.200
```

### 6. Настройка Local Path Provisioner (для PVC)

```bash
# K3s уже включает local-path-provisioner
kubectl get storageclass
# Должен быть local-path (default)

# Если нужно, можно настроить дополнительное хранилище
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-data
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /mnt/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k3s-worker-1
          - k3s-worker-2
EOF
```

---

## 🔧 Настройка Jenkins

### 1. Установка Jenkins на VM

```bash
# Подключение к Jenkins VM
ssh ubuntu@192.168.100.101

# Установка Java
sudo apt update
sudo apt install -y openjdk-17-jdk

# Установка Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Установка kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Получение начального пароля
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 2. Настройка Jenkins через Web UI

Откройте в браузере: `http://jenkins.local.dev:8080`

1. Введите начальный пароль
2. Установите рекомендуемые плагины
3. Создайте admin пользователя

### 3. Установка дополнительных плагинов

Перейдите: **Manage Jenkins → Plugins → Available Plugins**

Установите:
- Docker Pipeline
- Kubernetes
- Kubernetes CLI
- Git Parameter
- Pipeline: Stage View
- Blue Ocean

### 4. Настройка credentials

**Manage Jenkins → Credentials → (global) → Add Credentials**

#### GitHub credentials:
- **Kind**: Username with password
- **ID**: `github-credentials`
- **Username**: ваш GitHub username
- **Password**: Personal Access Token (создайте на GitHub)

#### DockerHub credentials:
- **Kind**: Username with password
- **ID**: `docker-hub-credentials`
- **Username**: ваш DockerHub username
- **Password**: ваш DockerHub password

#### Kubeconfig:
```bash
# На jumphost скопируйте kubeconfig с master ноды
scp ubuntu@192.168.100.10:~/.kube/config ./k3s-kubeconfig
```

В Jenkins:
- **Kind**: Secret file
- **ID**: `kubeconfig`
- **File**: загрузите k3s-kubeconfig

### 5. Настройка Jenkins Shared Library

**Manage Jenkins → System → Global Pipeline Libraries**

- **Name**: `Shared`
- **Default version**: `main`
- **Retrieval method**: Modern SCM
- **Source Code Management**: Git
- **Project Repository**: форкните и используйте свой репозиторий

---

## 📦 Настройка MinIO

### 1. Установка MinIO

```bash
# Подключение к MinIO VM
ssh ubuntu@192.168.100.20

# Создание директории для данных
sudo mkdir -p /mnt/data/minio
sudo chown -R ubuntu:ubuntu /mnt/data

# Скачивание MinIO
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Создание systemd сервиса
sudo nano /etc/systemd/system/minio.service
```

```ini
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local

User=ubuntu
Group=ubuntu

Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin123"
Environment="MINIO_VOLUMES=/mnt/data/minio"
Environment="MINIO_OPTS=--console-address :9001"

ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio

# Проверка статуса
sudo systemctl status minio
```

### 2. Настройка MinIO через Web UI

Откройте: `http://192.168.100.20:9001`

- **Username**: minioadmin
- **Password**: minioadmin123

Создайте bucket: `jenkins-artifacts`

### 3. Установка MinIO Client (mc)

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Настройка alias
mc alias set local http://192.168.100.20:9000 minioadmin minioadmin123

# Проверка
mc ls local
```

---

## 🔄 CI/CD Pipeline

### 1. Подготовка репозиториев

#### Форк основного репозитория:
```bash
# Склонируйте ваш форк
git clone https://github.com/YOUR_USERNAME/tws-e-commerce-app.git
cd tws-e-commerce-app
```

#### Создание Jenkinsfile для локальной среды:

Создайте файл `Jenkinsfile`:

```groovy
@Library('Shared') _

pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = "YOUR_DOCKERHUB_USERNAME"
        IMAGE_NAME = "easyshop"
        KUBECONFIG_CREDENTIAL_ID = 'kubeconfig'
        GIT_REPO = "https://github.com/YOUR_USERNAME/tws-e-commerce-app.git"
    }
    
    stages {
        stage('Cleanup') {
            steps {
                cleanWs()
            }
        }
        
        stage('Checkout') {
            steps {
                git branch: 'master',
                    credentialsId: 'github-credentials',
                    url: "${GIT_REPO}"
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'docker-hub-credentials') {
                        def image = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}")
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }
        
        stage('Update Kubernetes Manifests') {
            steps {
                script {
                    update_k8s_manifest(
                        repo: "${GIT_REPO}",
                        branch: 'master',
                        manifestPath: 'kubernetes/deployment.yaml',
                        imageName: "${DOCKER_REGISTRY}/${IMAGE_NAME}",
                        imageTag: "${BUILD_NUMBER}"
                    )
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
```

### 2. Создание Kubernetes манифестов

Создайте директорию `kubernetes/` в вашем репозитории:

```bash
mkdir -p kubernetes
```

#### Namespace:
```yaml
# kubernetes/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: easyshop
```

#### MongoDB Deployment:
```yaml
# kubernetes/mongodb.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: easyshop
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: easyshop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:6.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "admin"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "password123"
        - name: MONGO_INITDB_DATABASE
          value: "easyshop"
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
      volumes:
      - name: mongodb-storage
        persistentVolumeClaim:
          claimName: mongodb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: easyshop
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
  type: ClusterIP
```

#### EasyShop Application:
```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: easyshop
  namespace: easyshop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: easyshop
  template:
    metadata:
      labels:
        app: easyshop
    spec:
      containers:
      - name: easyshop
        image: YOUR_DOCKERHUB_USERNAME/easyshop:latest
        ports:
        - containerPort: 3000
        env:
        - name: MONGODB_URI
          value: "mongodb://admin:password123@mongodb:27017/easyshop?authSource=admin"
        - name: JWT_SECRET
          value: "your-secret-key-change-in-production"
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: easyshop
  namespace: easyshop
spec:
  selector:
    app: easyshop
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
```

#### Ingress:
```yaml
# kubernetes/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: easyshop-ingress
  namespace: easyshop
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: easyshop.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: easyshop
            port:
              number: 80
```

### 3. Настройка GitHub Webhook

1. Перейдите в Settings вашего репозитория на GitHub
2. Webhooks → Add webhook
3. **Payload URL**: `http://YOUR_NGROK_URL/github-webhook/`
4. **Content type**: `application/json`
5. **Events**: Just the push event
6. **Active**: ✓

### 4. Создание Jenkins Pipeline Job

В Jenkins:
1. **New Item** → Введите имя `easyshop-pipeline` → **Pipeline** → OK
2. **General**:
   - ✓ GitHub project: `https://github.com/YOUR_USERNAME/tws-e-commerce-app`
3. **Build Triggers**:
   - ✓ GitHub hook trigger for GITScm polling
4. **Pipeline**:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/YOUR_USERNAME/tws-e-commerce-app`
   - **Credentials**: github-credentials
   - **Branch**: */master
   - **Script Path**: Jenkinsfile
5. **Save**

### 5. Тестирование Pipeline

```bash
# Сделайте изменение в коде
echo "// test change" >> src/app/page.tsx

# Закоммитьте и запушьте
git add .
git commit -m "test: trigger pipeline"
git push origin master

# Pipeline должен автоматически запуститься в Jenkins
```

---

## 🚀 Развертывание ArgoCD

### 1. Установка ArgoCD

```bash
# На master ноде через jumphost
ssh ubuntu@192.168.100.10

# Создание namespace
kubectl create namespace argocd

# Установка ArgoCD через Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Получение values файла
helm show values argo/argo-cd > argocd-values.yaml

# Редактирование values
nano argocd-values.yaml
```

Измените следующие параметры в `argocd-values.yaml`:

```yaml
global:
  domain: argocd.local.dev

configs:
  params:
    server.insecure: true  # Для работы за Nginx Ingress

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    hosts:
      - argocd.local.dev
    paths:
      - /
    pathType: Prefix
```

```bash
# Установка ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd-values.yaml

# Ожидание готовности подов
kubectl wait --for=condition=ready pod \
  --all -n argocd \
  --timeout=300s

# Получение начального пароля
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo  # Новая строка
```

### 2. Доступ к ArgoCD UI

Откройте браузер: `http://argocd.local.dev`

- **Username**: admin
- **Password**: (пароль из предыдущего шага)

После входа смените пароль:
- User Info → Update Password

### 3. Настройка ArgoCD CLI (опционально)

```bash
# Установка ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Логин через CLI
argocd login argocd.local.dev \
  --username admin \
  --password YOUR_PASSWORD \
  --insecure

# Изменение пароля через CLI
argocd account update-password
```

### 4. Создание Application в ArgoCD

#### Через UI:

1. Нажмите **+ NEW APP**
2. Заполните параметры:
   - **Application Name**: easyshop
   - **Project**: default
   - **Sync Policy**: Automatic
   - **Self Heal**: ✓ (enabled)
   - **Prune Resources**: ✓ (enabled)
   
3. **Source**:
   - **Repository URL**: `https://github.com/YOUR_USERNAME/tws-e-commerce-app`
   - **Revision**: master
   - **Path**: kubernetes

4. **Destination**:
   - **Cluster URL**: https://kubernetes.default.svc
   - **Namespace**: easyshop

5. Нажмите **CREATE**

#### Через манифест:

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: easyshop
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/tws-e-commerce-app
    targetRevision: master
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: easyshop
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

```bash
kubectl apply -f argocd-application.yaml
```

### 5. Проверка синхронизации

```bash
# Статус приложения
argocd app get easyshop

# Список всех приложений
argocd app list

# Логи синхронизации
argocd app logs easyshop

# Принудительная синхронизация
argocd app sync easyshop
```

---

## 📊 Мониторинг (Prometheus + Grafana)

### 1. Установка kube-prometheus-stack

```bash
# На master ноде
kubectl create namespace monitoring

# Добавление репозитория
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Получение values
helm show values prometheus-community/kube-prometheus-stack > prometheus-stack-values.yaml
```

### 2. Настройка values файла

Отредактируйте `prometheus-stack-values.yaml`:

```yaml
# Grafana настройки
grafana:
  adminPassword: admin123  # Смените на свой
  
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    hosts:
      - grafana.local.dev
    path: /

  persistence:
    enabled: true
    size: 10Gi
    storageClassName: local-path

# Prometheus настройки
prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
  
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    hosts:
      - prometheus.local.dev
    paths:
      - /
    pathType: Prefix

# AlertManager настройки
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
  
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    hosts:
      - alertmanager.local.dev
    paths:
      - /
    pathType: Prefix

  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['namespace', 'alertname']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'default'
      routes:
      - receiver: 'critical'
        matchers:
          - severity =~ "critical|warning"
    
    receivers:
    - name: 'default'
      webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true
    
    - name: 'critical'
      webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true

# Включение ServiceMonitors для приложений
prometheus-node-exporter:
  enabled: true

kube-state-metrics:
  enabled: true
```

### 3. Установка стека

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-stack-values.yaml

# Проверка установки
kubectl get pods -n monitoring

# Ожидание готовности
kubectl wait --for=condition=ready pod \
  --all -n monitoring \
  --timeout=600s
```

### 4. Настройка Slack уведомлений (опционально)

Если хотите получать алерты в Slack:

1. Создайте Slack workspace и канал (например, #alerts)
2. Создайте Incoming Webhook: https://api.slack.com/apps
3. Обновите AlertManager конфигурацию:

```yaml
alertmanager:
  config:
    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        send_resolved: true
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

```bash
# Обновление
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-stack-values.yaml
```

### 5. Доступ к сервисам мониторинга

- **Grafana**: http://grafana.local.dev (admin / admin123)
- **Prometheus**: http://prometheus.local.dev
- **AlertManager**: http://alertmanager.local.dev

### 6. Импорт дашбордов в Grafana

В Grafana UI:
1. **Dashboards → Import**
2. Введите ID популярных дашбордов:
   - **3119**: Kubernetes cluster monitoring
   - **13639**: Kubernetes / Views / Global
   - **15757**: Kubernetes / Views / Namespaces
   - **1860**: Node Exporter Full
   - **15760**: Kubernetes / Views / Pods

### 7. Создание кастомного ServiceMonitor для EasyShop

```yaml
# kubernetes/servicemonitor.yaml
apiVersion: v1
kind: Service
metadata:
  name: easyshop-metrics
  namespace: easyshop
  labels:
    app: easyshop
spec:
  selector:
    app: easyshop
  ports:
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: easyshop
  namespace: easyshop
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: easyshop
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

```bash
kubectl apply -f kubernetes/servicemonitor.yaml
```

### 8. Установка Metrics Server

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]="--kubelet-insecure-tls"

# Проверка
kubectl top nodes
kubectl top pods -A
```

---

## 📝 Логирование (EFK Stack)

### 1. Создание namespace

```bash
kubectl create namespace logging
```

### 2. Установка Elasticsearch

```bash
# Добавление репозитория
helm repo add elastic https://helm.elastic.co
helm repo update

# Получение values
helm show values elastic/elasticsearch > elasticsearch-values.yaml
```

Отредактируйте `elasticsearch-values.yaml`:

```yaml
replicas: 1
minimumMasterNodes: 1

clusterHealthCheckParams: "wait_for_status=yellow&timeout=1s"

# Ресурсы
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "1000m"
    memory: "4Gi"

# Хранилище
volumeClaimTemplate:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: "local-path"
  resources:
    requests:
      storage: 30Gi

# Отключение X-Pack security для упрощения
protocol: http
```

```bash
# Установка
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values elasticsearch-values.yaml

# Проверка
kubectl get pods -n logging
kubectl logs -n logging elasticsearch-master-0 -f
```

### 3. Установка Filebeat

```bash
helm show values elastic/filebeat > filebeat-values.yaml
```

Отредактируйте `filebeat-values.yaml`:

```yaml
filebeatConfig:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
      - add_kubernetes_metadata:
          host: ${NODE_NAME}
          matchers:
          - logs_path:
              logs_path: "/var/log/containers/"
      # Фильтр только для приложения easyshop
      - drop_event:
          when:
            not:
              contains:
                kubernetes.namespace: "easyshop"

    output.elasticsearch:
      host: '${NODE_NAME}'
      hosts: '["http://elasticsearch-master:9200"]'
      indices:
        - index: "filebeat-easyshop-%{+yyyy.MM.dd}"
          when.contains:
            kubernetes.namespace: "easyshop"

    setup.kibana:
      host: "http://kibana-kibana:5601"

# Ресурсы
resources:
  requests:
    cpu: "100m"
    memory: "200Mi"
  limits:
    cpu: "200m"
    memory: "400Mi"
```

```bash
helm install filebeat elastic/filebeat \
  --namespace logging \
  --values filebeat-values.yaml

# Проверка (должен быть DaemonSet на каждой ноде)
kubectl get pods -n logging | grep filebeat
```

### 4. Установка Kibana

```bash
helm show values elastic/kibana > kibana-values.yaml
```

Отредактируйте `kibana-values.yaml`:

```yaml
elasticsearchHosts: "http://elasticsearch-master:9200"

# Ресурсы
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# Ingress
ingress:
  enabled: true
  className: nginx
  pathtype: Prefix
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: kibana.local.dev
      paths:
        - path: /
```

```bash
helm install kibana elastic/kibana \
  --namespace logging \
  --values kibana-values.yaml

# Проверка
kubectl get pods -n logging
```

### 5. Настройка Kibana

Откройте: http://kibana.local.dev

1. **Discover** → **Create index pattern**
2. **Index pattern name**: `filebeat-easyshop-*`
3. **Time field**: `@timestamp`
4. **Create index pattern**

Теперь вы можете просматривать логи приложения EasyShop!

### 6. Получение пароля Elasticsearch (если включен X-Pack)

Если вы используете Elasticsearch с security:

```bash
kubectl get secrets --namespace=logging elasticsearch-master-credentials \
  -ojsonpath='{.data.password}' | base64 -d
echo
```

---

## ✅ Проверка работоспособности

### 1. Проверка всех компонентов

```bash
# Проверка нод кластера
kubectl get nodes

# Проверка всех подов
kubectl get pods -A

# Проверка сервисов
kubectl get svc -A

# Проверка Ingress
kubectl get ingress -A
```

### 2. Проверка приложения EasyShop

```bash
# Статус в namespace easyshop
kubectl get all -n easyshop

# Логи приложения
kubectl logs -n easyshop -l app=easyshop --tail=50

# Логи MongoDB
kubectl logs -n easyshop -l app=mongodb --tail=50

# Описание пода (для проблем)
kubectl describe pod -n easyshop -l app=easyshop
```

### 3. Тестирование доступа к приложению

```bash
# Локально с master ноды
curl http://easyshop.local.dev

# Или откройте в браузере
firefox http://easyshop.local.dev
```

### 4. Проверка ArgoCD синхронизации

```bash
# Статус приложения
argocd app get easyshop

# История синхронизаций
argocd app history easyshop

# Детали последней синхронизации
kubectl get application -n argocd easyshop -o yaml
```

### 5. Проверка мониторинга

Откройте в браузере:
- Grafana: http://grafana.local.dev
- Prometheus: http://prometheus.local.dev  
- AlertManager: http://alertmanager.local.dev

В Grafana проверьте:
- Метрики кластера Kubernetes
- CPU/Memory usage подов EasyShop
- Network traffic

### 6. Проверка логирования

Откройте Kibana: http://kibana.local.dev

1. Перейдите в **Discover**
2. Выберите index pattern: `filebeat-easyshop-*`
3. Вы должны видеть логи контейнеров EasyShop
4. Добавьте фильтры:
   - `kubernetes.namespace: easyshop`
   - `kubernetes.container.name: easyshop`

### 7. Тестирование CI/CD Pipeline

```bash
# В вашем локальном репозитории
cd tws-e-commerce-app

# Внесите изменение
echo "// Pipeline test" >> README.md

# Закоммитьте и запушьте
git add .
git commit -m "test: CI/CD pipeline"
git push origin master

# Проверьте в Jenkins
# http://jenkins.local.dev:8080

# Проверьте в ArgoCD
# http://argocd.local.dev
```

---

## 🔧 Troubleshooting

### Проблемы с DNS

```bash
# На любой VM проверьте разрешение имен
nslookup easyshop.local.dev 10.0.10.53

# Проверка DNS сервера
ssh ubuntu@10.0.10.53
sudo systemctl status bind9
sudo journalctl -u bind9 -f
```

### Проблемы с сетью между нодами

```bash
# Проверка связности
ping 192.168.100.10  # master
ping 192.168.100.11  # worker-1
ping 192.168.100.12  # worker-2

# Проверка firewall
sudo ufw status
```

### Проблемы с подами

```bash
# Под не запускается
kubectl describe pod -n easyshop POD_NAME

# ImagePullBackOff
kubectl get events -n easyshop --sort-by='.lastTimestamp'

# CrashLoopBackOff
kubectl logs -n easyshop POD_NAME --previous
```

### Проблемы с хранилищем

```bash
# Проверка PVC
kubectl get pvc -A

# Проверка PV
kubectl get pv

# Описание PVC
kubectl describe pvc -n easyshop PVC_NAME
```

### Проблемы с Ingress

```bash
# Проверка Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Проверка правил Ingress
kubectl get ingress -A
kubectl describe ingress -n easyshop easyshop-ingress
```

### Проблемы с MetalLB

```bash
# Проверка подов MetalLB
kubectl get pods -n metallb-system

# Проверка конфигурации
kubectl get ipaddresspool -n metallb-system
kubectl describe ipaddresspool -n metallb-system default-pool

# Логи
kubectl logs -n metallb-system -l component=controller
```

### Сброс и переустановка

#### Полная очистка кластера:
```bash
# На каждой worker ноде
sudo /usr/local/bin/k3s-agent-uninstall.sh

# На master ноде
sudo /usr/local/bin/k3s-uninstall.sh

# Затем переустановите K3s заново
```

---

## 📚 Дополнительные улучшения

### 1. Backup решение для MongoDB

```yaml
# kubernetes/mongodb-backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
  namespace: easyshop
spec:
  schedule: "0 2 * * *"  # Каждый день в 2:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mongodb-backup
            image: mongo:6.0
            command:
            - /bin/sh
            - -c
            - |
              mongodump --host=mongodb --port=27017 \
                --username=admin --password=password123 \
                --authenticationDatabase=admin \
                --out=/backup/$(date +%Y%m%d_%H%M%S)
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: mongodb-backup-pvc
          restartPolicy: OnFailure
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-backup-pvc
  namespace: easyshop
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: local-path
```

### 2. Horizontal Pod Autoscaler для EasyShop

```yaml
# kubernetes/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: easyshop-hpa
  namespace: easyshop
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: easyshop
  minReplicas: 2
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
```

### 3. Network Policy для безопасности

```yaml
# kubernetes/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: easyshop-netpol
  namespace: easyshop
spec:
  podSelector:
    matchLabels:
      app: easyshop
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mongodb
    ports:
    - protocol: TCP
      port: 27017
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

---

## 🎉 Заключение

Теперь у вас есть полноценная DevOps инфраструктура для EasyShop приложения на локальном Proxmox сервере:

✅ **Инфраструктура**: Автоматизированное развертывание через Terraform  
✅ **Kubernetes**: K3s кластер с 3 нодами  
✅ **CI/CD**: Jenkins с автоматическими пайплайнами  
✅ **GitOps**: ArgoCD для декларативного деплоя  
✅ **Мониторинг**: Prometheus + Grafana с алертами  
✅ **Логирование**: EFK Stack для централизованных логов  
✅ **Хранилище**: MinIO для артефактов, Local Path для PVC  
✅ **Сеть**: DNS, Ingress, MetalLB LoadBalancer  

### Доступные эндпоинты:
- **EasyShop App**: http://easyshop.local.dev
- **ArgoCD**: http://argocd.local.dev
- **Jenkins**: http://jenkins.local.dev:8080
- **Grafana**: http://grafana.local.dev
- **Prometheus**: http://prometheus.local.dev
- **AlertManager**: http://alertmanager.local.dev
- **Kibana**: http://kibana.local.dev
- **MinIO**: http://192.168.100.20:9001

Этот проект отлично демонстрирует ваши навыки для резюме! 🚀