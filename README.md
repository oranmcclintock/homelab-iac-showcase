# GitOps Homelab Monorepo

> [!NOTE]
> This is a sanitized, public mirror of my active homelab infrastructure, provided as a portfolio piece to demonstrate my SRE and GitOps practices. All secrets and live IPs have been redacted.

<div align="center">

[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![SOPS](https://img.shields.io/badge/SOPS-000000?style=for-the-badge&logo=mozilla&logoColor=white)](https://github.com/getsops/sops)
[![Restic](https://img.shields.io/badge/Restic-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://restic.net/)

*A declarative Kubernetes infrastructure monorepo demonstrating strict GitOps, SOPS secrets management, and automated disaster recovery workflows.*

</div>

---

## Overview

This repository serves as the single source of truth for my personal homelab infrastructure. Built using standard Site Reliability Engineering (SRE) practices, the project provisions bare-metal hardware into a resilient, automated environment.

The codebase has evolved from legacy Docker Compose into a fully-fledged **K3s Kubernetes cluster** managed exclusively via **ArgoCD**. It demonstrates practical implementations of automated provisioning, encrypted secrets management, and programmatic disaster recovery validation.

---

## Architecture

The infrastructure relies on a highly-available Kubernetes architecture for maximum portability and resilience.

- **Hypervisor:** Proxmox VE running hardened Ubuntu Server 24.04 LTS virtual machines.
- **Orchestration:** K3s (Lightweight Kubernetes) cluster.
- **GitOps:** ArgoCD constantly monitors this repository and automatically reconciles the cluster state. No manual `kubectl apply` commands are used.
- **Service Topology:** Over 20 isolated deployments support the environment, including:
  - **Identity & Security:** Vaultwarden, AdGuard Home, Pocket ID
  - **Storage & Media:** Nextcloud, Immich, Jellyfin, *arr stack
  - **VCS & CI/CD:** Gitea
  - **Observability:** Prometheus, Grafana, Glances, Dozzle

---

## Infrastructure as Code (IaC)

Infrastructure state is managed declaratively through a combination of Terraform, Ansible, and Kubernetes manifests.

- **Provisioning:** Ansible playbooks configure base Ubuntu Server VMs, install K3s, configure the Tailscale VPN network, and deploy ArgoCD.
- **Deployment Speed:** Full infrastructure bootstrapping from a fresh install to a functional state takes under 15 minutes.
- **Idempotency:** Playbooks and Kubernetes manifests are strictly idempotent to prevent configuration drift.

### One-Click VM Provisioning
The homelab features a seamless **Terraform -> Ansible** zero-touch deployment workflow:
1. Terraform (`bpg/proxmox` provider) spins up a fresh Ubuntu 24.04 VM. The Terraform state is securely stored remotely in the Kubernetes cluster.
2. `cloud-init` automatically installs Tailscale and joins the Tailnet.
3. Once authenticated to Tailscale, `cloud-init` triggers the GitHub Actions deployment workflow.
4. The deployment workflow resolves the new VM via Tailscale MagicDNS and automatically bootstraps all encrypted SOPS secrets and K3s configurations without any manual intervention.

---

## Secrets Management

To adhere to GitOps principles, absolutely no plaintext secrets are stored in version control.

- **Encryption:** Secrets (including Terraform variables and Kubernetes application passwords) are encrypted at rest using Mozilla SOPS and Age asymmetric cryptography.
- **Decryption Workflow:** During Ansible deployments, `.sops.yml` files are decrypted securely.
- **Injection:** Decrypted variables are injected directly into Kubernetes Secrets, preventing credentials from being exposed in plaintext manifests or written to the host filesystem.

---

## Disaster Recovery

The disaster recovery strategy automates database dumps and deduplicated backups.

- **Pre-Backup Hooks:** Before any backups run, a `kubectl exec` routine natively connects to active PostgreSQL and MariaDB pods (Nextcloud, Immich, Gitea) to safely generate clean `.sql` dumps, preventing database corruption.
- **Storage:** Application state and SQL dumps are encrypted client-side and deduplicated using Restic before being pushed to Cloudflare R2 object storage.
- **Targeted Backups:** Restic explicitly backs up only critical data directories and the generated `.sql` dumps, intentionally excluding massive, replaceable media libraries.
- **Retention Policies:** Automated daily, weekly, and monthly pruning policies manage storage capacity and provide point-in-time recovery options.
- **Fail-Safes:** Restoration pipelines are built with strict failure constraints, ensuring silent data loss cannot occur if storage goes offline.

---

## Networking and Routing

The network is structured around isolation, GitOps-managed DNS, and VPN egress.

- **Ingress & Reverse Proxy:** Traefik natively integrates with Kubernetes via `IngressRoute` CRDs to manage internal DNS routing and SSL/TLS certificate termination (via Cloudflare DNS challenges).
- **DNS Blocking:** AdGuard Home provides local network-wide ad-blocking and custom DNS rewriting for `.example.com` routing.
- **Egress Routing:** Specific media stacks are isolated from the host network. Their egress traffic is routed through Gluetun (Wireguard) VPN containers to maintain privacy and prevent IP leakage.

---

<div align="center">
  <b>Maintained by Oran McClintock. </b>
</div>
