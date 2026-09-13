server() {
    # ---------------------------------------------------------
    # If docker not working correctly run below cmd in gcp terminal:
    # gcloud compute ssh algo --zone asia-south2-a --command 'sudo usermod -aG docker $USER'
    # ---------------------------------------------------------

    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # ------------------------
    # Install Docker (apt, official Docker repo)
    # ------------------------
    echo "Installing Docker via apt..."
    sudo apt install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable --now docker

    # docker-compose-plugin only registers `docker compose` (space), not the
    # standalone `docker-compose` binary. Shim it so old `docker-compose`
    # invocations (scripts, muscle memory) keep working.
    if ! command -v docker-compose > /dev/null; then
        sudo tee /usr/local/bin/docker-compose > /dev/null <<'EOSH'
#!/bin/sh
exec docker compose "$@"
EOSH
        sudo chmod +x /usr/local/bin/docker-compose
    fi

    # ------------------------
    # Ensure docker group exists & user added
    # ------------------------
    if ! getent group docker > /dev/null; then
        sudo groupadd docker
    fi
    sudo usermod -aG docker $USER

    # ------------------------
    # Apply group change and Test
    # ------------------------
    echo "Applying group permissions and testing..."
    newgrp docker <<EONG
    # Check if we can run docker without sudo
    if docker run hello-world; then
        echo "✅ Docker is working perfectly without sudo!"
    else
        echo "⚠️ Non-sudo access failed, trying with sudo..."
        sudo docker run hello-world
    fi
EONG

    # ------------------------
    # Done
    # ------------------------
    echo "✅ Setup complete!"
    echo "Docker installed, permissions updated, and tested."
    echo "Current Timezone: Asia/Kolkata"
}

server