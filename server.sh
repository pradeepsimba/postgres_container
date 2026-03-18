server() {
    # ---------------------------------------------------------
    # If docker not working correctly run below cmd in gcp terminal:
    # gcloud compute ssh algo --zone asia-south2-a --command 'sudo usermod -aG docker $USER'
    # ---------------------------------------------------------

    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Ensure snapd is installed and active
    sudo apt install -y snapd
    sudo systemctl enable --now snapd.socket

    # ------------------------
    # Install Docker (Snap)
    # ------------------------
    echo "Installing Docker via Snap..."
    sudo snap install docker
    
    # Connect snap interfaces for home directory access
    sudo snap connect docker:dot-docker

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