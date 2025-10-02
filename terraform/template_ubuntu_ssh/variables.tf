variable "proxmox_ssh_host" {
  description = "Proxmox host IP"
  type        = string
}

variable "proxmox_ssh_username" {
  description = "Имя пользователя ssh Proxmox"
  type        = string
}

variable "proxmox_api_url" {
  description = "URL API Proxmox"
  type        = string
}

variable "proxmox_username" {
  description = "Имя пользователя Proxmox"
  type        = string
}

variable "proxmox_password" {
  description = "Пароль пользователя Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Имя узла Proxmox"
  type        = string
}

variable "storage_ssd" {
  description = "ID хранилища SSD для дисков VM"
  type        = string
  default     = "local-lvm"
}

variable "storage_hdd" {
  description = "ID хранилища для образов и snippets"
  type        = string
  default     = "local"
}

variable "cloud_image_url" {
  description = "URL cloud image для загрузки"
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "template_vm_id" {
  description = "ID для шаблона VM"
  type        = number
  default     = 9000
}

variable "admin_user" {
  description = "Пользователь администратор"
  type        = string  
}

variable "admin_password" {
  description = "Пароль администратора (будет установлен и для root)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH ключу"
  type        = string
  default     = "id_rsa.pub"
}