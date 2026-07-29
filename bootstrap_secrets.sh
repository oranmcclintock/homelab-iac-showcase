#!/bin/bash

# Ensure we exit on any failure
set -e

# Path to the encrypted secrets file
SECRETS_FILE="ansible/group_vars/all/secrets.sops.yml"

# Ensure the Age key is available so SOPS can decrypt/encrypt seamlessly
if [ -z "$SOPS_AGE_KEY" ]; then
    if [ ! -f ~/.config/sops/age/keys.txt ]; then
        echo "❌ Error: SOPS Age Key is missing. Provide SOPS_AGE_KEY env var or create ~/.config/sops/age/keys.txt."
        exit 1
    fi
    export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
fi

echo "🔒 Scanning $SECRETS_FILE for placeholder secrets..."

# Decrypt the file in memory and check if our Wireguard placeholder exists
if sops -d "$SECRETS_FILE" | grep -q 'cGFzc3dvcmRwYXNzd29yZHBhc3N3b3JkcGFzc3dvcmQ='; then
    echo "⚠️  Missing Secret Detected: Mullvad Wireguard Private Key"
    
    wg_key="${ENV_WG_PRIVATE_KEY:-}"
    if [ -z "$wg_key" ]; then
        if [ -t 0 ]; then
            read -s -p "Enter your Mullvad Wireguard Private Key: " wg_key
            echo ""
        else
            echo "❌ Error: ENV_WG_PRIVATE_KEY is missing for headless mode."
            exit 1
        fi
    fi
    
    if [ -n "$wg_key" ]; then
        echo "Encrypting and injecting Wireguard key into SOPS..."
        # Use sops --set to inject the key without breaking the file structure or MAC hashes
        sops --set "[\"media_stack_wireguard_private_key\"] \"$wg_key\"" "$SECRETS_FILE"
    fi
else
    echo "✅ Mullvad Wireguard Private Key is already set."
fi

# Decrypt the file in memory and check if Restic password placeholder or empty string exists
# Alternatively, check if restic_password is missing or set to placeholder.
# If it's missing or empty, generate one.
if sops -d "$SECRETS_FILE" | grep -q 'restic_password: ""' || ! sops -d "$SECRETS_FILE" | grep -q 'restic_password'; then
    echo "Generating secure Restic Backup Password..."
    restic_pass=$(openssl rand -base64 32)
    sops --set "[\"restic_password\"] \"$restic_pass\"" "$SECRETS_FILE"
    echo "✅ Restic Password: Automatically generated and injected"
else
    echo "✅ Restic Password is already set."
fi

echo ""
echo "=============================================="
echo "✅ SECRETS BOOTSTRAP COMPLETE"
echo "=============================================="
echo ""

# Decrypt the file in memory and check if Restic AWS credentials exist
if ! sops -d "$SECRETS_FILE" | grep -q 'restic_aws_access_key_id'; then
    echo "⚠️  Missing Secret Detected: AWS Access Key ID for Restic S3"
    
    aws_id="${ENV_AWS_ACCESS_KEY_ID:-}"
    if [ -z "$aws_id" ] && [ -t 0 ]; then read -p "Enter your AWS Access Key ID (or B2 Key ID): " aws_id; fi
    if [ -n "$aws_id" ]; then
        sops --set "[\"restic_aws_access_key_id\"] \"$aws_id\"" "$SECRETS_FILE"
    else
        echo "❌ Error: ENV_AWS_ACCESS_KEY_ID is missing."
        exit 1
    fi
    
    aws_secret="${ENV_AWS_SECRET_ACCESS_KEY:-}"
    if [ -z "$aws_secret" ] && [ -t 0 ]; then read -s -p "Enter your AWS Secret Access Key: " aws_secret; echo ""; fi
    if [ -n "$aws_secret" ]; then
        sops --set "[\"restic_aws_secret_access_key\"] \"$aws_secret\"" "$SECRETS_FILE"
    else
        echo "❌ Error: ENV_AWS_SECRET_ACCESS_KEY is missing."
        exit 1
    fi
    
    s3_repo="${ENV_RESTIC_S3_REPO:-}"
    if [ -z "$s3_repo" ] && [ -t 0 ]; then read -p "Enter your S3 Repository URL: " s3_repo; fi
    if [ -n "$s3_repo" ]; then
        sops --set "[\"restic_s3_repo\"] \"$s3_repo\"" "$SECRETS_FILE"
    else
        echo "❌ Error: ENV_RESTIC_S3_REPO is missing."
        exit 1
    fi
    echo "✅ S3 Credentials have been securely injected!"
else
    echo "✅ Restic S3 Credentials are already set."
fi


# Decrypt the file in memory and check if Cloudflare placeholder exists
if sops -d "$SECRETS_FILE" | grep -q 'CHANGEME_CLOUDFLARE_API_TOKEN'; then
    echo "⚠️  Missing Secret Detected: Cloudflare API Token"
    
    cf_token="${ENV_CLOUDFLARE_API_TOKEN:-}"
    if [ -z "$cf_token" ]; then
        if [ -t 0 ]; then
            read -s -p "Enter your Cloudflare API Token (Edit Zone DNS permissions): " cf_token
            echo ""
        else
            echo "❌ Error: ENV_CLOUDFLARE_API_TOKEN is missing for headless mode."
            exit 1
        fi
    fi
    
    if [ -n "$cf_token" ]; then
        echo "Encrypting and injecting token into SOPS..."
        # Use sops --set to inject the token without breaking the file structure or MAC hashes
        sops --set "[\"cloudflare_api_token\"] \"$cf_token\"" "$SECRETS_FILE"
        echo "✅ Successfully securely injected 'cloudflare_api_token'!"
    else
        echo "❌ No token entered, skipping."
    fi
else
    echo "✅ Cloudflare API Token is already set."
fi

echo "✅ All secrets have been processed!"
