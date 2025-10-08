# EasyShop DevOps Infrastructure - Complete Setup Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup](#infrastructure-setup)
3. [DNS Configuration](#dns-configuration)
4. [Jumphost Setup](#jumphost-setup)
5. [MinIO Setup](#minio-setup)
6. [K3s Cluster Deployment](#k3s-cluster-deployment)
7. [Jenkins Installation](#jenkins-installation)
8. [Kubernetes Components](#kubernetes-components)
9. [Application Deployment](#application-deployment)
10. [Verification](#verification)

## Prerequisites

### Hardware Requirements
- Proxmox VE server
- Minimum resources:
  - 20+ CPU cores
  - 40+ GB RAM
  - 500+ GB SSD storage
  - 2 network interfaces

### Software Requirements
- Proxmox VE 8.x
- Ubuntu 22.04 cloud-init template
- GitHub account
- DockerHub account

### Network Requirements
- Management network: 10.0.10.0/24
- Internal network: 192.168.100.0/24

## Infrastructure Setup

### Step 1: Prepare Proxmox

```bash
# On Proxmox host
# Create network bridges if not exist
pvesh create /nodes/{node}/network --iface vmbr0 --type bridge --bridge_ports ens18
pvesh create /nodes/{node}/network --iface vmbr1 --type bridge --bridge_ports ens19

# Download Ubuntu cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Create template VM
qm create 9000 --name ubuntu-2204-template --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

### Step 2: Create VMs (Manual or Terraform)

#### Option A: Manual Creation

```bash
# Clone template for each VM
qm clone 9000 200 --name dns-server --full
qm clone 9000 201 --name jumphost --full
qm clone 9000 202 --name k3s-master --full
qm clone 9000 203 --name k3s-worker-1 --full
qm clone 9000 204 --name k3s-worker-2 --full
qm clone 9000 205 --name jenkins --full
qm clone 9000 206 --name minio --full

# Resize disks
qm resize 202 scsi0 +100G  # k3s-master
qm resize 203 scsi0 +50G   # k3s-worker-1
qm resize 204 scsi0 +50G   # k3s-worker-2
qm resize 205 scsi0 +50G   # jenkins
qm resize 206 scsi0 +200G  # minio

# Configure cloud-init
qm set 200 --ciuser admin --cipassword yourpassword --ipconfig0 ip=10.0.10.53/24,gw=10.0.10.1
qm set 201 --ciuser admin --cipassword yourpassword --ipconfig0 ip=10.0.10.102/24,gw=10.0.10.1
# ... repeat for all VMs

# Start VMs
qm start 200 && qm start 201 && qm start 202 && qm start 203 && qm start 204 && qm start 205 && qm start 206
```

## DNS Configuration

### Step 1: Install Dnsmasq

```bash
ssh admin@10.0.10.53

sudo apt update
sudo apt install -y dnsmasq
```

### Step 2: Configure Dnsmasq

```bash
sudo tee /etc/dnsmasq.d/easyshop.conf <<EOF
# Local domain
domain=local.dev
local=/local.dev/

# A-records for services
address=/easyshop.local.dev/192.168.100.10
address=/jenkins.local.dev/192.168.100.101
address=/argocd.local.dev/192.168.100.10
address=/grafana.local.dev/192.168.100.10
address=/prometheus.local.dev/192.168.100.10
address=/alertmanager.local.dev/192.168.100.10
address=/kibana.local.dev/192.168.100.10
address=/minio.local.dev/192.168.100.20
address=/minio-console.local.dev/192.168.100.20

# Upstream DNS
server=8.8.8.8
server=1.1.1.1
EOF

# Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# Verify
dig @localhost easyshop.local.dev
```

### Step 3: Configure DNS on All VMs

```bash
# On each VM, set DNS
echo "nameserver 10.0.10.53" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf  # Make immutable
```

## Jumphost Setup

### Step 1: Configure Network

```bash
ssh admin@10.0.10.102

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Configure NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

### Step 2: Install Tools

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install git
sudo apt install -y git
```

### Step 3: Configure HAProxy

```bash
sudo apt install -y haproxy

sudo tee /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# EasyShop App
frontend easyshop_frontend
    bind *:80
    acl is_easyshop hdr(host) -i easyshop.local.dev
    use_backend easyshop_backend if is_easyshop

backend easyshop_backend
    balance roundrobin
    server k3s-master 192.168.100.10:30080 check

# Jenkins
frontend jenkins_frontend
    bind *:8080
    default_backend jenkins_backend

backend jenkins_backend
    server jenkins 192.168.100.101:8080 check

# ArgoCD
frontend argocd_frontend
    bind *:8081
    acl is_argocd hdr(host) -i argocd.local.dev
    use_backend argocd_backend if is_argocd

backend argocd_backend
    server k3s-master 192.168.100.10:30081 check

# Grafana
frontend grafana_frontend
    bind *:3001
    acl is_grafana hdr(host) -i grafana.local.dev
    use_backend grafana_backend if is_grafana

backend grafana_backend
    server k3s-master 192.168.100.10:30030 check

# Prometheus
frontend prometheus_frontend
    bind *:9090
    acl is_prometheus hdr(host) -i prometheus.local.dev
    use_backend prometheus_backend if is_prometheus

backend prometheus_backend
    server k3s-master 192.168.100.10:30090 check

# Alertmanager
frontend alertmanager_frontend
    bind *:9093
    acl is_alertmanager hdr(host) -i alertmanager.local.dev
    use_backend alertmanager_backend if is_alertmanager

backend alertmanager_backend
    server k3s-master 192.168.100.10:30093 check

# Kibana
frontend kibana_frontend
    bind *:5601
    acl is_kibana hdr(host) -i kibana.local.dev
    use_backend kibana_backend if is_kibana

backend kibana_backend
    server k3s-master 192.168.100.10:30056 check

# MinIO API
frontend minio_frontend
    bind *:9000
    acl is_minio hdr(host) -i minio.local.dev
    use_backend minio_backend if is_minio

backend minio_backend
    server minio 192.168.100.20:9000 check

# MinIO Console
frontend minio_console_frontend
    bind *:9001
    acl is_minio_console hdr(host) -i minio-console.local.dev
    use_backend minio_console_backend if is_minio_console

backend minio_console_backend
    server minio 192.168.100.20:9001 check

# Stats page
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
EOF

# Verify and restart
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo systemctl enable haproxy
```

## MinIO Setup

### Step 1: Prepare Storage

```bash
ssh -J admin@10.0.10.102 admin@192.168.100.20

# Format additional disk (if you have one)
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/minio-data
echo '/dev/sdb /mnt/minio-data ext4 defaults 0 0' | sudo tee -a /etc/fstab
sudo mount -a
```

### Step 2: Install MinIO

```bash
# Download MinIO
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Create user and set permissions
sudo useradd -r minio-user -s /sbin/nologin
sudo chown minio-user:minio-user /mnt/minio-data
```

### Step 3: Create SystemD Service

```bash
sudo tee /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin123"
Environment="MINIO_SERVER_URL=http://minio.local.dev:9000"
Environment="MINIO_BROWSER_REDIRECT_URL=http://minio-console.local.dev:9001"
ExecStart=/usr/local/bin/minio server /mnt/minio-data --console-address ":9001"
Restart=always
LimitNOFILE=65536
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
```

### Step 4: Configure MinIO Client

```bash
# Install mc
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure alias
mc alias set local http://localhost:9000 minioadmin minioadmin123

# Create buckets
mc mb local/jenkins-artifacts
mc policy set download local/jenkins-artifacts

mc mb local/velero-backups
```

## K3s Cluster Deployment

### Step 1: Install K3s Master

```bash
ssh -J admin@10.0.10.102 admin@192.168.100.10

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --node-name k3s-master \
  --cluster-cidr=10.42.0.0/16 \
  --service-cidr=10.43.0.0/16" sh -

# Wait for K3s to be ready
sudo systemctl status k3s

# Get node token
sudo cat /var/lib/rancher/k3s/server/node-token
# Save this token for workers!
```

### Step 2: Install K3s Workers

```bash
# On k3s-worker-1
ssh -J admin@10.0.10.102 admin@192.168.100.11

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.100.10:6443 \
  K3S_TOKEN="<TOKEN_FROM_MASTER>" \
  INSTALL_K3S_EXEC="agent --node-name k3s-worker-1" sh -

# On k3s-worker-2
ssh -J admin@10.0.10.102 admin@192.168.100.12

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.100.10:6443 \
  K3S_TOKEN="<TOKEN_FROM_MASTER>" \
  INSTALL_K3S_EXEC="agent --node-name k3s-worker-2" sh -
```

### Step 3: Configure kubectl Access

```bash
# On jumphost
mkdir -p ~/.kube
ssh admin@192.168.100.10 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
sed -i 's/127.0.0.1/192.168.100.10/g' ~/.kube/config

# Verify
kubectl get nodes -o wide
```

## Jenkins Installation

### Step 1: Install Prerequisites

```bash
ssh -J admin@10.0.10.102 admin@192.168.100.101

# Install Java
sudo apt update
sudo apt install -y openjdk-17-jdk
```

### Step 2: Install Jenkins

```bash
# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins
```

### Step 3: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker jenkins

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Restart Jenkins
sudo systemctl restart jenkins
```

### Step 4: Install Additional Tools

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install -y trivy
```

### Step 5: Configure Jenkins

```bash
# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Jenkins UI Configuration:**

1. Open http://jenkins.local.dev:8080
2. Enter initial admin password
3. Install suggested plugins
4. Install additional plugins:
   - Docker Pipeline
   - Kubernetes CLI
   - Git Parameter
   - SSH Agent
   - Pipeline Utility Steps

5. Create admin user

### Step 6: Configure Credentials

**In Jenkins UI:**

Navigate to: Dashboard → Manage Jenkins → Credentials → (global) → Add Credentials

**GitHub Credentials:**
- Kind: Username with password
- ID: `github-credentials`
- Username: `<your-github-username>`
- Password: `<github-personal-access-token>`

**DockerHub Credentials:**
- Kind: Username with password
- ID: `docker-hub-credentials`
- Username: `<your-dockerhub-username>`
- Password: `<dockerhub-password>`

**Kubeconfig:**
- Kind: Secret file
- ID: `k3s-kubeconfig`
- File: Upload `~/.kube/config` from jumphost

### Step 7: Configure Shared Library

**In Jenkins UI:**

Dashboard → Manage Jenkins → System → Global Pipeline Libraries

- Name: `Shared`
- Default version: `main`
- ☑ Load implicitly
- ☑ Allow default version to be overridden
- Retrieval method: Modern SCM
- Source Code Management: Git
- Project Repository: `https://github.com/YOUR_USERNAME/jenkins-shared-libraries`

## Kubernetes Components

### Step 1: Install NGINX Ingress Controller

```bash
# From jumphost
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create namespace ingress-nginx

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --set controller.hostNetwork=true \
  --set controller.kind=DaemonSet

# Verify
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Step 2: Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for insecure TLS
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait and verify
sleep 30
kubectl top nodes
```

### Step 3: Install ArgoCD

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

cat > argocd-values.yaml <<EOF
global:
  domain: argocd.local.dev

configs:
  params:
    server.insecure: true

server:
  service:
    type: NodePort
    nodePortHttp: 30081
    nodePortHttps: 30444
  
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

redis:
  enabled: true

controller:
  replicas: 1

repoServer:
  replicas: 1

applicationSet:
  enabled: false
EOF

helm install argocd argo/argo-cd -n argocd -f argocd-values.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

### Step 4: Install Monitoring Stack

```bash
kubectl create namespace monitoring

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat > prometheus-values.yaml <<EOF
prometheus:
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
  
  service:
    type: NodePort
    nodePort: 30090
  
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    hosts:
      - prometheus.local.dev
    paths:
      - /

grafana:
  adminPassword: admin123
  
  service:
    type: NodePort
    nodePort: 30030
  
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
    storageClassName: local-path
    size: 10Gi

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
  
  service:
    type: NodePort
    nodePort: 30093
  
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    hosts:
      - alertmanager.local.dev
    paths:
      - /

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true
EOF

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f prometheus-values.yaml

# Verify
kubectl get pods -n monitoring
```

### Step 5: Install Logging Stack

```bash
kubectl create namespace logging

helm repo add elastic https://helm.elastic.co
helm repo update

# Elasticsearch
cat > elasticsearch-values.yaml <<EOF
replicas: 1
minimumMasterNodes: 1
clusterHealthCheckParams: "wait_for_status=yellow&timeout=10s"

resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

volumeClaimTemplate:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 30Gi

service:
  type: ClusterIP
EOF

helm install elasticsearch elastic/elasticsearch -n logging -f elasticsearch-values.yaml

# Wait for Elasticsearch
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=600s

# Kibana
cat > kibana-values.yaml <<EOF
service:
  type: NodePort
  nodePort: 30056

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: kibana.local.dev
      paths:
        - path: /
          pathType: Prefix

elasticsearchHosts: "http://elasticsearch-master:9200"

resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"
EOF

helm install kibana elastic/kibana -n logging -f kibana-values.yaml

# Filebeat
cat > filebeat-values.yaml <<EOF
daemonset:
  enabled: true
  
filebeatConfig:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*easyshop*.log
      processors:
        - add_kubernetes_metadata:
            host: \${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
    
    output.elasticsearch:
      hosts: ['http://elasticsearch-master:9200']
      index: "filebeat-easyshop-%{+yyyy.MM.dd}"
    
    setup.ilm.enabled: false
    setup.template.name: "filebeat-easyshop"
    setup.template.pattern: "filebeat-easyshop-*"

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "200m"
    memory: "256Mi"
EOF

helm install filebeat elastic/filebeat -n logging -f filebeat-values.yaml
```

## Application Deployment

### Step 1: Prepare Repository

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/tws-e-commerce-app_hackathon.git
cd tws-e-commerce-app_hackathon
```

### Step 2: Create Kubernetes Manifests

Create directory structure:
```bash
mkdir -p kubernetes/app
```

Create the following files in `kubernetes/app/`:

**namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: easyshop
```

**secrets.yaml:**
```bash
kubectl create namespace easyshop

kubectl create secret generic mongodb-credentials \
  --from-literal=username=admin \
  --from-literal=password=password123 \
  --from-literal=database=easyshop \
  -n easyshop

kubectl create secret generic easyshop-secrets \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --from-literal=nextauth-secret=$(openssl rand -base64 32) \
  -n easyshop

kubectl create configmap easyshop-config \
  --from-literal=NEXTAUTH_URL=http://easyshop.local.dev \
  --from-literal=NODE_ENV=production \
  -n easyshop
```

### Step 3: Deploy Application

```bash
# Apply all manifests
kubectl apply -f kubernetes/app/

# Watch deployment
kubectl get pods -n easyshop -w
```

### Step 4: Create Jenkins Pipeline

In Jenkins UI:
1. New Item → Pipeline
2. Name: `easyshop-pipeline`
3. Configure:
   - GitHub project: `https://github.com/YOUR_USERNAME/tws-e-commerce-app_hackathon`
   - Poll SCM: `H/5 * * * *`
   - Pipeline from SCM
   - Repository URL: `https://github.com/YOUR_USERNAME/tws-e-commerce-app_hackathon`
   - Credentials: `github-credentials`
   - Branch: `*/master`
   - Script Path: `Jenkinsfile`

### Step 5: Create ArgoCD Application

```bash
argocd app create easyshop \
  --repo https://github.com/YOUR_USERNAME/tws-e-commerce-app_hackathon \
  --path kubernetes/app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace easyshop \
  --sync-policy automated \
  --auto-prune \
  --self-heal

argocd app sync easyshop
```

## Verification

### Step 1: Check All Services

```bash
# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A
```

### Step 2: Access Services

Open in browser:
- EasyShop: http://easyshop.local.dev
- Jenkins: http://jenkins.local.dev:8080
- ArgoCD: http://argocd.local.dev
- Grafana: http://grafana.local.dev
- Prometheus: http://prometheus.local.dev
- Kibana: http://kibana.local.dev
- MinIO: http://minio-console.local.dev:9001

### Step 3: Run Health Check

```bash
# Create health check script
cat > health-check.sh <<'SCRIPT'
#!/bin/bash
echo "=== Kubernetes Health Check ==="
kubectl get nodes
kubectl get pods -n easyshop
kubectl get svc -n easyshop
kubectl top nodes
kubectl top pods -n easyshop
SCRIPT

chmod +x health-check.sh
./health-check.sh
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n easyshop
kubectl logs <pod-name> -n easyshop
```

### DNS issues
```bash
dig @10.0.10.53 easyshop.local.dev
kubectl run -it --rm debug --image=busybox -- nslookup easyshop.local.dev
```

### Ingress issues
```bash
kubectl get ingress -A
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Next Steps

1. Configure monitoring dashboards in Grafana
2. Set up alerts in Alertmanager
3. Create backup schedules
4. Implement security policies
5. Set up CI/CD automation

Congratulations! Your EasyShop DevOps infrastructure is now ready! 🎉
