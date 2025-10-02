output "vm_ips" {
  description = "IP addresses of all created VMs"
  value = {
    dns_server    = "10.0.10.53, 192.168.100.53"
    cf-tunnel     = "10.0.10.50, 192.168.100.50"
    k3s-master    = "192.168.100.10"
    k3s-worker-1  = "192.168.100.11"
    k3s-worker-2  = "192.168.100.12"
    jenkins       = "192.168.100.101"
    minio         = "192.168.100.20"
    jumphost      = "10.0.10.102, 192.168.100.5"
  }
}

output "vm_ids" {
  description = "VM IDs of all created VMs"
  value = {
    dns_server    = 253
    cf-tunnel     = 250
    k3s-master    = 210
    k3s-worker-1  = 211
    k3s-worker-2  = 212
    jenkins       = 256
    minio         = 220
    jumphost      = 205
  }
}

output "ssh_commands" {
  description = "SSH connection commands"
  value = {
    dns_server    = "ssh admin@10.0.10.53  # или ssh admin@192.168.100.53"
    cf-tunnel     = "ssh admin@10.0.10.50  # или ssh admin@192.168.100.50"
    k3s-master    = "ssh admin@192.168.100.10"
    k3s-worker-1  = "ssh admin@192.168.100.11"
    k3s-worker-2  = "ssh admin@192.168.100.12"
    jenkins       = "ssh admin@192.168.100.101"
    minio         = "ssh admin@192.168.100.20"
    jumphost      = "ssh admin@10.0.10.102  # или ssh admin@192.168.100.5"
  }
}

output "vm_roles" {
  description = "Roles and purposes of all created VMs"
  value = {
    dns_server    = "DNS Server"
    cf-tunnel     = "Tunnel Gateway"
    k3s-master    = "K3s Control Plane"
    k3s-worker-1  = "K3s Worker"
    k3s-worker-2  = "K3s Worker"
    jenkins       = "CI Server"
    minio         = "Object Storage"
    jumphost      = "Management Jump Host"
  }
}

output "network_summary" {
  description = "Network configuration summary"
  value = {
    external_network = "10.0.10.0/24 (vmbr0)"
    internal_network = "192.168.100.0/24 (vmbr1)"
    dual_homed_vms   = "dns-server, cf-tunnel, jumphost"
    internal_only_vms = "k3s-master, k3s-worker-1, k3s-worker-2, jenkins, minio"
  }
}