server() {
    echo "--- Starting System Setup ---"

    # ---------------------------------------------------------
    # 1. PERMISSION CHECK & AUTO-FIX
    # ---------------------------------------------------------
    if ! sudo -v &> /dev/null; then
        echo "⚠️  Sudo access denied. Attempting to fix permissions..."
        
        # This adds the current user to the necessary groups
        # Note: On GCP, if this fails, you MUST run the gcloud command below.
        sudo usermod -aG sudo,docker $USER 2>/dev/null || {
            echo "❌ Critical Error: user '$USER' is not in the sudoers file."
            echo "Please run this command in your GOOGLE CLOUD SHELL to fix this:"
            echo ""
            echo "  gcloud compute ssh algo --zone=asia-south2-a --command='sudo usermod -aG sudo,docker \$USER'"
            echo ""
            return 1
        }
    fi

    # ---------------------------------------------------------
    # 2. SYSTEM UPDATES
    # ---------------------------------------------------------
    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Ensure snapd is installed
    sudo apt install -y snapd
    sudo systemctl enable --now snapd.socket

    # ---------------------------------------------------------
    # 3. DOCKER INSTALLATION (SNAP)
    # ---------------------------------------------------------
    echo "Installing Docker via Snap..."
    sudo snap install docker
    sudo snap connect docker:dot-docker

    # Ensure docker group exists (Snap usually creates it, but let's be safe)
    if ! getent group docker > /dev/null; then
        sudo groupadd docker
    fi
    sudo usermod -aG docker $USER

    # ---------------------------------------------------------
    # 4. ENVIRONMENT REFRESH & TEST
    # ---------------------------------------------------------
    echo "Refreshing group permissions and testing Docker..."
    
    # Using 'sg' (execute as group) is more reliable inside scripts than 'newgrp'
    sg docker -c "
        if docker run --rm hello-world; then
            echo '✅ Docker is working perfectly!'
        else
            echo '⚠️  Docker test failed. Trying with sudo...'
            sudo docker run --rm hello-world
        fi
    "

    echo "------------------------------------------------"
    echo "✅ Setup complete! Timezone: Asia/Kolkata"
    echo "If 'docker' commands still fail, please re-log (exit and ssh back in)."
    echo "------------------------------------------------"
}

server