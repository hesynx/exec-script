#!/bin/bash

# Database Exporters Uninstaller Script
# Usage: ./db-uninstaller.sh --exporter <redis|mysql|postgres|mongodb> [--method <docker|host>] or --all

set -e

show_help() {
    echo "Database Exporters Uninstaller"
    echo "Usage: $0 [--exporter <redis|mysql|postgres|mongodb>] [--method <docker|host>] [--all]"
    echo ""
    echo "Options:"
    echo "  --exporter <type>      Database exporter type (redis|mysql|postgres|mongodb)"
    echo "  --method <method>      Installation method (docker|host|both) - auto-detect if not specified"
    echo "  --all                  Uninstall all database exporters"
    echo "  --force                Force removal without confirmation"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --exporter redis                    # Auto-detect and remove Redis exporter"
    echo "  $0 --exporter mysql --method docker    # Remove MySQL exporter Docker container only"
    echo "  $0 --exporter postgres --method host   # Remove PostgreSQL exporter host service only"
    echo "  $0 --all                              # Remove all database exporters"
    echo "  $0 --all --force                      # Remove all without confirmation"
}

# Function to detect installation method
detect_installation_method() {
    local exporter=$1
    local docker_found=false
    local host_found=false
    
    # Check for Docker containers
    if command -v docker &> /dev/null; then
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "${exporter}-exporter"; then
            docker_found=true
        fi
    fi
    
    # Check for systemd services
    if systemctl list-unit-files 2>/dev/null | grep -q "${exporter}_exporter.service"; then
        host_found=true
    fi
    
    if [[ "$docker_found" == true && "$host_found" == true ]]; then
        echo "both"
    elif [[ "$docker_found" == true ]]; then
        echo "docker"
    elif [[ "$host_found" == true ]]; then
        echo "host"
    else
        echo "none"
    fi
}

# Function to confirm action
confirm_action() {
    local message=$1
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo -n "$message (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to remove Docker container
remove_docker_container() {
    local exporter=$1
    local container_name="${exporter}-exporter"
    
    echo "Removing Docker container: $container_name"
    
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container_name"; then
        if confirm_action "Remove Docker container '$container_name'?"; then
            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
            echo "✓ Docker container '$container_name' removed successfully"
        else
            echo "Skipped Docker container removal"
        fi
    else
        echo "⚠ Docker container '$container_name' not found"
    fi
}

# Function to remove host service
remove_host_service() {
    local exporter=$1
    local service_name="${exporter}_exporter"
    local binary_name=""
    local config_dir=""
    
    case $exporter in
        redis)
            binary_name="redis_exporter"
            ;;
        mysql)
            binary_name="mysqld_exporter"
            config_dir="/etc/mysql_exporter"
            ;;
        postgres)
            binary_name="postgres_exporter"
            ;;
        mongodb)
            binary_name="mongodb_exporter"
            ;;
    esac
    
    echo "Removing host service: $service_name"
    
    if systemctl list-unit-files 2>/dev/null | grep -q "${service_name}.service"; then
        if confirm_action "Remove host service '$service_name'?"; then
            # Stop and disable service
            sudo systemctl stop "$service_name" 2>/dev/null || true
            sudo systemctl disable "$service_name" 2>/dev/null || true
            
            # Remove service file
            sudo rm -f "/etc/systemd/system/${service_name}.service"
            
            # Remove binary
            sudo rm -f "/usr/local/bin/$binary_name"
            
            # Remove config directory if exists
            if [[ -n "$config_dir" && -d "$config_dir" ]]; then
                sudo rm -rf "$config_dir"
            fi
            
            # Remove user
            sudo userdel "$service_name" 2>/dev/null || true
            
            # Reload systemd
            sudo systemctl daemon-reload
            
            echo "✓ Host service '$service_name' removed successfully"
        else
            echo "Skipped host service removal"
        fi
    else
        echo "⚠ Host service '$service_name' not found"
    fi
}

# Function to remove exporter
remove_exporter() {
    local exporter=$1
    local method=$2
    
    echo "========================================="
    echo "Removing $exporter exporter"
    echo "========================================="
    
    if [[ -z "$method" ]]; then
        method=$(detect_installation_method "$exporter")
        echo "Detected installation method: $method"
    fi
    
    case $method in
        docker)
            remove_docker_container "$exporter"
            ;;
        host)
            remove_host_service "$exporter"
            ;;
        both)
            echo "Both Docker and host installations found"
            remove_docker_container "$exporter"
            remove_host_service "$exporter"
            ;;
        none)
            echo "⚠ No installation found for $exporter exporter"
            ;;
        *)
            echo "Error: Invalid method '$method'. Use 'docker', 'host', or 'both'"
            exit 1
            ;;
    esac
}

# Function to remove all exporters
remove_all_exporters() {
    echo "========================================="
    echo "Removing ALL database exporters"
    echo "========================================="
    
    if ! confirm_action "This will remove ALL database exporters (Redis, MySQL, PostgreSQL, MongoDB). Continue?"; then
        echo "Operation cancelled"
        exit 0
    fi
    
    local exporters=("redis" "mysql" "postgres" "mongodb")
    
    for exporter in "${exporters[@]}"; do
        local method=$(detect_installation_method "$exporter")
        if [[ "$method" != "none" ]]; then
            remove_exporter "$exporter" "$method"
            echo ""
        fi
    done
}

# Function to clean up orphaned resources
cleanup_orphaned_resources() {
    echo "========================================="
    echo "Cleaning up orphaned resources"
    echo "========================================="
    
    # Remove orphaned Docker images
    if command -v docker &> /dev/null; then
        echo "Checking for orphaned Docker images..."
        local images=(
            "oliver006/redis_exporter"
            "quay.io/prometheus/mysqld-exporter"
            "quay.io/prometheus/postgres-exporter"
            "percona/mongodb_exporter"
        )
        
        for image in "${images[@]}"; do
            if docker images --format "{{.Repository}}" | grep -q "^${image}$"; then
                if confirm_action "Remove Docker image '$image'?"; then
                    docker rmi "$image" 2>/dev/null || true
                    echo "✓ Removed Docker image: $image"
                fi
            fi
        done
    fi
    
    # Check for orphaned users
    echo "Checking for orphaned users..."
    local users=("redis_exporter" "mysql_exporter" "postgres_exporter" "mongodb_exporter")
    
    for user in "${users[@]}"; do
        if id "$user" &>/dev/null; then
            if confirm_action "Remove user '$user'?"; then
                sudo userdel "$user" 2>/dev/null || true
                echo "✓ Removed user: $user"
            fi
        fi
    done
}

# Parse command line arguments
EXPORTER=""
METHOD=""
ALL=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --exporter)
            EXPORTER="$2"
            shift 2
            ;;
        --method)
            METHOD="$2"
            shift 2
            ;;
        --all)
            ALL=true
            shift
            ;;
        --force)
            FORCE=true
            shift
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

# Main execution
if [[ "$ALL" == true ]]; then
    remove_all_exporters
    if confirm_action "Clean up orphaned resources (Docker images, users)?"; then
        cleanup_orphaned_resources
    fi
elif [[ -n "$EXPORTER" ]]; then
    case $EXPORTER in
        redis|mysql|postgres|mongodb)
            remove_exporter "$EXPORTER" "$METHOD"
            ;;
        *)
            echo "Error: Invalid exporter '$EXPORTER'. Use 'redis', 'mysql', 'postgres', or 'mongodb'"
            show_help
            exit 1
            ;;
    esac
else
    echo "Error: Either --exporter or --all must be specified"
    show_help
    exit 1
fi

echo ""
echo "========================================="
echo "Uninstallation completed!"
echo "========================================="

# Final verification
echo "Verifying removal..."
if [[ "$ALL" == true ]]; then
    local exporters=("redis" "mysql" "postgres" "mongodb")
    for exporter in "${exporters[@]}"; do
        local method=$(detect_installation_method "$exporter")
        if [[ "$method" == "none" ]]; then
            echo "✓ $exporter exporter: Not found (successfully removed)"
        else
            echo "⚠ $exporter exporter: Still found ($method installation)"
        fi
    done
elif [[ -n "$EXPORTER" ]]; then
    local method=$(detect_installation_method "$EXPORTER")
    if [[ "$method" == "none" ]]; then
        echo "✓ $EXPORTER exporter: Not found (successfully removed)"
    else
        echo "⚠ $EXPORTER exporter: Still found ($method installation)"
    fi
fi
