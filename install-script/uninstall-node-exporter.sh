#!/bin/bash

# Node Exporter Uninstaller Script
# Usage: ./uninstall-node-exporter.sh --method docker|host

set -e

show_help() {
    echo "Node Exporter Uninstaller"
    echo "Usage: $0 [--method <docker|host>]"
    echo ""
    echo "Options:"
    echo "  --method docker    Remove Docker container"
    echo "  --method host      Remove host installation"
    echo "  --help             Show this help message"
    echo ""
    echo "If --method is not specified, the script will try to detect the installation type automatically."
}

uninstall_docker_method() {
    echo "Removing Node Exporter Docker container..."
    docker stop node-exporter 2>/dev/null || true
    docker rm node-exporter 2>/dev/null || true
    echo "Node Exporter Docker container removed successfully!"
}

uninstall_host_method() {
    echo "Removing Node Exporter host installation..."
    sudo systemctl stop node_exporter 2>/dev/null || true
    sudo systemctl disable node_exporter 2>/dev/null || true
    sudo rm -f /etc/systemd/system/node_exporter.service
    sudo rm -f /usr/local/bin/node_exporter
    sudo userdel node_exporter 2>/dev/null || true
    sudo systemctl daemon-reload
    echo "Node Exporter host installation removed successfully!"
}

detect_installation() {
    # Check for Docker container
    if docker ps -a --format '{{.Names}}' | grep -q '^node-exporter$'; then
        echo "docker"
        return
    fi
    # Check for systemd service
    if systemctl list-units --type=service --all | grep -q 'node_exporter.service'; then
        echo "host"
        return
    fi
    # Not found
    echo "none"
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

# Auto-detect installation if not specified
if [[ -z "$METHOD" ]]; then
    echo "No --method parameter specified, detecting installation type..."
    METHOD=$(detect_installation)
    if [[ "$METHOD" == "none" ]]; then
        echo "Could not detect a Node Exporter installation (docker or host)."
        exit 1
    else
        echo "Detected Node Exporter installation type: $METHOD"
    fi
fi

case $METHOD in
    docker)
        uninstall_docker_method
        ;;
    host)
        uninstall_host_method
        ;;
    *)
        echo "Error: Invalid method '$METHOD'. Use 'docker' or 'host'"
        show_help
        exit 1
        ;;
esac

echo "Uninstallation completed successfully!"
