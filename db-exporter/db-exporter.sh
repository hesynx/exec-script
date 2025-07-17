#!/bin/bash

# Database Exporters Installer Script
# Usage: ./db-exporters.sh --exporter <redis|mysql|postgres|mongodb> --method <docker|host> [options]

set -e

# Default configurations
REDIS_EXPORTER_VERSION="latest"
MYSQL_EXPORTER_VERSION="latest"
POSTGRES_EXPORTER_VERSION="latest"
MONGODB_EXPORTER_VERSION="latest"

REDIS_PORT="9121"
MYSQL_PORT="9104"
POSTGRES_PORT="9187"
MONGODB_PORT="9216"

# Default connection strings with standardized credentials
REDIS_ADDR="redis://:1qa2ws3ed123@localhost:6379"
MYSQL_DSN="exporter:1qa2ws3ed123@(localhost:3306)/"
POSTGRES_DSN="postgresql://exporter:1qa2ws3ed123@localhost:5432/testdb?sslmode=disable"
MONGODB_URI="mongodb://exporter:1qa2ws3ed123@localhost:27017/admin"

# Function to get the latest release tag from GitHub
get_latest_release() {
    local repo=$1
    curl -s https://api.github.com/repos/${repo}/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

show_help() {
    echo "Database Exporters Installer"
    echo "Usage: $0 --exporter <redis|mysql|postgres|mongodb> [--method <docker|host>] [options]"
    echo ""
    echo "Required Options:"
    echo "  --exporter <type>      Database exporter type (redis|mysql|postgres|mongodb)"
    echo ""
    echo "Optional Options:"
    echo "  --method <method>      Installation method (docker|host) - auto-detected if not specified"
    echo "  --onprem               Force on-premises/host installation (alias for --method host)"
    echo "  --docker               Force Docker installation (alias for --method docker)"
    echo ""
    echo "Connection Options (auto-detected if not specified):"
    echo "  --redis-addr <addr>    Redis connection string"
    echo "  --mysql-dsn <dsn>      MySQL connection string"
    echo "  --postgres-dsn <dsn>   PostgreSQL connection string"
    echo "  --mongodb-uri <uri>    MongoDB connection string"
    echo ""
    echo "Other Options:"
    echo "  --help                 Show this help message"
    echo ""
    echo "Auto-Detection:"
    echo "  The script automatically detects running database services:"
    echo "  - If on-premises service found: defaults to --method host"
    echo "  - If only Docker service found: defaults to --method docker"
    echo "  - If both found: defaults to --method host (on-premises preferred)"
    echo "  - If none found: defaults to --method host with standard connections"
    echo ""
    echo "Examples:"
    echo "  $0 --exporter redis                    # Auto-detect method and connection"
    echo "  $0 --exporter mysql --onprem           # Force on-premises installation"
    echo "  $0 --exporter postgres --docker        # Force Docker installation"
    echo "  $0 --exporter mongodb --method host --mongodb-uri 'mongodb://user:pass@localhost:27017'"
}

# Function to get the main network interface IP
get_main_ip() {
    ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1
}

# Function to detect running database services
detect_database_services() {
    local db_type=$1
    local onprem_found=false
    local docker_found=false
    local default_connection=""
    
    case $db_type in
        redis)
            # Check for on-premises Redis (default port 6379)
            if netstat -tuln 2>/dev/null | grep -q ":6379 " || ss -tuln 2>/dev/null | grep -q ":6379 "; then
                onprem_found=true
                default_connection="redis://:1qa2ws3ed123@localhost:6379"
            fi
            
            # Check for Docker Redis containers
            if command -v docker &> /dev/null; then
                if docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep -q "6379"; then
                    docker_found=true
                    if [[ "$onprem_found" == false ]]; then
                        default_connection="redis://:1qa2ws3ed123@localhost:6379"
                    fi
                fi
            fi
            ;;
            
        mysql)
            # Check for on-premises MySQL (default port 3306)
            if netstat -tuln 2>/dev/null | grep -q ":3306 " || ss -tuln 2>/dev/null | grep -q ":3306 "; then
                onprem_found=true
                default_connection="exporter:1qa2ws3ed123@(localhost:3306)/"
            fi
            
            # Check for Docker MySQL containers
            if command -v docker &> /dev/null; then
                if docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep -q "3306"; then
                    docker_found=true
                    if [[ "$onprem_found" == false ]]; then
                        default_connection="exporter:1qa2ws3ed123@(localhost:3306)/"
                    fi
                fi
            fi
            ;;
            
        postgres)
            # Check for on-premises PostgreSQL (default port 5432)
            if netstat -tuln 2>/dev/null | grep -q ":5432 " || ss -tuln 2>/dev/null | grep -q ":5432 "; then
                onprem_found=true
                default_connection="postgresql://exporter:1qa2ws3ed123@localhost:5432/testdb?sslmode=disable"
            fi
            
            # Check for Docker PostgreSQL containers
            if command -v docker &> /dev/null; then
                if docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep -q "5432"; then
                    docker_found=true
                    if [[ "$onprem_found" == false ]]; then
                        default_connection="postgresql://exporter:1qa2ws3ed123@localhost:5432/testdb?sslmode=disable"
                    fi
                fi
            fi
            ;;
            
        mongodb)
            # Check for on-premises MongoDB (default port 27017)
            if netstat -tuln 2>/dev/null | grep -q ":27017 " || ss -tuln 2>/dev/null | grep -q ":27017 "; then
                onprem_found=true
                default_connection="mongodb://exporter:1qa2ws3ed123@localhost:27017/admin"
            fi
            
            # Check for Docker MongoDB containers
            if command -v docker &> /dev/null; then
                if docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep -q "27017"; then
                    docker_found=true
                    if [[ "$onprem_found" == false ]]; then
                        default_connection="mongodb://exporter:1qa2ws3ed123@localhost:27017/admin"
                    fi
                fi
            fi
            ;;
    esac
    
    # Set global variables based on detection
    if [[ "$onprem_found" == true ]]; then
        echo "✓ Detected on-premises $db_type service"
        DETECTED_METHOD="host"
        case $db_type in
            redis) REDIS_ADDR="$default_connection" ;;
            mysql) MYSQL_DSN="$default_connection" ;;
            postgres) POSTGRES_DSN="$default_connection" ;;
            mongodb) MONGODB_URI="$default_connection" ;;
        esac
    elif [[ "$docker_found" == true ]]; then
        echo "✓ Detected Docker $db_type service"
        DETECTED_METHOD="docker"
        case $db_type in
            redis) REDIS_ADDR="$default_connection" ;;
            mysql) MYSQL_DSN="$default_connection" ;;
            postgres) POSTGRES_DSN="$default_connection" ;;
            mongodb) MONGODB_URI="$default_connection" ;;
        esac
    else
        echo "⚠ No running $db_type service detected, using defaults"
        DETECTED_METHOD="host"
        case $db_type in
            redis) REDIS_ADDR="redis://:1qa2ws3ed123@localhost:6379" ;;
            mysql) MYSQL_DSN="exporter:1qa2ws3ed123@(localhost:3306)/" ;;
            postgres) POSTGRES_DSN="postgresql://exporter:1qa2ws3ed123@localhost:5432/testdb?sslmode=disable" ;;
            mongodb) MONGODB_URI="mongodb://exporter:1qa2ws3ed123@localhost:27017/admin" ;;
        esac
    fi
    
    echo "Default connection: $default_connection"
    echo "Suggested method: $DETECTED_METHOD"
}

install_redis_docker() {
    echo "Installing Redis Exporter using Docker..."
    
    MAIN_IP=$(get_main_ip)
    echo "Detected main interface IP: $MAIN_IP"
    echo "Redis connection: $REDIS_ADDR"
    
    docker pull oliver006/redis_exporter:${REDIS_EXPORTER_VERSION}
    
    docker stop redis-exporter 2>/dev/null || true
    docker rm redis-exporter 2>/dev/null || true
    
    docker run -d \
        --name redis-exporter \
        --restart unless-stopped \
        -p ${REDIS_PORT}:9121 \
        -e REDIS_ADDR="${REDIS_ADDR}" \
        oliver006/redis_exporter:${REDIS_EXPORTER_VERSION}
    
    echo "Redis Exporter installed successfully!"
    echo "Access metrics at: http://${MAIN_IP}:${REDIS_PORT}/metrics"
}

install_redis_host() {
    echo "Installing Redis Exporter on host..."
    
    LISTEN_IP="0.0.0.0"
    MAIN_IP=$(get_main_ip)
    
    VERSION="$REDIS_EXPORTER_VERSION"
    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release "oliver006/redis_exporter")
        echo "Resolved latest Redis Exporter version: $VERSION"
    fi
    
    sudo useradd --no-create-home --shell /bin/false redis_exporter 2>/dev/null || true
    
    cd /tmp
    wget https://github.com/oliver006/redis_exporter/releases/download/${VERSION}/redis_exporter-${VERSION}.linux-amd64.tar.gz
    tar xvf redis_exporter-${VERSION}.linux-amd64.tar.gz
    
    sudo cp redis_exporter-${VERSION}.linux-amd64/redis_exporter /usr/local/bin/
    sudo chown redis_exporter:redis_exporter /usr/local/bin/redis_exporter
    
    sudo tee /etc/systemd/system/redis_exporter.service > /dev/null <<EOF
[Unit]
Description=Redis Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=redis_exporter
Group=redis_exporter
Type=simple
Environment=REDIS_ADDR=${REDIS_ADDR}
ExecStart=/usr/local/bin/redis_exporter --web.listen-address=${LISTEN_IP}:${REDIS_PORT}

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable redis_exporter
    sudo systemctl start redis_exporter
    
    rm -rf /tmp/redis_exporter-${VERSION}.linux-amd64*
    
    echo "Redis Exporter installed successfully!"
    echo "Service status: $(sudo systemctl is-active redis_exporter)"
    echo "Access metrics at: http://${MAIN_IP}:${REDIS_PORT}/metrics"
}

install_mysql_docker() {
    echo "Installing MySQL Exporter using Docker..."
    
    MAIN_IP=$(get_main_ip)
    echo "Detected main interface IP: $MAIN_IP"
    echo "MySQL DSN: $MYSQL_DSN"
    
    docker pull quay.io/prometheus/mysqld-exporter:${MYSQL_EXPORTER_VERSION}
    
    docker stop mysql-exporter 2>/dev/null || true
    docker rm mysql-exporter 2>/dev/null || true
    
    docker run -d \
        --name mysql-exporter \
        --restart unless-stopped \
        -p ${MYSQL_PORT}:9104 \
        -e DATA_SOURCE_NAME="${MYSQL_DSN}" \
        quay.io/prometheus/mysqld-exporter:${MYSQL_EXPORTER_VERSION}
    
    echo "MySQL Exporter installed successfully!"
    echo "Access metrics at: http://${MAIN_IP}:${MYSQL_PORT}/metrics"
}

install_mysql_host() {
    echo "Installing MySQL Exporter on host..."
    
    LISTEN_IP="0.0.0.0"
    MAIN_IP=$(get_main_ip)
    
    VERSION="$MYSQL_EXPORTER_VERSION"
    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release "prometheus/mysqld_exporter")
        echo "Resolved latest MySQL Exporter version: $VERSION"
    fi
    
    sudo useradd --no-create-home --shell /bin/false mysql_exporter 2>/dev/null || true
    
    cd /tmp
    wget https://github.com/prometheus/mysqld_exporter/releases/download/${VERSION}/mysqld_exporter-${VERSION#v}.linux-amd64.tar.gz
    tar xvf mysqld_exporter-${VERSION#v}.linux-amd64.tar.gz
    
    sudo cp mysqld_exporter-${VERSION#v}.linux-amd64/mysqld_exporter /usr/local/bin/
    sudo chown mysql_exporter:mysql_exporter /usr/local/bin/mysqld_exporter
    
    sudo tee /etc/systemd/system/mysql_exporter.service > /dev/null <<EOF
[Unit]
Description=MySQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=mysql_exporter
Group=mysql_exporter
Type=simple
Environment=DATA_SOURCE_NAME=${MYSQL_DSN}
ExecStart=/usr/local/bin/mysqld_exporter --web.listen-address=${LISTEN_IP}:${MYSQL_PORT}

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable mysql_exporter
    sudo systemctl start mysql_exporter
    
    rm -rf /tmp/mysqld_exporter-${VERSION#v}.linux-amd64*
    
    echo "MySQL Exporter installed successfully!"
    echo "Service status: $(sudo systemctl is-active mysql_exporter)"
    echo "Access metrics at: http://${MAIN_IP}:${MYSQL_PORT}/metrics"
}

install_postgres_docker() {
    echo "Installing PostgreSQL Exporter using Docker..."
    
    MAIN_IP=$(get_main_ip)
    echo "Detected main interface IP: $MAIN_IP"
    echo "PostgreSQL DSN: $POSTGRES_DSN"
    
    docker pull quay.io/prometheus/postgres-exporter:${POSTGRES_EXPORTER_VERSION}
    
    docker stop postgres-exporter 2>/dev/null || true
    docker rm postgres-exporter 2>/dev/null || true
    
    docker run -d \
        --name postgres-exporter \
        --restart unless-stopped \
        -p ${POSTGRES_PORT}:9187 \
        -e DATA_SOURCE_NAME="${POSTGRES_DSN}" \
        quay.io/prometheus/postgres-exporter:${POSTGRES_EXPORTER_VERSION}
    
    echo "PostgreSQL Exporter installed successfully!"
    echo "Access metrics at: http://${MAIN_IP}:${POSTGRES_PORT}/metrics"
}

install_postgres_host() {
    echo "Installing PostgreSQL Exporter on host..."
    
    LISTEN_IP="0.0.0.0"
    MAIN_IP=$(get_main_ip)
    
    VERSION="$POSTGRES_EXPORTER_VERSION"
    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release "prometheus-community/postgres_exporter")
        echo "Resolved latest PostgreSQL Exporter version: $VERSION"
    fi
    
    sudo useradd --no-create-home --shell /bin/false postgres_exporter 2>/dev/null || true
    
    cd /tmp
    wget https://github.com/prometheus-community/postgres_exporter/releases/download/${VERSION}/postgres_exporter-${VERSION#v}.linux-amd64.tar.gz
    tar xvf postgres_exporter-${VERSION#v}.linux-amd64.tar.gz
    
    sudo cp postgres_exporter-${VERSION#v}.linux-amd64/postgres_exporter /usr/local/bin/
    sudo chown postgres_exporter:postgres_exporter /usr/local/bin/postgres_exporter
    
    sudo tee /etc/systemd/system/postgres_exporter.service > /dev/null <<EOF
[Unit]
Description=PostgreSQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
Environment=DATA_SOURCE_NAME=${POSTGRES_DSN}
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=${LISTEN_IP}:${POSTGRES_PORT}

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable postgres_exporter
    sudo systemctl start postgres_exporter
    
    rm -rf /tmp/postgres_exporter-${VERSION#v}.linux-amd64*
    
    echo "PostgreSQL Exporter installed successfully!"
    echo "Service status: $(sudo systemctl is-active postgres_exporter)"
    echo "Access metrics at: http://${MAIN_IP}:${POSTGRES_PORT}/metrics"
}

install_mongodb_docker() {
    echo "Installing MongoDB Exporter using Docker..."
    
    MAIN_IP=$(get_main_ip)
    echo "Detected main interface IP: $MAIN_IP"
    echo "MongoDB URI: $MONGODB_URI"
    
    docker pull percona/mongodb_exporter:${MONGODB_EXPORTER_VERSION}
    
    docker stop mongodb-exporter 2>/dev/null || true
    docker rm mongodb-exporter 2>/dev/null || true
    
    docker run -d \
        --name mongodb-exporter \
        --restart unless-stopped \
        -p ${MONGODB_PORT}:9216 \
        -e MONGODB_URI="${MONGODB_URI}" \
        percona/mongodb_exporter:${MONGODB_EXPORTER_VERSION}
    
    echo "MongoDB Exporter installed successfully!"
    echo "Access metrics at: http://${MAIN_IP}:${MONGODB_PORT}/metrics"
}

install_mongodb_host() {
    echo "Installing MongoDB Exporter on host..."
    
    LISTEN_IP="0.0.0.0"
    MAIN_IP=$(get_main_ip)
    
    VERSION="$MONGODB_EXPORTER_VERSION"
    if [[ "$VERSION" == "latest" ]]; then
        VERSION=$(get_latest_release "percona/mongodb_exporter")
        echo "Resolved latest MongoDB Exporter version: $VERSION"
    fi
    
    sudo useradd --no-create-home --shell /bin/false mongodb_exporter 2>/dev/null || true
    
    cd /tmp
    wget https://github.com/percona/mongodb_exporter/releases/download/${VERSION}/mongodb_exporter-${VERSION#v}.linux-amd64.tar.gz
    tar xvf mongodb_exporter-${VERSION#v}.linux-amd64.tar.gz
    
    sudo cp mongodb_exporter-${VERSION#v}.linux-amd64/mongodb_exporter /usr/local/bin/
    sudo chown mongodb_exporter:mongodb_exporter /usr/local/bin/mongodb_exporter
    
    sudo tee /etc/systemd/system/mongodb_exporter.service > /dev/null <<EOF
[Unit]
Description=MongoDB Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=mongodb_exporter
Group=mongodb_exporter
Type=simple
Environment=MONGODB_URI=${MONGODB_URI}
ExecStart=/usr/local/bin/mongodb_exporter --web.listen-address=${LISTEN_IP}:${MONGODB_PORT}

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable mongodb_exporter
    sudo systemctl start mongodb_exporter
    
    rm -rf /tmp/mongodb_exporter-${VERSION#v}.linux-amd64*
    
    echo "MongoDB Exporter installed successfully!"
    echo "Service status: $(sudo systemctl is-active mongodb_exporter)"
    echo "Access metrics at: http://${MAIN_IP}:${MONGODB_PORT}/metrics"
}

check_installation() {
    local port=$1
    local name=$2
    
    echo "Checking $name installation..."
    sleep 3
    
    if curl -s http://127.0.0.1:${port}/metrics > /dev/null; then
        echo "✓ $name is running and accessible on 0.0.0.0:${port}"
        echo "✓ Metrics endpoint: http://$(get_main_ip):${port}/metrics"
    else
        echo "✗ $name is not accessible"
        exit 1
    fi
}

# Parse command line arguments
EXPORTER=""
METHOD=""
DETECTED_METHOD=""

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
        --onprem)
            METHOD="host"
            shift
            ;;
        --docker)
            METHOD="docker"
            shift
            ;;
        --redis-addr)
            REDIS_ADDR="$2"
            shift 2
            ;;
        --mysql-dsn)
            MYSQL_DSN="$2"
            shift 2
            ;;
        --postgres-dsn)
            POSTGRES_DSN="$2"
            shift 2
            ;;
        --mongodb-uri)
            MONGODB_URI="$2"
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

# Validate required parameters
if [[ -z "$EXPORTER" ]]; then
    echo "Error: --exporter parameter is required"
    show_help
    exit 1
fi

# Auto-detect database services and set defaults
echo "Detecting $EXPORTER database services..."
detect_database_services "$EXPORTER"

# Use detected method if not explicitly specified
if [[ -z "$METHOD" ]]; then
    METHOD="$DETECTED_METHOD"
    echo "Using auto-detected method: $METHOD"
else
    echo "Using specified method: $METHOD"
fi

# Check if Docker is installed for docker method
if [[ "$METHOD" == "docker" ]] && ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first or use --method host."
    exit 1
fi

# Install based on exporter type and method
case $EXPORTER in
    redis)
        case $METHOD in
            docker) install_redis_docker ;;
            host) install_redis_host ;;
            *) echo "Error: Invalid method '$METHOD'. Use 'docker' or 'host'"; exit 1 ;;
        esac
        check_installation $REDIS_PORT "Redis Exporter"
        echo "Add to prometheus.yml: - job_name: 'redis'; static_configs: - targets: ['$(get_main_ip):${REDIS_PORT}']"
        ;;
    mysql)
        case $METHOD in
            docker) install_mysql_docker ;;
            host) install_mysql_host ;;
            *) echo "Error: Invalid method '$METHOD'. Use 'docker' or 'host'"; exit 1 ;;
        esac
        check_installation $MYSQL_PORT "MySQL Exporter"
        echo "Add to prometheus.yml: - job_name: 'mysql'; static_configs: - targets: ['$(get_main_ip):${MYSQL_PORT}']"
        ;;
    postgres)
        case $METHOD in
            docker) install_postgres_docker ;;
            host) install_postgres_host ;;
            *) echo "Error: Invalid method '$METHOD'. Use 'docker' or 'host'"; exit 1 ;;
        esac
        check_installation $POSTGRES_PORT "PostgreSQL Exporter"
        echo "Add to prometheus.yml: - job_name: 'postgres'; static_configs: - targets: ['$(get_main_ip):${POSTGRES_PORT}']"
        ;;
    mongodb)
        case $METHOD in
            docker) install_mongodb_docker ;;
            host) install_mongodb_host ;;
            *) echo "Error: Invalid method '$METHOD'. Use 'docker' or 'host'"; exit 1 ;;
        esac
        check_installation $MONGODB_PORT "MongoDB Exporter"
        echo "Add to prometheus.yml: - job_name: 'mongodb'; static_configs: - targets: ['$(get_main_ip):${MONGODB_PORT}']"
        ;;
    *)
        echo "Error: Invalid exporter '$EXPORTER'. Use 'redis', 'mysql', 'postgres', or 'mongodb'"
        show_help
        exit 1
        ;;
esac

echo ""
echo "Installation completed successfully!"
echo "You can now configure Prometheus to scrape this $EXPORTER exporter instance."
