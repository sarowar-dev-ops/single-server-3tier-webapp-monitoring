#!/bin/bash

##############################################################################
# BMI Health Tracker - Monitoring Server Setup Script
# 
# This script installs and configures:
# - Prometheus (metrics collection)
# - Grafana (visualization)
# - Loki (log aggregation)
# - AlertManager (alerting)
# - Node Exporter (system metrics)
#
# Usage: sudo ./setup-monitoring-server.sh
##############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Versions
PROMETHEUS_VERSION="2.48.0"
GRAFANA_VERSION="latest"
LOKI_VERSION="2.9.3"
ALERTMANAGER_VERSION="0.26.0"
NODE_EXPORTER_VERSION="1.7.0"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Please run as root or with sudo"
        exit 1
    fi
}

# Get EC2 Public IP (IMDSv2)
get_ec2_public_ip() {
    # Try to get token for IMDSv2
    local TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
        --connect-timeout 2 2>/dev/null)
    
    if [ -n "$TOKEN" ]; then
        # Use IMDSv2 with token
        local PUBLIC_IP=$(curl -s \
            -H "X-aws-ec2-metadata-token: $TOKEN" \
            --connect-timeout 2 \
            http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    else
        # Fallback to IMDSv1
        local PUBLIC_IP=$(curl -s --connect-timeout 2 \
            http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    fi
    
    # Trim whitespace and return
    echo "$PUBLIC_IP" | tr -d '[:space:]'
}

# Main execution
log_info "====================================================================="
log_info "BMI Health Tracker - Monitoring Server Setup"
log_info "====================================================================="

check_root

# Detect if running from cloned repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [ -f "$REPO_DIR/monitoring/prometheus/prometheus.yml" ]; then
    log_info "Detected repository at: $REPO_DIR"
    USE_REPO=true
    CONFIG_SOURCE="$REPO_DIR/monitoring"
else
    log_warning "Repository not detected. Using inline configurations."
    USE_REPO=false
fi

# Get application server IP
echo ""
log_info "Network Configuration:"
log_info "If both servers are in the same VPC/subnet, use PRIVATE IP for better security and performance."
log_info "Private IPs avoid internet exposure and data transfer costs."
echo ""
read -p "Enter APPLICATION SERVER PRIVATE IP address: " APP_SERVER_IP
if [ -z "$APP_SERVER_IP" ]; then
    log_error "Application server IP is required"
    exit 1
fi

log_info "Application server IP: $APP_SERVER_IP"

# Update system
log_info "Updating system packages..."
apt update && apt upgrade -y
log_success "System updated"

# Install essential tools
log_info "Installing essential tools..."
apt install -y curl wget git vim htop net-tools unzip
log_success "Essential tools installed"

# Create users
log_info "Creating service users..."
useradd --no-create-home --shell /bin/false prometheus || true
useradd --no-create-home --shell /bin/false grafana || true
useradd --no-create-home --shell /bin/false loki || true
log_success "Service users created"

# Create directories
log_info "Creating directory structure..."
mkdir -p /opt/monitoring/{prometheus,grafana,loki,alertmanager}
mkdir -p /var/lib/{prometheus,grafana,loki,alertmanager}
mkdir -p /etc/{prometheus,grafana,loki,alertmanager}
log_success "Directories created"

#=============================================================================
# INSTALL PROMETHEUS
#=============================================================================
log_info "Installing Prometheus ${PROMETHEUS_VERSION}..."

# Stop existing service if running
if systemctl is-active --quiet prometheus; then
    log_info "Stopping existing Prometheus service..."
    systemctl stop prometheus
fi

cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64
cp -f prometheus promtool /usr/local/bin/
cp -r consoles console_libraries /etc/prometheus/
chown -R prometheus:prometheus /usr/local/bin/prom* /etc/prometheus /var/lib/prometheus

# Create Prometheus configuration
log_info "Creating Prometheus configuration..."

if [ "$USE_REPO" = true ] && [ -f "$CONFIG_SOURCE/prometheus/prometheus.yml" ]; then
    log_info "Using prometheus.yml from repository..."
    cp "$CONFIG_SOURCE/prometheus/prometheus.yml" /etc/prometheus/prometheus.yml
    
    # Update application server IP in the config (handle both placeholder formats)
    sed -i "s/APP_SERVER_IP/${APP_SERVER_IP}/g" /etc/prometheus/prometheus.yml
    sed -i "s/APPLICATION_SERVER_IP/${APP_SERVER_IP}/g" /etc/prometheus/prometheus.yml
    
    # Copy alert rules if available
    if [ -f "$CONFIG_SOURCE/prometheus/alert_rules.yml" ]; then
        cp "$CONFIG_SOURCE/prometheus/alert_rules.yml" /etc/prometheus/alert_rules.yml
        log_success "Alert rules copied from repository"
    fi
else
    log_info "Creating default prometheus.yml..."
    cat > /etc/prometheus/prometheus.yml <<'EOFPROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOFPROM

    # Add application server targets
    cat >> /etc/prometheus/prometheus.yml <<EOFPROM

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['${APP_SERVER_IP}:9100']
        labels:
          server: 'app-server'

  - job_name: 'postgresql'
    static_configs:
      - targets: ['${APP_SERVER_IP}:9187']
        labels:
          server: 'app-server'

  - job_name: 'nginx'
    static_configs:
      - targets: ['${APP_SERVER_IP}:9113']
        labels:
          server: 'app-server'

  - job_name: 'bmi-backend'
    static_configs:
      - targets: ['${APP_SERVER_IP}:9091']
        labels:
          server: 'app-server'

  - job_name: 'node_exporter_monitoring'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          server: 'monitoring-server'
EOFPROM

    # Create empty alert rules file if not using repo
    touch /etc/prometheus/alert_rules.yml
fi

# Create Prometheus systemd service
cat > /etc/systemd/system/prometheus.service <<'EOFSVC'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --storage.tsdb.retention.time=30d \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOFSVC

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

log_success "Prometheus installed and started on port 9090"

#=============================================================================
# INSTALL GRAFANA
#=============================================================================
log_info "Installing Grafana..."
apt install -y software-properties-common
add-apt-repository -y "deb https://apt.grafana.com stable main"
wget -q -O - https://apt.grafana.com/gpg.key | apt-key add -
apt update
apt install -y grafana

systemctl enable grafana-server
systemctl start grafana-server

log_success "Grafana installed and started on port 3000"
log_warning "Default credentials: admin/admin (change immediately!)"

#=============================================================================
# CONFIGURE GRAFANA DATASOURCES
#=============================================================================
log_info "Configuring Grafana datasources..."

# Create provisioning directories
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards

# Configure Prometheus datasource
cat > /etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
      queryTimeout: 60s
EOF

# Configure Loki datasource
cat > /etc/grafana/provisioning/datasources/loki.yml <<EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    editable: false
    jsonData:
      maxLines: 1000
      timeout: 60
EOF

log_success "Datasources configured (Prometheus and Loki)"

#=============================================================================
# CONFIGURE GRAFANA DASHBOARDS
#=============================================================================
log_info "Configuring Grafana dashboards..."

# Create dashboard provider configuration
cat > /etc/grafana/provisioning/dashboards/default.yml <<EOF
apiVersion: 1

providers:
  - name: 'BMI Application Dashboards'
    orgId: 1
    folder: 'BMI Health Tracker'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
EOF

# Copy dashboards from repository if available
if [ "$USE_REPO" = true ]; then
    DASHBOARD_COUNT=0
    
    # Copy Three-Tier Application Dashboard
    if [ -f "$REPO_DIR/monitoring/3-tier-app/dashboards/three-tier-application-dashboard.json" ]; then
        log_info "Copying Three-Tier Application Dashboard..."
        cp "$REPO_DIR/monitoring/3-tier-app/dashboards/three-tier-application-dashboard.json" \
           /var/lib/grafana/dashboards/
        log_success "Dashboard imported: Three-Tier Application Dashboard"
        ((DASHBOARD_COUNT++))
    else
        log_warning "Three-Tier Application Dashboard not found in repository"
    fi
    
    # Copy Loki Logs Dashboard
    if [ -f "$REPO_DIR/monitoring/3-tier-app/dashboards/loki-logs-dashboard.json" ]; then
        log_info "Copying Loki Logs Dashboard..."
        cp "$REPO_DIR/monitoring/3-tier-app/dashboards/loki-logs-dashboard.json" \
           /var/lib/grafana/dashboards/
        log_success "Dashboard imported: Loki Logs Dashboard"
        ((DASHBOARD_COUNT++))
    else
        log_warning "Loki Logs Dashboard not found in repository"
    fi
    
    chown -R grafana:grafana /var/lib/grafana/dashboards
    
    if [ $DASHBOARD_COUNT -eq 0 ]; then
        log_warning "No dashboards found. You can import them manually later."
    else
        log_success "$DASHBOARD_COUNT dashboard(s) imported successfully"
    fi
else
    log_warning "Repository not detected. Dashboards can be imported manually later."
fi

# Set correct permissions
chown -R grafana:grafana /etc/grafana/provisioning
chown -R grafana:grafana /var/lib/grafana/dashboards

# Restart Grafana to apply provisioning
systemctl restart grafana-server
sleep 3

log_success "Grafana datasources and dashboards configured"

#=============================================================================
# INSTALL LOKI
#=============================================================================
log_info "Installing Loki ${LOKI_VERSION}..."

# Stop existing service if running
if systemctl is-active --quiet loki; then
    log_info "Stopping existing Loki service..."
    systemctl stop loki
fi

cd /tmp
wget -q https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip
unzip -o loki-linux-amd64.zip
mv -f loki-linux-amd64 /usr/local/bin/loki
chmod +x /usr/local/bin/loki

# Create Loki configuration
if [ "$USE_REPO" = true ] && [ -f "$CONFIG_SOURCE/loki/loki-config.yml" ]; then
    log_info "Using loki-config.yml from repository..."
    cp "$CONFIG_SOURCE/loki/loki-config.yml" /etc/loki/loki-config.yml
else
    log_info "Creating default loki-config.yml..."
    cat > /etc/loki/loki-config.yml <<'EOFLOKI'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 744h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

chunk_store_config:
  max_look_back_period: 744h

table_manager:
  retention_deletes_enabled: true
  retention_period: 744h
EOFLOKI
fi

chown -R loki:loki /var/lib/loki /etc/loki

# Create Loki systemd service
cat > /etc/systemd/system/loki.service <<'EOFSVC'
[Unit]
Description=Loki Log Aggregation System
After=network.target

[Service]
Type=simple
User=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOFSVC

systemctl daemon-reload
systemctl enable loki
systemctl start loki

log_success "Loki installed and started on port 3100"

#=============================================================================
# INSTALL ALERTMANAGER
#=============================================================================
log_info "Installing AlertManager ${ALERTMANAGER_VERSION}..."

# Stop existing service if running
if systemctl is-active --quiet alertmanager; then
    log_info "Stopping existing AlertManager service..."
    systemctl stop alertmanager
fi

cd /tmp
wget -q https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
tar -xzf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
cd alertmanager-${ALERTMANAGER_VERSION}.linux-amd64
cp -f alertmanager amtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/alert*

# Create AlertManager configuration
if [ "$USE_REPO" = true ] && [ -f "$CONFIG_SOURCE/alertmanager/alertmanager.yml" ]; then
    log_info "Using alertmanager.yml from repository..."
    cp "$CONFIG_SOURCE/alertmanager/alertmanager.yml" /etc/alertmanager/alertmanager.yml
else
    log_info "Creating default alertmanager.yml..."
    cat > /etc/alertmanager/alertmanager.yml <<'EOFAM'
global:
  resolve_timeout: 5m

route:
  receiver: 'default-receiver'
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: 'default-receiver'
    # Configure notification channels here

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOFAM
fi

chown -R prometheus:prometheus /etc/alertmanager
mkdir -p /var/lib/alertmanager
chown prometheus:prometheus /var/lib/alertmanager

# Create AlertManager systemd service
cat > /etc/systemd/system/alertmanager.service <<'EOFSVC'
[Unit]
Description=AlertManager
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --web.listen-address=0.0.0.0:9093

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOFSVC

systemctl daemon-reload
systemctl enable alertmanager
systemctl start alertmanager

log_success "AlertManager installed and started on port 9093"

#=============================================================================
# INSTALL NODE EXPORTER (for monitoring server itself)
#=============================================================================
log_info "Installing Node Exporter ${NODE_EXPORTER_VERSION}..."

# Stop existing service if running
if systemctl is-active --quiet node_exporter; then
    log_info "Stopping existing Node Exporter service..."
    systemctl stop node_exporter
fi

cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp -f node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/node_exporter

# Create Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service <<'EOFSVC'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/node_exporter

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOFSVC

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

log_success "Node Exporter installed and started on port 9100"

#=============================================================================
# CLEANUP
#=============================================================================
log_info "Cleaning up temporary files..."
cd /tmp
rm -rf prometheus-* alertmanager-* node_exporter-* loki-linux-amd64*
log_success "Cleanup completed"

#=============================================================================
# FIREWALL CONFIGURATION
#=============================================================================
log_info "Configuring firewall (UFW)..."
ufw --force enable
ufw allow 22/tcp comment 'SSH'
ufw allow 3000/tcp comment 'Grafana'
ufw allow 9090/tcp comment 'Prometheus'
ufw allow 9093/tcp comment 'AlertManager'
ufw allow from $APP_SERVER_IP to any port 3100 comment 'Loki from app server'
ufw reload
log_success "Firewall configured"

#=============================================================================
# SUMMARY
#=============================================================================
echo ""
log_success "====================================================================="
log_success "Monitoring Server Setup Completed Successfully!"
log_success "====================================================================="
echo ""
log_info "Services Status:"
systemctl is-active prometheus && log_success "✓ Prometheus: Running on port 9090" || log_error "✗ Prometheus: Failed"
systemctl is-active grafana-server && log_success "✓ Grafana: Running on port 3000" || log_error "✗ Grafana: Failed"
systemctl is-active loki && log_success "✓ Loki: Running on port 3100" || log_error "✗ Loki: Failed"
systemctl is-active alertmanager && log_success "✓ AlertManager: Running on port 9093" || log_error "✗ AlertManager: Failed"
systemctl is-active node_exporter && log_success "✓ Node Exporter: Running on port 9100" || log_error "✗ Node Exporter: Failed"

echo ""
log_info "Access URLs:"
MONITORING_IP=$(get_ec2_public_ip)
if [ -z "$MONITORING_IP" ] || [ "$MONITORING_IP" = "" ]; then
    log_warning "Could not detect EC2 public IP. Using hostname..."
    MONITORING_IP=$(hostname -I | awk '{print $1}')
fi
echo "  Grafana:      http://${MONITORING_IP}:3000 (admin/admin)"
echo "  Prometheus:   http://${MONITORING_IP}:9090"
echo "  Loki:         http://${MONITORING_IP}:3100 (API/metrics only)"
echo "  AlertManager: http://${MONITORING_IP}:9093"

echo ""
log_warning "Next Steps:"
echo "  1. Change Grafana admin password immediately"
echo "  2. Run setup-application-exporters.sh on application server"
echo "  3. Configure alert notifications in AlertManager"
echo "  4. Datasources (Prometheus & Loki) are pre-configured"
echo "  5. Dashboards are pre-loaded in 'BMI Health Tracker' folder"
echo ""
log_info "Pre-configured Components:"
echo "  ✓ Prometheus datasource (default)"
echo "  ✓ Loki datasource for logs"
echo "  ✓ Three-Tier Application Dashboard"
echo "  ✓ Loki Logs Dashboard"
echo ""

log_info "For detailed documentation, see: monitoring/IMPLEMENTATION_GUIDE.md"
