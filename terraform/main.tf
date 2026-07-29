terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = true
  api_token = var.proxmox_api_token
  ssh {
    agent       = false
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")
  }
}

# Download the Ubuntu 22.04 Cloud Image
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

# Inject the Cloud-Init config
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    data = templatefile("${path.module}/cloud-init.yaml", {
      VM_NAME              = var.vm_name
      TAILSCALE_AUTHKEY    = var.tailscale_authkey
      GITHUB_PAT           = var.github_pat
      SSH_PUBLIC_KEY       = var.ssh_public_key
      SWEENY_PASSWORD_HASH = var.sweeny_password_hash
    })
    file_name = "cloud-config.yaml"
  }
}

# Create the Kubernetes VM
resource "proxmox_virtual_environment_vm" "homelab_k8s_node" {
  name        = var.vm_name
  description = "Managed by Terraform GitOps (K3s Node)"
  node_name   = "pve"
  vm_id       = var.vm_id
  
  agent {
    enabled = true
  }

  cpu {
    cores = var.vm_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = var.vm_disk_size
  }

  network_device {
    bridge = var.vm_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.vm_ip_address
        gateway = var.vm_gateway
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }
}
