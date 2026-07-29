# Homelab Monorepo: State and Deployment Guide

This document captures the current state of the entire `homelab-monorepo` repository, the major enhancements completed by the SRE team, and the next steps required to deploy and maintain the cluster.

---

## Current Architecture State

The homelab has been migrated from a legacy **Docker Compose** structure to a fully declarative **K3s Kubernetes** cluster managed via **ArgoCD GitOps**.

```
                           [ Cloudflare Ingress Route ]
                                        │
                                        ▼
                             [ Traefik Ingress (K3s) ]
                                 ┌──────┴──────┐
                                 ▼             ▼
                           [ App Pods ]   [ Databases ]
                                 │             │
                    (Daily SQL Dumps)          │ (Restic Excludes Raw DB Paths)
                                 ▼             ▼
                       [ DB Dumps Directory ] [ PVC Storage ]
                                 │             │
                                 └──────┬──────┘
                                        ▼
                              [ Restic Backup (R2) ]
```

---

## What Has Been Completed (Monorepo Overhaul)

### 1. Terraform Security & State Protection
* **Secret Encryption:** Plaintext credentials in `terraform.tfvars` have been replaced with a SOPS-encrypted file (`terraform.sops.tfvars`) containing Proxmox tokens, Tailscale auth keys, and GitHub PATs.
* **State Backend Migration:** The remote Terraform state backend has been migrated from a local file to a secure **Kubernetes Secret** backend running inside the K3s cluster.

### 2. Disaster Recovery & Restic Overhaul
* **Dumping Live Databases:** To prevent Restic from backing up live database files (which guaranteed corruption), the backup playbook (`ansible/backup.yml`) now runs `kubectl exec` to dump clean `.sql` files for **Nextcloud**, **Immich**, **Gitea**, and **Oneill Art** into `/opt/backup/db_dumps`. Restic target paths have been updated to back up only these dumps.
* **Restore Reliability:** Removed `ignore_errors: yes` from the restore scripts in `ansible/deploy.yml` and `ansible/restore.yml`. If a restore fails, the pipeline will immediately halt rather than silently deploying empty applications.

### 3. Kubernetes Applications Configuration
* **Glances Monitoring:** Updated `k8s/apps/monitoring/glances-deployment.yaml` to include `hostNetwork: true` and `hostPID: true` so that Glances can monitor host metrics instead of container sandboxed stats.
* **Cleaned Monorepo:** Deleted the legacy `compose/` directory and deprecated setup scripts. All configurations are native K8s manifests under `k8s/apps/`.

---

## Future Roadmap

The following initiatives are planned for future iterations of the homelab:

### 1. High Availability Expansion
* Add additional physical nodes to the K3s cluster to support node-level failover.
* Implement Longhorn or Ceph for distributed, highly-available persistent storage across all nodes.

### 2. Enhanced Observability
* Integrate OpenTelemetry for distributed tracing across custom microservices.
* Establish automated alerting via Alertmanager to notify on critical infrastructure degradation.

### 3. Automated Security Scanning
* Implement continuous image scanning using Trivy to detect vulnerabilities in container deployments.
* Automate SOPS key rotation policies.
