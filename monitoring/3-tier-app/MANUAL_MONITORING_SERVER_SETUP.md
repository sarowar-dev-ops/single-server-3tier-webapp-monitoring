# Three-Tier Application Monitoring Server - Manual Setup Guide

## Overview

This comprehensive guide walks you through manually setting up a complete monitoring infrastructure for your three-tier BMI Health Tracker application. 

**Companion to**: `monitoring/3-tier-app/scripts/setup-monitoring-server.sh` (automated version)

### What Will Be Installed

- **Prometheus v2.48.0** - Metrics collection and storage (30-day retention)
- **Grafana (latest)** - Visualization and dashboards on port 3001
- **Loki v2.9.3** - Log aggregation (31-day retention)
- **AlertManager v0.26.0** - Alert handling and notifications
- **Node Exporter v1.7.0** - System metrics for monitoring server itself

### Monitoring Coverage

The monitoring server will collect metrics and logs from:

- **Frontend Layer**: Nginx web server metrics and access/error logs
- **Backend Layer**: Node.js application metrics, API performance, application logs
- **Database Layer**: PostgreSQL database metrics and logs
- **System Layer**: CPU, memory, disk, network metrics from application server

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Server                        │
│                                                             │
│  ┌──────────────┐  ┌──────────┐  ┌─────┐  ┌──────────┐   │
│  │  Prometheus  │  │ Grafana  │  │Loki │  │AlertMgr  │   │
│  │    :9090     │  │  :3001   │  │:3100│  │  :9093   │   │
│  └──────┬───────┘  └────┬─────┘  └──┬──┘  └──────────┘   │
│         │               │            │                      │
│         │  Scrapes      │ Visualize  │ Logs                │
│         │  Metrics      │ Metrics    │ Collection          │
└─────────┼───────────────┼────────────┼──────────────────────┘
          │               │            │
          │               │            │
          ▼               ▼            ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Server (3-Tier App)                │
│                                                             │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────┐        │
│  │   Nginx    │  │   Node.js   │  │  PostgreSQL  │        │
│  │  Frontend  │  │   Backend   │  │   Database   │        │
│  └──────┬─────┘  └──────┬──────┘  └──────┬───────┘        │
│         │               │                 │                 │
│  ┌──────▼─────┐  ┌──────▼──────┐  ┌──────▼───────┐        │
│  │   Nginx    │  │ BMI Custom  │  │  PostgreSQL  │        │
│  │  Exporter  │  │  Exporter   │  │   Exporter   │        │
│  │   :9113    │  │   :9091     │  │    :9187     │        │
│  └────────────┘  └─────────────┘  └──────────────┘        │
│                                                             │
│  ┌──────────────────────────────────────┐                  │
│  │      Node Exporter (System)          │                  │
│  │            :9100                     │                  │
│  └──────────────────────────────────────┘                  │
│                                                             │
│  ┌──────────────────────────────────────┐                  │
│  │      Promtail (Log Shipper)          │                  │
│  │            :9080                     │                  │
│  └──────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Hardware Requirements
- **Minimum**: 2 vCPU, 4GB RAM, 30GB disk
- **Recommended**: 4 vCPU, 8GB RAM, 50GB disk

### Software Requirements
- **Fresh Ubuntu 22.04 LTS server**
- **Root or sudo access**
- **Internet connectivity**

### Network Requirements

**AWS EC2 Security Group / Firewall Rules:**

| Type | Port | Source | Description |
|------|------|--------|-------------|
| SSH | 22 | Your IP | SSH access |
| Custom TCP | 3001 | 0.0.0.0/0 | Grafana UI |
| Custom TCP | 9090 | 0.0.0.0/0 | Prometheus UI (optional) |
| Custom TCP | 3100 | Application Server IP | Loki (log ingestion) |
| Custom TCP | 9093 | 0.0.0.0/0 | AlertManager UI (optional) |

**Important**: Loki port 3100 should only be accessible from your application server's private IP for security.

## Part 1: Initial Server Setup

### Step 1: Connect to Server

```bash
# Connect via SSH
ssh -i your-key.pem ubuntu@YOUR_MONITORING_SERVER_IP

# Switch to root or use sudo for all commands
sudo su -
```

### Step 2: Update System

```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y
```

### Step 3: Install Essential Tools

```bash
sudo apt install -y wget curl git unzip tar jq net-tools ufw \
    software-properties-common apt-transport-https ca-certificates
```

### Step 4: Detect Server IP Addresses

The monitoring server needs to know its own IP addresses:

```bash
# For AWS EC2 (using IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Get public IP
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: $PUBLIC_IP"

# Get private IP
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP: $PRIVATE_IP"

# For non-AWS servers
hostname -I | awk '{print $1}'
```

### Step 5: Configure Firewall

```bash
# Enable UFW (force yes to avoid prompts)
sudo ufw --force enable

# Allow SSH (IMPORTANT: Do this first!)
sudo ufw allow 22/tcp comment 'SSH'

# Allow Grafana
sudo ufw allow 3001/tcp comment 'Grafana'

# Allow Prometheus (optional, for direct access)
sudo ufw allow 9090/tcp comment 'Prometheus'

# Allow Loki (optional, for direct access)
sudo ufw allow 3100/tcp comment 'Loki'

# Allow AlertManager (optional)
sudo ufw allow 9093/tcp comment 'AlertManager'

# Reload firewall
sudo ufw reload

# Check status
sudo ufw status numbered
```

## Part 2: Install Prometheus

### Step 1: Create Prometheus User

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
```

### Step 2: Create Directories

```bash
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
```

### Step 3: Download and Install Prometheus

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar -xf prometheus-2.48.0.linux-amd64.tar.gz
cd prometheus-2.48.0.linux-amd64

# Move binaries
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Move console files
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries

# Cleanup
cd /tmp
rm -rf prometheus-2.48.0.linux-amd64*

# Verify installation
prometheus --version
promtool --version
```

### Step 4: Create Prometheus Configuration

Create `/etc/prometheus/prometheus.yml`:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Add the following content (replace `APPLICATION_SERVER_IP` with your app server's private IP):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'bmi-health-tracker'
    environment: 'production'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "alert_rules.yml"

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          role: 'monitoring'

  # Node Exporter - Application Server (System Metrics)
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['APPLICATION_SERVER_IP:9100']
        labels:
          server: 'bmi-app-server'
          role: 'system'
          tier: 'infrastructure'

  # PostgreSQL Exporter - Database Layer
  - job_name: 'postgresql'
    static_configs:
      - targets: ['APPLICATION_SERVER_IP:9187']
        labels:
          server: 'bmi-app-server'
          database: 'bmidb'
          role: 'database'
          tier: 'data'

  # Nginx Exporter - Frontend Layer
  - job_name: 'nginx'
    static_configs:
      - targets: ['APPLICATION_SERVER_IP:9113']
        labels:
          server: 'bmi-app-server'
          role: 'webserver'
          tier: 'frontend'

  # BMI Custom Application Exporter - Backend Layer
  - job_name: 'bmi-backend'
    static_configs:
      - targets: ['APPLICATION_SERVER_IP:9091']
        labels:
          server: 'bmi-app-server'
          application: 'bmi-health-tracker'
          role: 'backend'
          tier: 'application'

  # Node Exporter - Monitoring Server (Self-monitoring)
  - job_name: 'node_exporter_monitoring'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          server: 'monitoring-server'
          role: 'monitoring'
```

Save and exit (Ctrl+X, Y, Enter).

Set ownership:

```bash
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
```

### Step 5: Create Alert Rules

Create `/etc/prometheus/alert_rules.yml`:

```bash
sudo nano /etc/prometheus/alert_rules.yml
```

Add the following content:

```yaml
groups:
  - name: system_alerts
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% on {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk space is below 15% on {{ $labels.instance }}"

  - name: application_alerts
    interval: 30s
    rules:
      - alert: ApplicationDown
        expr: up{job="bmi-backend"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "BMI application is down"
          description: "The BMI application exporter is not responding"

      - alert: DatabaseDown
        expr: up{job="postgresql"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL database is down"
          description: "PostgreSQL exporter is not responding"

      - alert: NginxDown
        expr: up{job="nginx"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Nginx web server is down"
          description: "Nginx exporter is not responding"

  - name: database_alerts
    interval: 30s
    rules:
      - alert: DatabaseConnectionsHigh
        expr: pg_stat_database_numbackends > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of database connections"
          description: "PostgreSQL has {{ $value }} active connections"
```

Save and exit (Ctrl+X, Y, Enter).

Set ownership:

```bash
sudo chown prometheus:prometheus /etc/prometheus/alert_rules.yml
```

### Step 6: Validate Configuration

```bash
# Validate Prometheus configuration
promtool check config /etc/prometheus/prometheus.yml

# Validate alert rules
promtool check rules /etc/prometheus/alert_rules.yml
```

Both commands should show "SUCCESS".

### Step 7: Create Prometheus Systemd Service

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Add the following content:

```ini
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --storage.tsdb.retention.time=30d \
  --web.enable-lifecycle

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Key Configuration Options:**
- `--storage.tsdb.retention.time=30d` - Keep 30 days of metrics data
- `--web.enable-lifecycle` - Allow reloading configuration without restart

Save and exit (Ctrl+X, Y, Enter).

### Step 8: Start Prometheus

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable Prometheus to start on boot
sudo systemctl enable prometheus

# Start Prometheus
sudo systemctl start prometheus

# Wait a moment
sleep 3

# Check status
sudo systemctl status prometheus
```

### Step 9: Verify Prometheus

```bash
# Check if Prometheus is running
sudo systemctl is-active prometheus

# View logs
sudo journalctl -u prometheus -n 50 --no-pager

# Test Prometheus API
curl http://localhost:9090/-/healthy

# Access web UI (from your browser)
# http://YOUR_MONITORING_SERVER_PUBLIC_IP:9090
```

  - name: database_alerts
    interval: 30s
    rules:
      - alert: DatabaseConnectionsHigh
        expr: pg_stat_database_numbackends > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of database connections"
          description: "PostgreSQL has {{ $value }} active connections"
```

Save and exit. Set ownership:

```bash
sudo chown prometheus:prometheus /etc/prometheus/alert_rules.yml
```

### Step 6: Create Prometheus Systemd Service

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Add the following content:

```ini
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --storage.tsdb.retention.time=30d \
  --web.enable-lifecycle

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 7: Start Prometheus

```bash
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
```

### Step 8: Verify Prometheus

```bash
# Check if Prometheus is running
curl http://localhost:9090/-/healthy

# You should see "Prometheus is Healthy."
```

## Part 3: Install Node Exporter (Self-Monitoring)

### Step 1: Create Node Exporter User

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

### Step 2: Download and Install

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar -xvf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-1.7.0.linux-amd64*
```

### Step 3: Create Systemd Service

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Add the following content:

```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 4: Start Node Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

## Part 4: Install Grafana

### Step 1: Add Grafana Repository

```bash
# Add GPG key
wget -q -O - https://apt.grafana.com/gpg.key | sudo apt-key add -

# Add repository
sudo add-apt-repository -y "deb https://apt.grafana.com stable main"

# Update package list
sudo apt update
```

### Step 2: Install Grafana

```bash
sudo apt install -y grafana

# Verify installation
grafana-server -v
```

### Step 3: Configure Grafana Port

Grafana will run on port 3001 (not the default 3000):

```bash
# Using sed for automatic configuration
sudo sed -i 's/;http_port = 3000/http_port = 3001/' /etc/grafana/grafana.ini
sudo sed -i 's/http_port = 3000/http_port = 3001/' /etc/grafana/grafana.ini

# Verify the change
sudo grep "http_port" /etc/grafana/grafana.ini | grep -v "^;"
```

**Manual method:**

```bash
sudo nano /etc/grafana/grafana.ini
```

Find the `[server]` section and modify:

```ini
[server]
# The HTTP port to use
http_port = 3001
```

Save and exit (Ctrl+X, Y, Enter).

### Step 4: Setup Datasource Provisioning

Create provisioning directories:

```bash
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo mkdir -p /etc/grafana/provisioning/dashboards
sudo mkdir -p /var/lib/grafana/dashboards
```

#### Create Prometheus Datasource

```bash
sudo tee /etc/grafana/provisioning/datasources/prometheus.yml > /dev/null <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
EOF
```

#### Create Loki Datasource

```bash
sudo tee /etc/grafana/provisioning/datasources/loki.yml > /dev/null <<'EOF'
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    editable: false
EOF
```

### Step 5: Setup Dashboard Provisioning

```bash
sudo tee /etc/grafana/provisioning/dashboards/default.yml > /dev/null <<'EOF'
apiVersion: 1

providers:
  - name: 'BMI Health Tracker'
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
```

### Step 6: Copy Dashboard Files (Optional)

If you have dashboard JSON files in your project:

```bash
# Navigate to your project directory
cd /path/to/your/bmi-project

# Copy dashboards if they exist
if [ -f "monitoring/3-tier-app/dashboards/three-tier-application-dashboard.json" ]; then
    sudo cp monitoring/3-tier-app/dashboards/three-tier-application-dashboard.json /var/lib/grafana/dashboards/
    echo "Copied three-tier application dashboard"
fi

if [ -f "monitoring/3-tier-app/dashboards/loki-logs-dashboard.json" ]; then
    sudo cp monitoring/3-tier-app/dashboards/loki-logs-dashboard.json /var/lib/grafana/dashboards/
    echo "Copied Loki logs dashboard"
fi
```

### Step 7: Set Permissions

```bash
sudo chown -R grafana:grafana /etc/grafana/provisioning
sudo chown -R grafana:grafana /var/lib/grafana/dashboards
```

### Step 8: Start Grafana

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable Grafana to start on boot
sudo systemctl enable grafana-server

# Start Grafana
sudo systemctl start grafana-server

# Wait for Grafana to be ready
sleep 5

# Check status
sudo systemctl status grafana-server
```

### Step 9: Verify Grafana

```bash
# Check if Grafana is running
sudo systemctl is-active grafana-server

# Test Grafana API
curl http://localhost:3001/api/health

# You should see: {"commit":"...","database":"ok","version":"..."}

# Wait for Grafana to fully start and check datasources
sleep 10
curl -s http://localhost:3001/api/datasources | jq
```

### Step 10: Access Grafana

Open your browser and navigate to:

```
http://YOUR_MONITORING_SERVER_PUBLIC_IP:3001
```

**Default credentials:**
- Username: `admin`
- Password: `admin`

You'll be prompted to change the password on first login.

**Verify Datasources:**
- Go to **Configuration** → **Data Sources**
- You should see **Prometheus** (default) and **Loki** already configured

## Part 5: Install Loki (Log Aggregation)

### Step 1: Download and Install Loki

```bash
cd /tmp
wget https://github.com/grafana/loki/releases/download/v2.9.3/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
sudo mv loki-linux-amd64 /usr/local/bin/loki
sudo chmod +x /usr/local/bin/loki
rm loki-linux-amd64.zip

# Verify installation
loki --version
```

### Step 2: Create Loki User and Directories

```bash
sudo useradd --no-create-home --shell /bin/false loki
sudo mkdir -p /etc/loki
sudo mkdir -p /var/lib/loki
sudo chown loki:loki /var/lib/loki
```

### Step 3: Create Loki Configuration

**Automated method:**

```bash
sudo tee /etc/loki/loki-config.yml > /dev/null <<'EOF'
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

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  retention_period: 744h
EOF

# Set ownership
sudo chown loki:loki /etc/loki/loki-config.yml
```

**Manual method:**

```bash
sudo nano /etc/loki/loki-config.yml
```

Copy and paste the above YAML configuration.

**Key Configuration:**
- `retention_period: 744h` - Keep logs for 31 days (744 hours)
- `http_listen_port: 3100` - Loki API port for receiving logs from Promtail
- `storage: filesystem` - Store logs locally on disk

Save and exit (Ctrl+X, Y, Enter).

### Step 4: Create Loki Systemd Service

```bash
sudo nano /etc/systemd/system/loki.service
```

Add the following content:

```ini
[Unit]
Description=Loki Log Aggregation System
After=network.target

[Service]
Type=simple
User=loki
Group=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 5: Start Loki

```bash
sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl start loki
sudo systemctl status loki
```

## Part 6: Install AlertManager

### Step 1: Download and Install AlertManager

```bash
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz
tar -xvf alertmanager-0.26.0.linux-amd64.tar.gz
cd alertmanager-0.26.0.linux-amd64

sudo cp alertmanager /usr/local/bin/
sudo cp amtool /usr/local/bin/

cd /tmp
rm -rf alertmanager-0.26.0.linux-amd64*
```

### Step 2: Create AlertManager User and Directories

```bash
sudo useradd --no-create-home --shell /bin/false alertmanager
sudo mkdir -p /etc/alertmanager
sudo mkdir -p /var/lib/alertmanager
sudo chown alertmanager:alertmanager /etc/alertmanager
sudo chown alertmanager:alertmanager /var/lib/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager
sudo chown alertmanager:alertmanager /usr/local/bin/amtool
```

### Step 3: Create AlertManager Configuration

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

Add the following content (customize email settings):

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'email-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'email-notifications'
      continue: true

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'admin@example.com'
        headers:
          Subject: 'ALERT: {{ .GroupLabels.alertname }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
```

Save and exit. Set ownership:

```bash
sudo chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml
```

### Step 4: Create AlertManager Systemd Service

```bash
sudo nano /etc/systemd/system/alertmanager.service
```

Add the following content:

```ini
[Unit]
Description=Prometheus AlertManager
After=network.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager/
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 5: Start AlertManager

```bash
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager
sudo systemctl status alertmanager
```

## Part 7: Configure Grafana Dashboards

**Note**: Datasources are already configured via provisioning (Part 4). You don't need to manually add them unless provisioning failed.

### Verify Datasources Were Created

```bash
# Wait for Grafana to fully start
sleep 10

# Check datasources via API
curl -s http://localhost:3001/api/datasources | jq

# You should see Prometheus and Loki
```

**Via Web UI:**
1. Log in to Grafana: `http://YOUR_MONITORING_SERVER_IP:3001`
2. Go to **Configuration** (gear icon) → **Data Sources**
3. Verify **Prometheus** (default) and **Loki** are listed

### Import Pre-configured Dashboards

If you have dashboard JSON files in your project (automatically copied in Part 4, Step 6):

**Via Web UI:**
1. Click **Dashboards** → **Browse**
2. Look for folder **"BMI Health Tracker"**
3. Dashboards should be automatically loaded

**Manual Import (if needed):**
1. Click **Dashboards** → **Import**
2. Upload JSON file or paste JSON content
3. Select **Prometheus** as datasource
4. Click **Import**

**Sample Dashboard IDs (from Grafana.com):**
- Node Exporter Full: `1860`
- PostgreSQL: `9628`
- Nginx: `12708`

## Part 8: Verification

### Check All Services

```bash
# Check status of all services
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status loki
sudo systemctl status alertmanager
sudo systemctl status node_exporter

# Quick check if all are running
for service in prometheus grafana-server loki alertmanager node_exporter; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service is running"
    else
        echo "✗ $service is NOT running"
    fi
done
```

### Verify Prometheus Targets

Navigate to: `http://YOUR_MONITORING_SERVER_IP:9090/targets`

**Expected Status:**
- `prometheus` (localhost:9090) - **UP** (green)
- `node_exporter_monitoring` (localhost:9100) - **UP** (green)
- Application server targets - **DOWN** (red) until you configure the application server

### Verify Loki

```bash
# Check Loki health
curl http://localhost:3100/ready

# Should return "ready"

# Check Loki metrics
curl http://localhost:3100/metrics | grep loki
```

### Test AlertManager

```bash
# Check AlertManager status
curl http://localhost:9093/-/healthy

# Should return "Healthy"
```

### Access All Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Grafana** | `http://YOUR_SERVER_IP:3001` | admin / admin |
| **Prometheus** | `http://YOUR_SERVER_IP:9090` | None |
| **AlertManager** | `http://YOUR_SERVER_IP:9093` | None |
| **Loki** | `http://YOUR_SERVER_IP:3100` | None (API only) |

## Service Management

### Start/Stop/Restart Services

```bash
# Start
sudo systemctl start prometheus
sudo systemctl start grafana-server
sudo systemctl start loki
sudo systemctl start alertmanager
sudo systemctl start node_exporter

# Stop
sudo systemctl stop <service-name>

# Restart
sudo systemctl restart <service-name>

# Enable auto-start on boot
sudo systemctl enable <service-name>
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f
sudo journalctl -u loki -f
sudo journalctl -u alertmanager -f

# Last 50 lines
sudo journalctl -u prometheus -n 50 --no-pager

# Logs since 1 hour ago
sudo journalctl -u grafana-server --since "1 hour ago"
```

### Check Service Status

```bash
# Detailed status
sudo systemctl status prometheus

# Just check if active
systemctl is-active prometheus

# Check if enabled on boot
systemctl is-enabled prometheus
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs for errors
sudo journalctl -u <service-name> -n 100 --no-pager

# Check configuration syntax
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alert_rules.yml

# Check file permissions
ls -la /etc/prometheus/
ls -la /var/lib/prometheus/
ls -la /etc/loki/
ls -la /var/lib/loki/
```

### Can't Access Grafana Web UI

```bash
# Check if Grafana is listening on port 3001
sudo netstat -tlnp | grep 3001
sudo lsof -i :3001

# Check firewall
sudo ufw status | grep 3001

# Test locally
curl http://localhost:3001/api/health

# Check Grafana configuration
sudo grep "http_port" /etc/grafana/grafana.ini | grep -v "^;"
```

### Prometheus Can't Scrape Targets

```bash
# Test connectivity from monitoring server to application server
APP_SERVER_IP="YOUR_APPLICATION_SERVER_IP"

curl http://$APP_SERVER_IP:9100/metrics | head -10
curl http://$APP_SERVER_IP:9187/metrics | head -10
curl http://$APP_SERVER_IP:9113/metrics | head -10
curl http://$APP_SERVER_IP:9091/metrics | head -10

# If connection refused, check:
# 1. Application server exporters are running
# 2. Application server firewall allows connections from monitoring server
# 3. AWS security groups allow traffic
```

### Loki Not Receiving Logs

```bash
# Check Loki status
curl http://localhost:3100/ready
curl http://localhost:3100/metrics | grep loki_ingester_streams

# Check Loki logs
sudo journalctl -u loki -n 100 --no-pager

# Test log ingestion (from application server after Promtail is setup)
# This will be tested after setting up the application server
```

### Grafana Datasources Not Working

```bash
# Check if datasources were created
curl -s http://localhost:3001/api/datasources | jq

# Check datasource provisioning files
sudo cat /etc/grafana/provisioning/datasources/prometheus.yml
sudo cat /etc/grafana/provisioning/datasources/loki.yml

# Test datasource connectivity
curl http://localhost:9090/-/healthy
curl http://localhost:3100/ready

# Restart Grafana to reload provisioning
sudo systemctl restart grafana-server
```

## Maintenance

### Update Components

```bash
# Stop services before updating
sudo systemctl stop prometheus grafana-server loki alertmanager

# Download new versions (use same installation steps with new version numbers)
# Update version variables:
PROMETHEUS_VERSION="2.48.0"
LOKI_VERSION="2.9.3"
ALERTMANAGER_VERSION="0.26.0"

# Then re-run installation steps for each component

# Start services after updating
sudo systemctl start prometheus grafana-server loki alertmanager
```

### Backup Configuration

```bash
# Create backup directory
sudo mkdir -p /root/monitoring-backups

# Backup configurations
sudo tar -czf /root/monitoring-backups/monitoring-config-$(date +%Y%m%d).tar.gz \
  /etc/prometheus/ \
  /etc/grafana/grafana.ini \
  /etc/grafana/provisioning/ \
  /etc/loki/ \
  /etc/alertmanager/ \
  /var/lib/grafana/dashboards/

# List backups
ls -lh /root/monitoring-backups/
```

### Clean Up Old Data

```bash
# Check disk usage
du -sh /var/lib/prometheus/
du -sh /var/lib/loki/
du -sh /var/lib/grafana/

# Prometheus will automatically clean up based on retention (30d)
# Loki will automatically clean up based on retention (744h)

# Manual cleanup if needed (use with caution)
# sudo rm -rf /var/lib/prometheus/*
# sudo systemctl restart prometheus
```

## Security Recommendations

1. **Change default passwords** immediately after first login
2. **Configure SSL/TLS** for production use (reverse proxy with nginx/caddy)
3. **Restrict network access** using security groups/firewall rules
4. **Use strong authentication** (consider OAuth, LDAP for Grafana)
5. **Regular backups** of Grafana dashboards and Prometheus data
6. **Monitor the monitoring server** itself (Node Exporter is already installed)
7. **Keep software updated** with latest security patches
8. **Use private IPs** for communication between monitoring and application servers

## Next Steps

1. **Verify all services** are running on monitoring server
2. **Access Grafana** and change default password
3. **Proceed to Application Server Setup**:
   - Run `monitoring/3-tier-app/scripts/setup-application-server.sh` (automated)
   - Or follow `monitoring/3-tier-app/MANUAL_APPLICATION_SERVER_SETUP.md` (manual)
4. **Verify targets in Prometheus** - all should show as UP
5. **Check logs in Grafana** using Loki datasource
6. **Import additional dashboards** as needed
7. **Configure alert notifications** in AlertManager (email, Slack, etc.)
8. **Test alerts** by triggering conditions

## Useful Commands Reference

```bash
# === Service Management ===
sudo systemctl status prometheus grafana-server loki alertmanager node_exporter
sudo systemctl restart <service-name>
sudo journalctl -u <service-name> -f

# === Quick Health Checks ===
curl http://localhost:9090/-/healthy     # Prometheus
curl http://localhost:3001/api/health    # Grafana
curl http://localhost:3100/ready         # Loki
curl http://localhost:9093/-/healthy     # AlertManager
curl http://localhost:9100/metrics | head  # Node Exporter

# === Check Configuration ===
promtool check config /etc/prometheus/prometheus.yml
promtool check rules /etc/prometheus/alert_rules.yml

# === View Targets ===
curl -s http://localhost:9090/api/v1/targets | jq

# === Check Disk Usage ===
du -sh /var/lib/prometheus/
du -sh /var/lib/loki/
df -h

# === Firewall Management ===
sudo ufw status numbered
sudo ufw allow from APP_SERVER_IP to any port 9100 proto tcp
sudo ufw reload
```

---

## Summary

✅ **Installed Components:**
- ✓ Prometheus v2.48.0 - Metrics collection (port 9090, 30-day retention)
- ✓ Grafana (latest) - Visualization (port 3001)
- ✓ Loki v2.9.3 - Log aggregation (port 3100, 31-day retention)
- ✓ AlertManager v0.26.0 - Alert management (port 9093)
- ✓ Node Exporter v1.7.0 - System metrics (port 9100)

✅ **Configuration:**
- ✓ Datasources auto-provisioned (Prometheus & Loki)
- ✓ Dashboard provisioning configured
- ✓ Alert rules configured for system and application monitoring
- ✓ Firewall configured with necessary ports
- ✓ All services enabled for auto-start on boot

✅ **Access Points:**
- **Grafana**: `http://YOUR_SERVER_IP:3001` (admin/admin)
- **Prometheus**: `http://YOUR_SERVER_IP:9090`
- **AlertManager**: `http://YOUR_SERVER_IP:9093`

---

**Monitoring Server Setup Complete!** 🎉

For automated setup, you can also use:
```bash
sudo ./monitoring/3-tier-app/scripts/setup-monitoring-server.sh
```

## Support

- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- Loki Documentation: https://grafana.com/docs/loki/

---

**Setup Complete!** Your monitoring server is now ready to receive metrics from your three-tier application.

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
