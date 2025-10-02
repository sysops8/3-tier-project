terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.83.1"
    }
  }
  required_version = ">= 1.0"
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
}

# 1. ЗАГРУЗКА CLOUD IMAGE
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  overwrite    = true
  datastore_id = var.storage_hdd
  node_name    = var.proxmox_node
  
  source_file {
    path     = var.cloud_image_url
    insecure = true
  }
  
  lifecycle {
    ignore_changes = [source_file]
  }
}

# 2. СОЗДАНИЕ CLOUD-INIT CONFIG
resource "proxmox_virtual_environment_file" "cloud_init_config" {
  content_type = "snippets"
  datastore_id = var.storage_hdd
  node_name    = var.proxmox_node
  
  source_raw {
    data = <<-EOT
#cloud-config
users:
  - default
  - name: admin
    gecos: Admin User
    primary_group: admin
    groups: [sudo, adm]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${file(var.ssh_public_key_path)}
    lock_passwd: false
    passwd: ${var.admin_password}

########ROOT ACCESS FOR SSH, DEL IF PROD############
  - name: root
    ssh_authorized_keys:
      - ${file(var.ssh_public_key_path)}
    lock_passwd: false
####################################################
ssh_pwauth: true
disable_root: false

write_files:
  - path: /etc/issue
    content: |
      ====================================
      Ubuntu Server - Добро пожаловать!
      ====================================
      Хост: \n
      IP: \4{eth0}
      Дата: \d  Время: \t
      ====================================
    permissions: '0644'
    owner: root:root

  - path: /etc/update-motd.d/99-custom-motd
    content: |
      #!/bin/bash
      echo "================================================"
      echo "🚀 Ubuntu Server (Project VM)"
      echo "================================================"
      echo "🖥 Hostname      : $(hostname -f)"
      echo "🌐 IP Address    : $(ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{print $2}')"
      echo "📦 Release       : $(lsb_release -sd 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
      echo "🐧 Kernel        : $(uname -r)"
      echo "👥 Users         : $(who | wc -l) connected"
      echo "🕐 Server Time   : $(date '+%d.%m.%Y %H:%M:%S')"
      echo "⚡ System load   : $(awk '{print $1}' /proc/loadavg)"
      echo "💾 Memory used % : $(free -h | awk '/Mem/{print $3"/"$2}' || echo 'N/A')"
      echo "💽 Swap used %   : $(free -b | awk '/Swap:/ {if ($2>0) printf "%.2f", $3/$2*100; else print 0}')"  
      echo "⏰ System uptime : $(uptime -p | sed 's/up //')"
      echo "💿 Disk /        : $(df -h / | awk 'NR==2{print $3"/"$2 " ("$5")"}' || echo 'N/A')"
      echo "================================================"
    permissions: '0755'
    owner: root:root

  - path: /etc/update-motd.d/10-help-text
    content: |
      #!/bin/sh
      exit 0
    permissions: '0755'
    owner: root:root

package_update: true
package_upgrade: true

# устанавливаем системные программы с родных репо
# в runcmd ставим внешние программы с внешних репо
packages:
  - qemu-guest-agent
  - mc
  - zip
  - jq
  - gnupg2
  - open-iscsi
  - curl
  - wget
  - htop
  - git
  - net-tools
  - sshpass
  - python3
  - python3-pip
  - ansible
  
runcmd:
  - useradd -m -s /bin/bash -G sudo admin || true
  - echo 'admin:${var.admin_password}' | chpasswd
  - echo 'root:${var.admin_password}' | chpasswd
  - sed -i 's/#*PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  - systemctl restart ssh
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - chmod +x /etc/update-motd.d/99-custom-motd
  - chmod +x /etc/update-motd.d/10-help-text
# - apt-get update -y
  - cloud-init clean
  - rm -f /etc/ssh/ssh_host_*
  - ssh-keygen -A
  - rm -f /var/log/cloud-init*.log
  - rm -rf /var/lib/cloud/instances/*
  - truncate -s 0 /etc/machine-id
  - echo -n > /var/lib/dbus/machine-id
EOT
    file_name = "cloud-init-config.yml"
  }
}

# 3. СОЗДАНИЕ ВРЕМЕННОЙ VM
resource "proxmox_virtual_environment_vm" "temp_vm" {
  name        = "ubuntu-temp-setup"
  node_name   = var.proxmox_node
  description = "Temporary VM for template creation"
  vm_id       = var.template_vm_id + 1
  started     = true  # ДОЛЖНА быть запущена для клонирования
  template    = false
  
  scsi_hardware = "virtio-scsi-single"
  machine       = "q35"
  bios          = "seabios"
  
  memory {
    dedicated = 2048
  }
  
  cpu {
    cores   = 2
    sockets = 1
    type    = "x86-64-v2"
  }
  
  disk {
    datastore_id = var.storage_ssd
    file_id      = proxmox_virtual_environment_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 10
    iothread     = true
    discard      = "on"
    ssd          = true
  }
  
  disk {
    datastore_id = var.storage_ssd
    interface    = "ide2"
    size         = 4
  }
  
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  
  initialization {
    datastore_id = var.storage_hdd
    interface    = "ide2"
    
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    
    user_account {
      username = "admin"
      keys     = [file(var.ssh_public_key_path)]
      password = var.admin_password
    }
    
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_config.id
  }
  
  agent {
    enabled = true
    type    = "virtio"
  }
  
  operating_system {
    type = "l26"
  }
  
  serial_device {}
  
 
  
  lifecycle {
    ignore_changes = [started]
  }
}


# 4. СОЗДАНИЕ ШАБЛОНА ИЗ ЗАПУЩЕННОЙ VM
resource "proxmox_virtual_environment_vm" "cloud_init_template" {
  #depends_on = [null_resource.wait_for_cloud_init]
  
  name        = "ubuntu-2204-cloud-template"
  node_name   = var.proxmox_node
  description = "Ubuntu 22.04 Cloud-init Template"
  vm_id       = var.template_vm_id
  started     = false  # Шаблон создаем выключенным
  template    = true   # Это шаблон!
  
  # Клонируем из запущенной VM (провайдер сам ее остановит)
  clone {
    vm_id = proxmox_virtual_environment_vm.temp_vm.vm_id
    full  = true
  }


}

# 6. УДАЛЕНИЕ ВРЕМЕННОЙ VM ПОСЛЕ СОЗДАНИЯ ШАБЛОНА
resource "null_resource" "cleanup_temp_vm" {
  depends_on = [proxmox_virtual_environment_vm.cloud_init_template]
  
  triggers = {
    temp_vm_id = proxmox_virtual_environment_vm.temp_vm.vm_id
  }

  connection {
    type     = "ssh"
    host     = var.proxmox_ssh_host
    user     = var.proxmox_ssh_username
    password = var.proxmox_password
    # если используешь ключ, то:
    # private_key = file("~/.ssh/id_rsa")
    # agent       = true   # <- вот это если хочешь брать ключ из ssh-agent
  }

  provisioner "remote-exec" {
    inline = [
		"sudo qm stop ${self.triggers.temp_vm_id}",
		"sudo qm destroy ${self.triggers.temp_vm_id}",
    ]
  }
}


# OUTPUTS
output "template_id" {
  description = "ID созданного шаблона"
  value       = proxmox_virtual_environment_vm.cloud_init_template.vm_id
}

output "template_name" {
  description = "Имя созданного шаблона"
  value       = proxmox_virtual_environment_vm.cloud_init_template.name
}

output "status" {
  description = "Статус выполнения"
  value       = "Шаблон создан! Временная VM удалена."


}
