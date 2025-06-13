#!/bin/bash

# Node Exporter Installer Script
# Usage: ./install-node-exporter.sh --method docker|host

set -e

NODE_EXPORTER_VERSION="latest"
NODE_EXPORTER_PORT="9100"

# Function to get the latest release tag from GitHub
get_latest_release() {
    curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

show_help() {
    echo "Node Exporter Installer"
    echo "Base URL: https://github.com/prometheus/node_exporter"
    echo "Usage: $0 --method <docker|host>"
    echo ""
    echo "Options:"
    echo "  --method docker    Install as Docker container"
    echo "  --method host      Install directly on host system"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --method docker"
    echo "  $0 --method host"
}

# Function to get the main network interface IP
get_main_ip() {
    # Get IP of the default route interface (usually eth0 or main interface)
    ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1
}

install_docker_method() {
    echo "Installing Node Exporter using Docker..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Get main interface IP
    MAIN_IP=$(get_main_ip)
    echo "Detected main interface IP: $MAIN_IP"
    
    # Pull the latest image
    echo "Pulling Node Exporter Docker image..."
    docker pull quay.io/prometheus/node-exporter:${NODE_EXPORTER_VERSION}
    
    # Stop and remove existing container if exists
    docker stop node-exporter 2>/dev/null || true
    docker rm node-exporter 2>/dev/null || true
    
    # Create Docker container
    docker run -d \
        --name node-exporter \
        --restart unless-stopped \
        -p 9100:9100 \
        --pid="host" \
        -v "/:/host:ro,rslave" \
        quay.io/prometheus/node-exporter:${NODE_EXPORTER_VERSION} \
        --path.rootfs=/host
    
    echo "Node Exporter installed as Docker container successfully!"
    echo "Access metrics at: http://${MAIN_IP}:${NODE_EXPORTER_PORT}/metrics"
}

install_host_method() {
    echo "Installing Node Exporter directly on host..."
    
    # Get main interface IP
    MAIN_IP=$(get_main_ip)
    echo "Detected main interface IP: $MAIN_IP"

    # If version is "latest", resolve to actual latest tag
    VERSION="$NODE_EXPORTER_VERSION"
    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release)
        echo "Resolved latest Node Exporter version: $VERSION"
    fi
    
    # Create node_exporter user
    sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
    
    # Download and extract Node Exporter
    cd /tmp
    wget https://github.com/prometheus/node_exporter/releases/download/${VERSION}/node_exporter-${VERSION#v}.linux-amd64.tar.gz
    tar xvf node_exporter-${VERSION#v}.linux-amd64.tar.gz
    
    # Move binary to /usr/local/bin
    sudo cp node_exporter-${VERSION#v}.linux-amd64/node_exporter /usr/local/bin/
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
    
    # Create systemd service file
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${MAIN_IP}:${NODE_EXPORTER_PORT}

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
    
    # Clean up
    rm -rf /tmp/node_exporter-${VERSION#v}.linux-amd64*
    
    echo "Node Exporter installed on host successfully!"
    echo "Service status: $(sudo systemctl is-active node_exporter)"
    echo "Access metrics at: http://${MAIN_IP}:${NODE_EXPORTER_PORT}/metrics"
}

check_installation() {
    echo "Checking Node Exporter installation..."
    
    # Get main interface IP
    MAIN_IP=$(get_main_ip)
    
    # Wait a moment for service to start
    sleep 3
    
    if curl -s http://${MAIN_IP}:${NODE_EXPORTER_PORT}/metrics > /dev/null; then
        echo "✓ Node Exporter is running and accessible on ${MAIN_IP}:${NODE_EXPORTER_PORT}"
        echo "✓ Metrics endpoint: http://${MAIN_IP}:${NODE_EXPORTER_PORT}/metrics"
    else
        echo "✗ Node Exporter is not accessible"
        exit 1
    fi
}

# Parse command line arguments
METHOD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --method)
            METHOD="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default to host method if not specified
if [[ -z "$METHOD" ]]; then
    echo "No --method parameter specified, defaulting to 'host' installation."
    METHOD="host"
fi

case $METHOD in
    docker)
        install_docker_method
        ;;
    host)
        install_host_method
        ;;
    *)
        echo "Error: Invalid method '$METHOD'. Use 'docker' or 'host'"
        show_help
        exit 1
        ;;
esac

check_installation

echo ""
echo "Installation completed successfully!"
echo "You can now configure Prometheus to scrape this Node Exporter instance."
echo "You can now configure Prometheus to scrape this Node Exporter instance."
