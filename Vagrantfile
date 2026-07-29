Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "gitops-sandbox"

  # Forward the NPM ports to the host machine for easy testing
  config.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
  config.vm.network "forwarded_port", guest: 443, host: 8443, auto_correct: true

  # Allocate enough resources for the docker-compose stack
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 2
    vb.name = "gitops-sandbox"
  end

  # Mount the current repository into the VM
  config.vm.synced_folder ".", "/home/ubuntu/homelab-monorepo"

  # Pass the SOPS Age key from the Arch laptop host into the sandbox for decryption
  if File.exist?(File.expand_path("~/.config/sops/age/keys.txt"))
    config.vm.provision "file", source: "~/.config/sops/age/keys.txt", destination: "/tmp/keys.txt"
  end

  # Install Ansible, Docker, and run the playbook
  config.vm.provision "setup", type: "shell", inline: <<-SHELL
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y software-properties-common curl ca-certificates gnupg
    apt-get remove -y ansible ansible-core || true
    apt-add-repository --yes --update ppa:ansible/ansible
    apt-get install -y ansible

    # Install SOPS binary
    curl -L -o /usr/local/bin/sops https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
    chmod +x /usr/local/bin/sops

    # Add Docker's official GPG key and repository so ansible can install docker-ce
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
  SHELL
    
  config.vm.provision "ansible", type: "shell", run: "never", inline: <<-SHELL
    # Switch to the repo directory and run the playbook locally
    cd /home/ubuntu/homelab-monorepo
    
    # Ensure galaxy requirements are installed
    ansible-galaxy collection install -r ansible/requirements.yml || true
    
    echo "Running GitOps deployment..."
    echo "homelab ansible_connection=local" > /tmp/inventory.ini
    
    # Export the SOPS key path so the Ansible SOPS plugin can decrypt the vault
    export SOPS_AGE_KEY_FILE=/tmp/keys.txt
    
    echo "Testing Disaster Recovery Restore..."
    ansible-playbook -i /tmp/inventory.ini ansible/restore.yml
    
    echo "Testing GitOps Deployment..."
    ansible-playbook -i /tmp/inventory.ini ansible/deploy.yml -e "adguard_dns_tcp_port=10053" -e "adguard_dns_udp_port=10053"
  SHELL
end
