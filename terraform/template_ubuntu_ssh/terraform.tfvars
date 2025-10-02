# Подключение к Proxmox
proxmox_api_url  = "https://10.0.10.200:8006/api2/json"
proxmox_username = "terraform@pam"
proxmox_password = "<CHANGE ME>"
proxmox_node     = "pve"

#Подключение по ssh 
proxmox_ssh_host     = "10.0.10.200"
proxmox_ssh_username = "terraform" 

# Хранилища
storage_ssd = "local-ssd-seagate2tb"      # Для дисков виртуальных машин
storage_hdd = "local-hdd-wd2tb"          # Для образов и snippets

# Шаблон
template_vm_id = 9999          # ID шаблона 

# Cloud Image
cloud_image_url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

# Пользователь
admin_user			= "root"				#или admin
admin_password      = "<CHANGE ME>"
ssh_public_key_path = "id_rsa.pub"