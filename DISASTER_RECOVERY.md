# Parkanore Disaster Recovery Guide

> **Architecture:** GitOps (Ansible) + SOPS (Age) + Cloud Object Storage (Cloudflare R2)

This document outlines the exact procedure to recover the `parkanore` bare-metal node or hypervisor VM in the event of a catastrophic hardware failure or migration.

## 1. Hypervisor / Bare-Metal Prep
1. Install Proxmox VE (or Ubuntu Server 24.04 LTS if running bare-metal) on the new hardware.
2. If using Proxmox, spin up a new Ubuntu Server 24.04 VM.
3. Ensure the VM/Node is accessible via SSH and assign it a static IP address (e.g., `192.168.x.x`).
4. Update `live_inventory.ini` in this repository to reflect the new IP address if it has changed.

## 2. Zero-Touch State Restoration (Restic -> R2)
This phase pulls the encrypted Cloudflare API keys via SOPS, connects to the `parkanore` bucket, and restores the ~7GB core configuration state (databases, configs, metrics).

Instead of running this manually, you can orchestrate this directly from GitHub:
1. Navigate to the **Actions** tab in this repository.
2. Select the **Disaster Recovery Restore** workflow.
3. Click **Run workflow**. You may optionally specify a Restic Snapshot ID to restore from a specific point in time (defaults to `latest`).

This workflow securely connects to the VM over Tailscale and executes `ansible/restore.yml`, which cleanly stops all containers, restores the state, and restarts the environment.

## 3. Infrastructure Deployment
If you provisioned a completely new VM, the standard infrastructure deployment will automatically be triggered by Terraform. If you need to manually trigger a redeployment, run the **Deploy Homelab GitOps** workflow from the GitHub Actions UI.

## 4. Bulk Media Restoration
Because the Cloudflare R2 backup explicitly excludes massive media directories via the Whitelist architecture, you must manually restore the bulk media.

1. Attach the external USB hard drive or network mount containing the ~300GB media backup to the `parkanore` node.
2. Copy the respective media directories back into `/opt/appdata`:
   ```bash
   sudo rsync -ahP /mnt/usb/immich_server/library/ /opt/appdata/immich_server/library/
   sudo rsync -ahP /mnt/usb/nextcloud/data/ /opt/appdata/nextcloud/data/
   sudo rsync -ahP /mnt/usb/media-stack/data/ /opt/appdata/media-stack/data/
   ```
3. Restart the media containers to register the newly mounted files:
   ```bash
   sudo k3s kubectl rollout restart deployment/immich-server -n default
   sudo k3s kubectl rollout restart deployment/nextcloud -n default
   sudo k3s kubectl rollout restart deployment/qbittorrent -n default
   sudo k3s kubectl rollout restart deployment/radarr -n default
   sudo k3s kubectl rollout restart deployment/sonarr -n default
   sudo k3s kubectl rollout restart deployment/jellyfin -n default
   ```

## 5. Verification
Verify the system is fully operational by executing the internal QA check (or running it locally against the live IP):
```bash
# Verify Traefik routing
curl -H "Host: vaultwarden.example.com" http://<parkanore-ip>:80
```
Expect an HTTP `200 OK` or `302 Found`. Recovery is complete.
