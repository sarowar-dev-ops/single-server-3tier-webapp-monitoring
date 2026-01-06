# BMI Health Tracker - Monitoring Server Manual Setup Guide

This comprehensive guide walks you through manually setting up a complete monitoring infrastructure for the BMI Health Tracker application, including **Prometheus**, **Grafana**, **Loki**, **AlertManager**, and **Node Exporter** on a fresh Ubuntu 22.04 LTS server.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Part 1: Initial Server Setup](#part-1-initial-server-setup)
- [Part 2: Install Prometheus](#part-2-install-prometheus)
- [Part 3: Install Node Exporter](#part-3-install-node-exporter)
- [Part 4: Install Grafana](#part-4-install-grafana)
- [Part 5: Install Loki](#part-5-install-loki)
- [Part 6: Install AlertManager](#part-6-install-alertmanager)
- [Part 7: Configure Alert Rules](#part-7-configure-alert-rules)
- [Part 8: Configure Grafana Datasources](#part-8-configure-grafana-datasources)
- [Part 9: Verification & Testing](#part-9-verification--testing)
- [Part 10: Next Steps](#part-10-next-steps)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What You'll Build

A complete monitoring stack that includes:

- **Prometheus** (v2.48.0) - Metrics collection and storage
- **Grafana** (Latest) - Visualization and dashboards
- **Loki** (v2.9.3) - Log aggregation
- **AlertManager** (v0.26.0) - Alert routing and notifications
- **Node Exporter** (v1.7.0) - System metrics collection

### Ports Used

| Service | Port | Purpose |
|---------|------|---------|
| **Prometheus** | 9090 | Web UI & API |
| **Grafana** | 3000 | Web UI |
| **Loki** | 3100 | Log ingestion API |
| **AlertManager** | 9093 | Web UI & API |
| **Node Exporter** | 9100 | Metrics endpoint |

---

## Prerequisites

### Hardware Requirements

- **Minimum**: 4GB RAM, 2 vCPU, 30GB disk
- **Recommended**: 8GB RAM, 4 vCPU, 50GB disk

### Software Requirements

- Ubuntu 22.04 LTS (fresh install)
- Root or sudo access
- Internet connectivity

### AWS EC2 Security Group

Add these inbound rules:

| Type | Port | Source | Description |
|------|------|--------|-------------|
| SSH | 22 | Your IP | SSH access |
| Custom TCP | 9090 | 0.0.0.0/0 | Prometheus |
| Custom TCP | 3000 | 0.0.0.0/0 | Grafana |
| Custom TCP | 3100 | Application Server IP | Loki |
| Custom TCP | 9093 | 0.0.0.0/0 | AlertManager |
| Custom TCP | 9100 | Application Server IP | Node Exporter |

---

## Part 1: Initial Server Setup

### 1.1 Connect to Server

```bash
# Connect via SSH
ssh -i your-key.pem ubuntu@YOUR_MONITORING_SERVER_IP

# Switch to root
sudo su -
```

### 1.2 Update System

```bash
# Update package lists
apt update

# Upgrade installed packages
apt upgrade -y
```

### 1.3 Install Essential Tools

```bash
# Install required utilities
apt install -y curl wget git vim htop net-tools ufw unzip software-properties-common jq
```

### 1.4 Configure Firewall

```bash
# Enable UFW
ufw --force enable

# Allow SSH (important - do this first!)
ufw allow 22/tcp comment 'SSH'

# Allow monitoring services
ufw allow 9090/tcp comment 'Prometheus'
ufw allow 3000/tcp comment 'Grafana'
ufw allow 3100/tcp comment 'Loki'
ufw allow 9093/tcp comment 'AlertManager'
ufw allow 9100/tcp comment 'Node Exporter'

# Check status
ufw status numbered
```

### 1.5 Set Timezone

```bash
# Set to UTC
timedatectl set-timezone UTC

# Verify
timedatectl
```

### 1.6 Create Service Users

```bash
# Create users without home directories
useradd --no-create-home --shell /bin/false prometheus
useradd --no-create-home --shell /bin/false node_exporter
useradd --no-create-home --shell /bin/false alertmanager
useradd --no-create-home --shell /bin/false loki

# Verify users
id prometheus
id node_exporter
id alertmanager
id loki
```

---

## Part 2: Install Prometheus

### 2.1 Download Prometheus

```bash
# Navigate to tmp directory
cd /tmp

# Download Prometheus v2.48.0
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz

# Verify download
ls -lh prometheus-2.48.0.linux-amd64.tar.gz
```

### 2.2 Extract and Install

```bash
# Extract archive
tar -xzf prometheus-2.48.0.linux-amd64.tar.gz

# Navigate to extracted directory
cd prometheus-2.48.0.linux-amd64

# Copy binaries to /usr/local/bin
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

# Set ownership
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# Verify installation
prometheus --version
promtool --version
```

### 2.3 Create Directories

```bash
# Create configuration directory
mkdir -p /etc/prometheus

# Create data directory
mkdir -p /var/lib/prometheus

# Copy console files
cp -r consoles /etc/prometheus/
cp -r console_libraries /etc/prometheus/

# Set ownership
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
```

### 2.4 Create Configuration File

```bash
# Create prometheus.yml
cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'bmi-monitoring'
    environment: 'production'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - localhost:9093

rule_files:
  - "alerts/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'monitoring-server'

  - job_name: 'node_exporter_monitoring'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'monitoring-server'
EOF

# Set ownership
chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Validate configuration
promtool check config /etc/prometheus/prometheus.yml
```

### 2.5 Create Systemd Service

```bash
# Create service file
cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --storage.tsdb.retention.time=15d \
  --web.enable-lifecycle \
  --web.listen-address=0.0.0.0:9090

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 2.6 Start Prometheus

```bash
# Reload systemd
systemctl daemon-reload

# Enable service
systemctl enable prometheus

# Start service
systemctl start prometheus

# Check status
systemctl status prometheus

# Verify logs
journalctl -u prometheus -f
# Press Ctrl+C to exit
```

### 2.7 Verify Installation

```bash
# Check if Prometheus is responding
curl http://localhost:9090/-/healthy

# Access web UI (from your browser)
# http://YOUR_MONITORING_SERVER_IP:9090
```

---

## Part 3: Install Node Exporter

### 3.1 Download Node Exporter

```bash
# Navigate to tmp
cd /tmp

# Download Node Exporter v1.7.0
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz

# Extract
tar -xzf node_exporter-1.7.0.linux-amd64.tar.gz
```

### 3.2 Install Binary

```bash
# Copy binary
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Set ownership
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Verify
node_exporter --version
```

### 3.3 Create Systemd Service

```bash
# Create service file
cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 3.4 Start Node Exporter

```bash
# Reload systemd
systemctl daemon-reload

# Enable and start
systemctl enable node_exporter
systemctl start node_exporter

# Check status
systemctl status node_exporter

# Verify metrics
curl http://localhost:9100/metrics | head -20
```

---

## Part 4: Install Grafana

### 4.1 Add Grafana Repository

```bash
# Add GPG key
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -

# Add repository
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

# Update package list
apt update
```

### 4.2 Install Grafana

```bash
# Install Grafana
apt install -y grafana

# Verify installation
grafana-server -v
```

### 4.3 Configure Network Access

```bash
# Backup original configuration
cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.backup

# Configure to listen on all interfaces
sed -i 's/^;http_addr =.*/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini

# Verify change
grep "http_addr" /etc/grafana/grafana.ini
```

### 4.4 Start Grafana

```bash
# Reload systemd
systemctl daemon-reload

# Enable and start
systemctl enable grafana-server
systemctl start grafana-server

# Check status
systemctl status grafana-server

# Wait for Grafana to be ready
sleep 10

# Check health
curl http://localhost:3000/api/health
```

### 4.5 Access Grafana

**Access URL**: `http://YOUR_MONITORING_SERVER_IP:3000`

**Default Credentials**:
- Username: `admin`
- Password: `admin`
- You'll be prompted to change the password on first login

---

## Part 5: Install Loki

### 5.1 Download Loki

```bash
# Navigate to tmp
cd /tmp

# Download Loki v2.9.3
wget https://github.com/grafana/loki/releases/download/v2.9.3/loki-linux-amd64.zip

# Unzip
unzip loki-linux-amd64.zip
```

### 5.2 Install Binary

```bash
# Move binary
mv loki-linux-amd64 /usr/local/bin/loki

# Make executable
chmod +x /usr/local/bin/loki

# Verify
loki --version
```

### 5.3 Create Directories

```bash
# Create configuration directory
mkdir -p /etc/loki

# Create data directories
mkdir -p /var/lib/loki/{wal,chunks,boltdb-shipper-active,boltdb-shipper-cache,boltdb-shipper-compactor,rules,rules-temp}

# Set ownership
chown -R loki:loki /var/lib/loki
```

### 5.4 Create Configuration

```bash
# Create loki-config.yml
cat > /etc/loki/loki-config.yml <<'EOF'
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
    - from: 2023-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /var/lib/loki/boltdb-shipper-active
    cache_location: /var/lib/loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /var/lib/loki/chunks

compactor:
  working_directory: /var/lib/loki/boltdb-shipper-compactor
  shared_store: filesystem

limits_config:
  retention_period: 168h
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 24

chunk_store_config:
  max_look_back_period: 168h

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h

ruler:
  storage:
    type: local
    local:
      directory: /var/lib/loki/rules
  rule_path: /var/lib/loki/rules-temp
  alertmanager_url: http://localhost:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
EOF

# Set ownership
chown loki:loki /etc/loki/loki-config.yml
```

### 5.5 Create Systemd Service

```bash
# Create service file
cat > /etc/systemd/system/loki.service <<'EOF'
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
EOF
```

### 5.6 Start Loki

```bash
# Reload systemd
systemctl daemon-reload

# Enable and start
systemctl enable loki
systemctl start loki

# Check status
systemctl status loki

# Verify Loki is ready
curl http://localhost:3100/ready
```

---

## Part 6: Install AlertManager

### 6.1 Download AlertManager

```bash
# Navigate to tmp
cd /tmp

# Download AlertManager v0.26.0
wget https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz

# Extract
tar -xzf alertmanager-0.26.0.linux-amd64.tar.gz

# Navigate to directory
cd alertmanager-0.26.0.linux-amd64
```

### 6.2 Install Binaries

```bash
# Copy binaries
cp alertmanager /usr/local/bin/
cp amtool /usr/local/bin/

# Set ownership
chown alertmanager:alertmanager /usr/local/bin/alertmanager
chown alertmanager:alertmanager /usr/local/bin/amtool

# Verify
alertmanager --version
```

### 6.3 Create Directories

```bash
# Create configuration directory
mkdir -p /etc/alertmanager

# Create data directory
mkdir -p /var/lib/alertmanager

# Set ownership
chown alertmanager:alertmanager /etc/alertmanager
chown alertmanager:alertmanager /var/lib/alertmanager
```

### 6.4 Create Configuration

```bash
# Create alertmanager.yml
cat > /etc/alertmanager/alertmanager.yml <<'EOF'
global:
  resolve_timeout: 5m
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alertmanager@bmi-tracker.local'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical'
    - match:
        severity: warning
      receiver: 'warning'

receivers:
  - name: 'default'
    # Add your notification channels here (email, slack, etc.)
  
  - name: 'critical'
    # Critical alerts configuration
  
  - name: 'warning'
    # Warning alerts configuration

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
EOF

# Set ownership
chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml
```

### 6.5 Create Systemd Service

```bash
# Create service file
cat > /etc/systemd/system/alertmanager.service <<'EOF'
[Unit]
Description=AlertManager
After=network.target

[Service]
Type=simple
User=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager/ \
  --web.listen-address=0.0.0.0:9093 \
  --web.external-url=http://localhost:9093

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 6.6 Start AlertManager

```bash
# Reload systemd
systemctl daemon-reload

# Enable and start
systemctl enable alertmanager
systemctl start alertmanager

# Check status
systemctl status alertmanager

# Verify health
curl http://localhost:9093/-/healthy
```

---

## Part 7: Configure Alert Rules

### 7.1 Create Alert Rules Directory

```bash
# Create directory
mkdir -p /etc/prometheus/alerts

# Set ownership
chown prometheus:prometheus /etc/prometheus/alerts
```

### 7.2 Create Basic Alert Rules

```bash
# Create basic_alerts.yml
cat > /etc/prometheus/alerts/basic_alerts.yml <<'EOF'
groups:
  - name: basic_alerts
    interval: 30s
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 10 minutes."

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 10 minutes."

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk space is below 15% on root filesystem."
EOF

# Set ownership
chown prometheus:prometheus /etc/prometheus/alerts/basic_alerts.yml
```

### 7.3 Validate Alert Rules

```bash
# Validate syntax
promtool check rules /etc/prometheus/alerts/basic_alerts.yml
```

### 7.4 Reload Prometheus

```bash
# Reload configuration
curl -X POST http://localhost:9090/-/reload

# Or restart service
systemctl restart prometheus

# Verify rules loaded
curl -s http://localhost:9090/api/v1/rules | jq
```

---

## Part 8: Configure Grafana Datasources

### 8.1 Add Prometheus Datasource

```bash
# Add Prometheus datasource via API
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true,
    "basicAuth": false
  }'
```

### 8.2 Add Loki Datasource

```bash
# Add Loki datasource via API
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://localhost:3100",
    "access": "proxy",
    "basicAuth": false
  }'
```

### 8.3 Verify Datasources

**Via Web UI:**
1. Login to Grafana: `http://YOUR_MONITORING_SERVER_IP:3000`
2. Go to **Configuration** → **Data Sources**
3. Verify both **Prometheus** and **Loki** are listed

**Via API:**
```bash
# List all datasources
curl -s http://admin:admin@localhost:3000/api/datasources | jq
```

---

## Part 9: Verification & Testing

### 9.1 Check All Services

```bash
# Check service status
systemctl status prometheus
systemctl status node_exporter
systemctl status grafana-server
systemctl status loki
systemctl status alertmanager

# Quick status check
for service in prometheus node_exporter grafana-server loki alertmanager; do
  systemctl is-active $service && echo "$service: ✓ Running" || echo "$service: ✗ Not Running"
done
```

### 9.2 Verify Network Ports

```bash
# Check listening ports
netstat -tulpn | grep -E '9090|3000|3100|9093|9100'

# Expected output should show:
# 0.0.0.0:9090 (Prometheus)
# 0.0.0.0:3000 (Grafana)
# 127.0.0.1:3100 or 0.0.0.0:3100 (Loki)
# 0.0.0.0:9093 (AlertManager)
# 0.0.0.0:9100 (Node Exporter)
```

### 9.3 Test Prometheus Targets

**Via Web UI:**
1. Access: `http://YOUR_MONITORING_SERVER_IP:9090/targets`
2. Verify all targets show **UP** status

**Via API:**
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### 9.4 Test Metrics Collection

```bash
# Query Prometheus metrics
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq

# Query Node Exporter metrics
curl -s http://localhost:9100/metrics | grep "node_cpu_seconds_total" | head -5

# Test Loki
curl http://localhost:3100/ready
```

### 9.5 Access Web Interfaces

Open these URLs in your browser:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Prometheus** | `http://YOUR_SERVER_IP:9090` | None |
| **Grafana** | `http://YOUR_SERVER_IP:3000` | admin / admin |
| **AlertManager** | `http://YOUR_SERVER_IP:9093` | None |

---

## Part 10: Next Steps

### 10.1 Import Grafana Dashboards

**Popular Dashboards:**

1. **Node Exporter Full** (ID: 1860)
   - Go to Grafana → Dashboards → Import
   - Enter Dashboard ID: `1860`
   - Select Prometheus datasource
   - Click Import

2. **Prometheus Stats** (ID: 2)
   - Dashboard ID: `2`

### 10.2 Add Application Server Monitoring

On your **Application Server**, run:

```bash
# Clone repository
cd ~
git clone <your-repo-url>

# Run application server monitoring setup
cd single-server-3tier-webapp-monitoring
sudo ./monitoring/Basic_Monitoring_Setup.sh

# Or use enhanced setup
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
```

### 10.3 Configure Email Alerts

Edit AlertManager configuration:

```bash
# Edit config
sudo nano /etc/alertmanager/alertmanager.yml

# Add email configuration under 'global':
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

# Restart AlertManager
sudo systemctl restart alertmanager
```

### 10.4 Secure Grafana

```bash
# Change admin password via Grafana UI or:
grafana-cli admin reset-admin-password NEW_PASSWORD

# Configure SSL (recommended for production)
# Edit /etc/grafana/grafana.ini:
sudo nano /etc/grafana/grafana.ini
```

### 10.5 Setup Backups

```bash
# Create backup script
cat > /root/backup-monitoring.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/root/monitoring-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup Prometheus data
tar -czf $BACKUP_DIR/prometheus-$DATE.tar.gz /var/lib/prometheus/

# Backup Grafana
tar -czf $BACKUP_DIR/grafana-$DATE.tar.gz /var/lib/grafana/

# Backup configs
tar -czf $BACKUP_DIR/configs-$DATE.tar.gz \
  /etc/prometheus/ \
  /etc/grafana/ \
  /etc/loki/ \
  /etc/alertmanager/

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

# Make executable
chmod +x /root/backup-monitoring.sh

# Schedule daily backup (2 AM)
crontab -e
# Add: 0 2 * * * /root/backup-monitoring.sh
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check service logs
sudo journalctl -u prometheus -n 50
sudo journalctl -u grafana-server -n 50
sudo journalctl -u loki -n 50

# Check configuration syntax
promtool check config /etc/prometheus/prometheus.yml

# Check file permissions
ls -la /etc/prometheus/
ls -la /var/lib/prometheus/
```

### Can't Access Web Interface

```bash
# Check if service is listening on correct interface
netstat -tulpn | grep 9090

# Check firewall
sudo ufw status

# Check service status
systemctl status prometheus

# Try accessing locally first
curl http://localhost:9090
```

### No Metrics Showing in Grafana

```bash
# Verify datasource in Grafana
curl -s http://admin:admin@localhost:3000/api/datasources | jq

# Test Prometheus query
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq
```

### Disk Space Issues

```bash
# Check disk usage
df -h

# Check Prometheus data size
du -sh /var/lib/prometheus/

# Clean old data (adjust retention)
# Edit /etc/systemd/system/prometheus.service
# Change --storage.tsdb.retention.time=15d to lower value

# Restart Prometheus
sudo systemctl restart prometheus
```

### AlertManager Not Receiving Alerts

```bash
# Check Prometheus alertmanager config
curl -s http://localhost:9090/api/v1/alertmanagers | jq

# Check alert rules
curl -s http://localhost:9090/api/v1/rules | jq

# Test alert rule evaluation
promtool test rules /etc/prometheus/alerts/basic_alerts.yml

# Check AlertManager logs
journalctl -u alertmanager -f
```

---

## Configuration File Locations

| Component | Configuration | Data Directory |
|-----------|--------------|----------------|
| **Prometheus** | `/etc/prometheus/prometheus.yml` | `/var/lib/prometheus/` |
| **Node Exporter** | Service file only | N/A |
| **Grafana** | `/etc/grafana/grafana.ini` | `/var/lib/grafana/` |
| **Loki** | `/etc/loki/loki-config.yml` | `/var/lib/loki/` |
| **AlertManager** | `/etc/alertmanager/alertmanager.yml` | `/var/lib/alertmanager/` |
| **Alert Rules** | `/etc/prometheus/alerts/*.yml` | N/A |

---

## Useful Commands Reference

```bash
# Service Management
sudo systemctl status prometheus
sudo systemctl restart prometheus
sudo systemctl stop prometheus
sudo systemctl start prometheus

# View Logs
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server --since "1 hour ago"
sudo journalctl -u loki -n 100

# Reload Configurations
curl -X POST http://localhost:9090/-/reload  # Prometheus
sudo systemctl reload grafana-server          # Grafana

# Check Configuration
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alerts/basic_alerts.yml

# Test Metrics
curl http://localhost:9090/metrics
curl http://localhost:9100/metrics
curl http://localhost:3100/ready

# Query Prometheus
curl 'http://localhost:9090/api/v1/query?query=up'
curl 'http://localhost:9090/api/v1/targets'

# Backup Commands
tar -czf prometheus-backup.tar.gz /var/lib/prometheus/
tar -czf grafana-backup.tar.gz /var/lib/grafana/
```

---

## Security Best Practices

1. **Change Default Passwords**
   - Grafana admin password
   - Add authentication to Prometheus (if exposed)

2. **Enable HTTPS**
   - Configure SSL certificates
   - Use Let's Encrypt for free certificates

3. **Restrict Network Access**
   - Use security groups/firewall rules
   - Limit access to specific IPs

4. **Regular Updates**
   - Keep services updated
   - Monitor security advisories

5. **Enable Authentication**
   - Configure Grafana auth (OAuth, LDAP, etc.)
   - Add basic auth to Prometheus

---

## Summary

You now have a complete monitoring infrastructure with:

✅ **Prometheus** collecting and storing metrics  
✅ **Grafana** providing visualization dashboards  
✅ **Loki** aggregating application logs  
✅ **AlertManager** handling alert notifications  
✅ **Node Exporter** collecting system metrics  

### Quick Access

- **Prometheus**: `http://YOUR_SERVER_IP:9090`
- **Grafana**: `http://YOUR_SERVER_IP:3000` (admin/admin)
- **AlertManager**: `http://YOUR_SERVER_IP:9093`

### Next: Connect Application Server

Once your monitoring server is ready, configure your application server to send metrics and logs using:
- `monitoring/Basic_Monitoring_Setup.sh` (basic setup)
- `monitoring/3-tier-app/scripts/setup-application-server.sh` (enhanced setup)

---

**Setup Complete!** 🎉

For automated setup, you can also use:
```bash
sudo ./monitoring/MONITORING_SERVER_SETUP.sh
```

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)  
🐙 GitHub: [@md-sarowar-alam](https://github.com/md-sarowar-alam)

---

### License

This guide is provided as educational material for DevOps engineers.

---

**© 2026 Md. Sarowar Alam. All rights reserved.**
