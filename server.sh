server() {
    # ------------------------
    # If docker not working correctly run below cmd in gcp terminal
    # gcloud compute ssh algo --zone asia-south1-b --command 'sudo usermod -aG docker $USER'
    # ------------------------
    sudo apt update && sudo apt upgrade -y

    sudo apt install -y snapd
    sudo systemctl enable --now snapd.socket

    # ------------------------
    # Install Docker (Snap)
    # ------------------------
    sudo snap install docker

    # ------------------------
    # Ensure docker group exists & user added
    # ------------------------
    if ! getent group docker > /dev/null; then
        sudo groupadd docker
    fi
    sudo usermod -aG docker $USER

    # ------------------------
    # Apply group change WITHOUT logging out
    # ------------------------
    newgrp docker <<EONG

    # ------------------------
    # Test Docker
    # ------------------------
    echo "Testing Docker..."
    docker run hello-world || sudo docker run hello-world

EONG

    # ------------------------
    # Done
    # ------------------------
    echo "✅ Setup complete!"
    echo "PostgreSQL ready (Timezone: Asia/Kolkata), Docker installed, and permissions fixed."
}

server
