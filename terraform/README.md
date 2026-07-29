# Proxmox Homelab GitOps Node: Terraform Usage Guide

This directory contains the Infrastructure as Code (IaC) configuration necessary to automatically spin up a Proxmox Virtual Machine pre-configured to receive the homelab Ansible GitOps deployment.

## Overview

The Terraform code will:
1. Download the latest Ubuntu 22.04 Cloud Image natively to your Proxmox server.
2. Spin up a VM with your specified hardware resources and network bridge.
3. Automatically configure the OS via Cloud-Init on first boot:
   - Perform full package updates/upgrades.
   - Create your secure user account (`sweeny`) with a hashed password and inject your public SSH keys.
   - Install and enable the `qemu-guest-agent`.
   - Install Tailscale and autonomously authenticate to your Tailnet.
   - Fire a webhook to GitHub via a Personal Access Token (PAT) to trigger the Ansible deployment pipeline automatically.

## Prerequisites

Before running this configuration, you need the following:
1. **Terraform** installed on your local workstation.
2. **Proxmox API Token:** An API token generated in Proxmox (`Datacenter -> Permissions -> API Tokens`). The user should have the necessary permissions to create VMs and download files.
3. **Tailscale Pre-Auth Key:** A reusable, ephemeral Tailscale auth key (generated in your Tailscale Admin Console).
4. **GitHub PAT:** A classic Personal Access Token with the `repo` scope to trigger GitHub Action workflows.
5. **Hashed Password:** A SHA-512 hashed password for the `sweeny` user to allow standard sudo usage.

## Step-by-Step Setup

### Step 1: Configure Your Environment

1. Navigate into this directory:
   ```bash
   cd terraform
   ```

2. Create your active variables file from the provided example:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Generate a secure hashed password for the `sweeny` user. You can do this on a Linux machine using the `mkpasswd` utility:
   ```bash
   mkpasswd -m sha-512
   ```

4. Edit `terraform.tfvars` and populate it with your specific secrets, IP addresses, and resource requirements:
   - Proxmox API Endpoint and Token
   - VM ID, Cores, Memory, and Disk Size
   - Static IP, Gateway, and Network Bridge (`vmbr0`)
   - Your public SSH Key (`~/.ssh/id_ed25519.pub`)
   - The hashed password from step 3
   - Tailscale Auth Key and GitHub PAT

### Step 2: Initialize & Validate

Initialize the Terraform providers and validate the syntax:

```bash
terraform init
terraform fmt
terraform validate
```

### Step 3: Plan the Deployment

Generate and review the execution plan to verify what resources will be created on your Proxmox server:

```bash
terraform plan
```

Ensure the output successfully shows the creation of the cloud image file, the cloud-init snippet, and the `homelab-docker-node` virtual machine.

### Step 4: Execute the Build

Apply the configuration. This is the "One-Click" step that will execute the entire provisioning and bootstrapping process:

```bash
terraform apply -auto-approve
```

## What Happens Next?

Once the `terraform apply` finishes successfully:
- The VM boots up in Proxmox and runs the Cloud-Init script.
- Tailscale is configured, joining the node securely to your private network.
- The Cloud-Init script makes a POST request to the GitHub API, triggering the `deploy.yml` workflow in your `homelab-monorepo`.
- GitHub Actions runners connect to the VM via Tailscale and run your Ansible playbooks, deploying your entire Docker Compose stack securely using your vaulted `ansible_become_pass`.
