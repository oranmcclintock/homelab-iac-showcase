variable "proxmox_endpoint" {
  type        = string
  description = "The Proxmox API endpoint (e.g. https://192.168.x.x:8006/)"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "The Proxmox API token (format: USER@REALM!TOKENID=UUID)"
}

variable "vm_id" {
  type        = number
  description = "The ID for the Proxmox VM"
  default     = 150
}

variable "vm_name" {
  type        = string
  description = "The name of the VM"
  default     = "homelab-docker-node"
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 8
}

variable "vm_memory" {
  type        = number
  description = "Amount of RAM in MB"
  default     = 16384
}

variable "vm_disk_size" {
  type        = number
  description = "Disk size in GB"
  default     = 200
}

variable "vm_ip_address" {
  type        = string
  description = "IP address with CIDR (e.g. 192.168.x.x/24)"
}

variable "vm_gateway" {
  type        = string
  description = "Gateway IP address (e.g. 192.168.x.x)"
}

variable "vm_bridge" {
  description = "The Proxmox bridge to attach the network interface to"
  type        = string
  default     = "vmbr0"
}



variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for the sweeny user"
}

variable "sweeny_password_hash" {
  type        = string
  description = "Hashed password for the sweeny user (required for sudo). Generate with: mkpasswd -m sha-512"
  sensitive   = true
}

variable "tailscale_authkey" {
  type        = string
  sensitive   = true
  description = "Reusable Tailscale auth key"
}

variable "github_pat" {
  type        = string
  sensitive   = true
  description = "GitHub PAT to trigger workflows"
}
