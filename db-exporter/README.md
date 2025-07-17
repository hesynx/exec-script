# Database Exporters Installer

A unified installer script for Prometheus database exporters (Redis, MySQL, PostgreSQL, MongoDB) with automatic service detection and intelligent defaults.

## 🚀 Quick Install

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter <redis|mysql|postgres|mongodb>
```

### Download and Run

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh -o db-exporter.sh

# Make it executable
chmod +x db-exporter.sh

# Run with auto-detection
./db-exporter.sh --exporter redis
```

## 📋 Supported Database Exporters

| Database | Exporter | Default Port | Repository |
|----------|----------|--------------|------------|
| Redis | redis_exporter | 9121 | [oliver006/redis_exporter](https://github.com/oliver006/redis_exporter) |
| MySQL | mysqld_exporter | 9104 | [prometheus/mysqld_exporter](https://github.com/prometheus/mysqld_exporter) |
| PostgreSQL | postgres_exporter | 9187 | [prometheus-community/postgres_exporter](https://github.com/prometheus-community/postgres_exporter) |
| MongoDB | mongodb_exporter | 9216 | [percona/mongodb_exporter](https://github.com/percona/mongodb_exporter) |

## 🔍 Auto-Detection Features

The script automatically detects running database services and sets intelligent defaults:

- **On-premises service found**: Uses `--method host` (preferred)
- **Only Docker service found**: Uses `--method docker`
- **Both found**: Defaults to `--method host` (on-premises preferred)
- **None found**: Defaults to `--method host` with standard connections

## 📖 Usage

### Basic Usage (Recommended)

```bash
# Auto-detect and install Redis exporter
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter redis

# Auto-detect and install MySQL exporter
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter mysql

# Auto-detect and install PostgreSQL exporter
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter postgres

# Auto-detect and install MongoDB exporter
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter mongodb
```

### Advanced Usage

#### Force Installation Method

```bash
# Force on-premises installation
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter redis --onprem

# Force Docker installation
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter mysql --docker
```

#### Custom Connection Strings

```bash
# Redis with custom connection
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter redis --redis-addr "redis://user:password@localhost:6379"

# MySQL with custom DSN
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter mysql --mysql-dsn "exporter:password@(localhost:3306)/"

# PostgreSQL with custom DSN
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter postgres --postgres-dsn "postgresql://user:pass@localhost:5432/mydb"

# MongoDB with custom URI
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter mongodb --mongodb-uri "mongodb://user:pass@localhost:27017"
```

## 🛠 Installation Methods

### Docker Installation

Installs the exporter as a Docker container with automatic restart policy.

**Requirements:**
- Docker installed and running
- Database accessible from Docker network

**Advantages:**
- Easy to manage and update
- Isolated environment
- Automatic restarts

### Host Installation

Installs the exporter directly on the host system as a systemd service.

**Requirements:**
- systemd-based Linux distribution
- sudo privileges

**Advantages:**
- Better performance
- Direct access to host metrics
- More configuration options

## 📝 Command Line Options

### Required Options
- `--exporter <type>` - Database exporter type (`redis`, `mysql`, `postgres`, `mongodb`)

### Optional Options
- `--method <method>` - Installation method (`docker`, `host`) - auto-detected if not specified
- `--onprem` - Force on-premises/host installation (alias for `--method host`)
- `--docker` - Force Docker installation (alias for `--method docker`)

### Connection Options (auto-detected if not specified)
- `--redis-addr <addr>` - Redis connection string
- `--mysql-dsn <dsn>` - MySQL connection string  
- `--postgres-dsn <dsn>` - PostgreSQL connection string
- `--mongodb-uri <uri>` - MongoDB connection string

### Other Options
- `--help` - Show help message

## 🔧 Connection String Formats

### Redis
```bash
# Basic
redis://localhost:6379

# With authentication
redis://password@localhost:6379

# With username and password
redis://user:password@localhost:6379
```

### MySQL
```bash
# Basic
root:@(localhost:3306)/

# With password
user:password@(localhost:3306)/

# With specific database
user:password@(localhost:3306)/database

# TCP connection
user:password@tcp(host:3306)/database
```

### PostgreSQL
```bash
# Basic
postgresql://postgres:@localhost:5432/postgres?sslmode=disable

# With password
postgresql://user:password@localhost:5432/database

# With SSL
postgresql://user:password@localhost:5432/database?sslmode=require
```

### MongoDB
```bash
# Basic
mongodb://localhost:27017

# With authentication
mongodb://user:password@localhost:27017

# With specific database
mongodb://user:password@localhost:27017/database

# Replica set
mongodb://user:password@host1:27017,host2:27017/database?replicaSet=rs0
```

## 📊 Prometheus Configuration

After installation, add the exporter to your `prometheus.yml`:

### Redis Exporter
```yaml
scrape_configs:
  - job_name: 'redis'
    static_configs:
      - targets: ['your-server-ip:9121']
```

### MySQL Exporter
```yaml
scrape_configs:
  - job_name: 'mysql'
    static_configs:
      - targets: ['your-server-ip:9104']
```

### PostgreSQL Exporter
```yaml
scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['your-server-ip:9187']
```

### MongoDB Exporter
```yaml
scrape_configs:
  - job_name: 'mongodb'
    static_configs:
      - targets: ['your-server-ip:9216']
```

## 🔍 Verification

After installation, verify the exporter is working:

```bash
# Check if exporter is running
curl http://localhost:<port>/metrics

# Check systemd service status (for host installations)
sudo systemctl status <exporter-name>_exporter

# Check Docker container status (for Docker installations)
docker ps | grep <exporter-name>-exporter
```

## 🗑️ Uninstallation

### Quick Uninstall

```bash
# Uninstall specific exporter
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-uninstaller.sh | bash -s -- --exporter <redis|mysql|postgres|mongodb>

# Uninstall all database exporters
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-uninstaller.sh | bash -s -- --all

# Force uninstall without confirmation
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-uninstaller.sh | bash -s -- --all --force
```

### Uninstaller Features

- **Auto-Detection**: Automatically detects Docker and host installations
- **Selective Removal**: Remove specific exporters or all at once
- **Method Selection**: Choose to remove Docker containers, host services, or both
- **Safety Checks**: Confirmation prompts before removal (can be bypassed with `--force`)
- **Complete Cleanup**: Removes services, binaries, users, config files, and Docker images
- **Verification**: Confirms successful removal after completion

### Uninstaller Options

- `--exporter <type>` - Remove specific exporter (redis, mysql, postgres, mongodb)
- `--method <method>` - Remove specific installation type (docker, host, both)
- `--all` - Remove all database exporters
- `--force` - Skip confirmation prompts
- `--help` - Show help message

### Download and Run

```bash
# Download the uninstaller script
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-uninstaller.sh -o db-uninstaller.sh

# Make it executable
chmod +x db-uninstaller.sh

# Uninstall specific exporter
./db-uninstaller.sh --exporter redis

# Uninstall all exporters
./db-uninstaller.sh --all
```

### Manual Uninstallation

#### Docker Containers
```bash
# Stop and remove Redis exporter
docker stop redis-exporter && docker rm redis-exporter

# Stop and remove MySQL exporter
docker stop mysql-exporter && docker rm mysql-exporter

# Stop and remove PostgreSQL exporter
docker stop postgres-exporter && docker rm postgres-exporter

# Stop and remove MongoDB exporter
docker stop mongodb-exporter && docker rm mongodb-exporter
```

#### Host Services
```bash
# Redis exporter
sudo systemctl stop redis_exporter
sudo systemctl disable redis_exporter
sudo rm /etc/systemd/system/redis_exporter.service
sudo rm /usr/local/bin/redis_exporter
sudo userdel redis_exporter

# MySQL exporter
sudo systemctl stop mysql_exporter
sudo systemctl disable mysql_exporter
sudo rm /etc/systemd/system/mysql_exporter.service
sudo rm /usr/local/bin/mysqld_exporter
sudo rm -rf /etc/mysql_exporter
sudo userdel mysql_exporter

# PostgreSQL exporter
sudo systemctl stop postgres_exporter
sudo systemctl disable postgres_exporter
sudo rm /etc/systemd/system/postgres_exporter.service
sudo rm /usr/local/bin/postgres_exporter
sudo userdel postgres_exporter

# MongoDB exporter
sudo systemctl stop mongodb_exporter
sudo systemctl disable mongodb_exporter
sudo rm /etc/systemd/system/mongodb_exporter.service
sudo rm /usr/local/bin/mongodb_exporter
sudo userdel mongodb_exporter

# Reload systemd after removing services
sudo systemctl daemon-reload
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Permission Denied
```bash
# Ensure script is executable
chmod +x db-exporter.sh

# Run with sudo if needed for host installation
sudo ./db-exporter.sh --exporter redis --method host
```

#### 2. Docker Not Found
```bash
# Install Docker first
curl -fsSL https://get.docker.com | sh
sudo systemctl start docker
sudo systemctl enable docker
```

#### 3. Connection Refused
- Check if the database service is running
- Verify connection string parameters
- Check firewall settings
- Ensure database allows connections from exporter

#### 4. Metrics Not Available
```bash
# Check exporter logs (host installation)
sudo journalctl -u redis_exporter -f

# Check Docker logs
docker logs redis-exporter
```

### Service Management

#### Host Installation (systemd)
```bash
# Start service
sudo systemctl start redis_exporter

# Stop service
sudo systemctl stop redis_exporter

# Restart service
sudo systemctl restart redis_exporter

# View logs
sudo journalctl -u redis_exporter -f
```

#### Docker Installation
```bash
# Start container
docker start redis-exporter

# Stop container
docker stop redis-exporter

# Restart container
docker restart redis-exporter

# View logs
docker logs redis-exporter -f
```

## 🔒 Security Considerations

1. **Database Credentials**: Store sensitive credentials in environment files or use authentication mechanisms
2. **Network Access**: Restrict exporter access to Prometheus servers only
3. **Firewall Rules**: Configure appropriate firewall rules for exporter ports
4. **User Permissions**: Run exporters with minimal required privileges

## 📚 Examples

### Complete Setup Examples

#### Redis with Docker
```bash
# Start Redis container
docker run -d --name redis -p 6379:6379 redis:latest

# Install Redis exporter (auto-detects Docker Redis)
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter redis
```

#### MySQL on Host
```bash
# Install MySQL exporter for host-based MySQL
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter mysql --onprem --mysql-dsn "monitoring:password@(localhost:3306)/"
```

#### PostgreSQL with Custom Settings
```bash
# Install PostgreSQL exporter with custom connection
curl -fsSL https://raw.githubusercontent.com/hesynx/exec-script/refs/heads/main/db-exporter/db-exporter.sh | bash -s -- --exporter postgres --postgres-dsn "postgresql://monitoring:securepass@db-server:5432/production?sslmode=require"
```

## 🆘 Support

- **GitHub Issues**: Report issues on the repository
- **Documentation**: Check exporter-specific documentation for advanced configuration
- **Community**: Join Prometheus community forums for general support

## 📄 License

This script is provided as-is under the MIT License. Individual exporters may have their own licenses.
