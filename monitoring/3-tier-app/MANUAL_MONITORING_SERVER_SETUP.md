# Three-Tier Application Monitoring Server - Manual Setup Guide

## Overview

This guide walks you through setting up a dedicated monitoring server to monitor your three-tier BMI Health Tracker application. The monitoring server will collect metrics from:

- **Frontend Layer**: Nginx web server metrics
- **Backend Layer**: Node.js application metrics, API performance
- **Database Layer**: PostgreSQL database metrics
- **System Layer**: CPU, memory, disk, network metrics

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

- **Fresh Ubuntu 22.04 LTS server** (Minimum: 2 vCPU, 4GB RAM, 30GB disk)
- **Root or sudo access**
- **Security group/firewall configured** to allow:
  - SSH (22) from your IP
  - Grafana (3001) from your IP
  - Prometheus (9090) from your IP (optional, for direct access)

## Part 1: Initial Server Setup

### Step 1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install Essential Tools

```bash
sudo apt install -y wget curl git unzip tar jq net-tools ufw
```

### Step 3: Configure Firewall

```bash
# Enable UFW
sudo ufw --force enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow Grafana
sudo ufw allow 3001/tcp

# Allow Prometheus (optional)
sudo ufw allow 9090/tcp

# Allow Loki (optional)
sudo ufw allow 3100/tcp

# Reload firewall
sudo ufw reload

# Check status
sudo ufw status
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
tar -xvf prometheus-2.48.0.linux-amd64.tar.gz
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
sudo apt install -y software-properties-common
sudo add-apt-repository "deb https://apt.grafana.com stable main"
wget -q -O - https://apt.grafana.com/gpg.key | sudo apt-key add -
sudo apt update
```

### Step 2: Install Grafana

```bash
sudo apt install -y grafana
```

### Step 3: Configure Grafana Port

Edit Grafana configuration to use port 3001:

```bash
sudo nano /etc/grafana/grafana.ini
```

Find the `[server]` section and modify:

```ini
[server]
http_port = 3001
```

Save and exit.

### Step 4: Start Grafana

```bash
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```

### Step 5: Access Grafana

Open your browser and navigate to:

```
http://YOUR_MONITORING_SERVER_PUBLIC_IP:3001
```

Default credentials:
- Username: `admin`
- Password: `admin`

You'll be prompted to change the password on first login.

## Part 5: Install Loki (Log Aggregation)

### Step 1: Download and Install Loki

```bash
cd /tmp
wget https://github.com/grafana/loki/releases/download/v2.9.3/loki-linux-amd64.zip
unzip loki-linux-amd64.zip
sudo mv loki-linux-amd64 /usr/local/bin/loki
sudo chmod +x /usr/local/bin/loki
rm loki-linux-amd64.zip
```

### Step 2: Create Loki User and Directories

```bash
sudo useradd --no-create-home --shell /bin/false loki
sudo mkdir -p /etc/loki
sudo mkdir -p /var/lib/loki
sudo chown loki:loki /var/lib/loki
```

### Step 3: Create Loki Configuration

```bash
sudo nano /etc/loki/loki-config.yml
```

Add the following content:

```yaml
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
  retention_period: 744h  # 31 days
```

Save and exit. Set ownership:

```bash
sudo chown loki:loki /etc/loki/loki-config.yml
```

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

### Step 1: Add Prometheus Data Source

1. Log in to Grafana: `http://YOUR_MONITORING_SERVER_IP:3001`
2. Click on Configuration (gear icon) → Data Sources
3. Click "Add data source"
4. Select "Prometheus"
5. Configure:
   - Name: `Prometheus`
   - URL: `http://localhost:9090`
   - Access: `Server (default)`
6. Click "Save & Test"

### Step 2: Add Loki Data Source

1. Click "Add data source" again
2. Select "Loki"
3. Configure:
   - Name: `Loki`
   - URL: `http://localhost:3100`
4. Click "Save & Test"

### Step 3: Import Pre-configured Dashboards

The dashboard JSON files will be provided in the `dashboards` folder. You can import them via:

1. Click on Dashboards (four squares icon) → Import
2. Upload the JSON file or paste the JSON content
3. Select the Prometheus data source
4. Click "Import"

## Part 8: Verification

### Check All Services

```bash
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status loki
sudo systemctl status alertmanager
sudo systemctl status node_exporter
```

### Verify Prometheus Targets

Navigate to: `http://YOUR_MONITORING_SERVER_IP:9090/targets`

You should see all configured targets. The monitoring server targets should be UP. Application server targets will show as DOWN until you set up the application server.

### Access Points

- **Grafana**: `http://YOUR_MONITORING_SERVER_IP:3001`
- **Prometheus**: `http://YOUR_MONITORING_SERVER_IP:9090`
- **AlertManager**: `http://YOUR_MONITORING_SERVER_IP:9093`
- **Loki**: `http://YOUR_MONITORING_SERVER_IP:3100`

## Security Recommendations

1. **Change default passwords** immediately
2. **Configure SSL/TLS** for production use
3. **Restrict access** using security groups/firewall rules
4. **Use strong authentication** (consider OAuth, LDAP)
5. **Regular backups** of Grafana dashboards and Prometheus data
6. **Monitor the monitoring server** itself

## Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f
sudo journalctl -u loki -f
```

### Can't access Grafana

```bash
# Check if Grafana is listening
sudo netstat -tlnp | grep 3001

# Check firewall
sudo ufw status
```

### Prometheus can't scrape targets

```bash
# Test connectivity from monitoring server
curl http://APPLICATION_SERVER_IP:9100/metrics
curl http://APPLICATION_SERVER_IP:9187/metrics
curl http://APPLICATION_SERVER_IP:9113/metrics
curl http://APPLICATION_SERVER_IP:9091/metrics
```

## Next Steps

Proceed to the **Application Server Setup Guide** to install and configure all exporters on your application server.

## Support

- Prometheus Documentation: https://prometheus.io/docs/
- Grafana Documentation: https://grafana.com/docs/
- Loki Documentation: https://grafana.com/docs/loki/

---

**Setup Complete!** Your monitoring server is now ready to receive metrics from your three-tier application.
