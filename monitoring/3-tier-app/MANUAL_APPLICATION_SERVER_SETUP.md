# Three-Tier Application Server - Manual Monitoring Setup Guide

## Overview

This guide walks you through setting up monitoring exporters on your three-tier BMI Health Tracker application server. These exporters will send metrics to your monitoring server.

## What Will Be Installed

This setup includes exporters for all three tiers of your application:

1. **System Metrics**: Node Exporter (CPU, Memory, Disk, Network)
2. **Frontend Tier**: Nginx Exporter (Web server metrics)
3. **Backend Tier**: Custom BMI Application Exporter (API metrics, business metrics)
4. **Database Tier**: PostgreSQL Exporter (Database performance)
5. **Log Collection**: Promtail (Ships logs to Loki)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Application Server (Your 3-Tier App)           │
│                                                             │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐      │
│  │   Frontend   │  │   Backend   │  │   Database   │      │
│  ├──────────────┤  ├─────────────┤  ├──────────────┤      │
│  │    Nginx     │  │  Node.js    │  │  PostgreSQL  │      │
│  │   (Port 80)  │  │  (Port 3000)│  │  (Port 5432) │      │
│  │              │  │             │  │              │      │
│  │  - Static    │  │  - API      │  │  - BMI DB    │      │
│  │    Files     │  │  - Business │  │  - Data      │      │
│  │  - React App │  │    Logic    │  │              │      │
│  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘      │
│         │                 │                 │               │
│         │                 │                 │               │
│  ┌──────▼─────────────────▼─────────────────▼──────┐       │
│  │              Exporters Layer                     │       │
│  ├──────────────────────────────────────────────────┤       │
│  │                                                  │       │
│  │  ┌──────────┐  ┌─────────┐  ┌──────────┐       │       │
│  │  │  Nginx   │  │   BMI   │  │PostgreSQL│       │       │
│  │  │ Exporter │  │ Exporter│  │ Exporter │       │       │
│  │  │  :9113   │  │  :9091  │  │  :9187   │       │       │
│  │  └──────────┘  └─────────┘  └──────────┘       │       │
│  │                                                  │       │
│  │  ┌────────────────────┐  ┌────────────────┐    │       │
│  │  │   Node Exporter    │  │    Promtail    │    │       │
│  │  │      :9100         │  │     :9080      │    │       │
│  │  └────────────────────┘  └────────────────┘    │       │
│  │                                                  │       │
│  └──────────────────────────────────────────────────┘       │
│                         │                                    │
│                         ▼ Sends Metrics/Logs                │
└─────────────────────────┼──────────────────────────────────┘
                          │
                          │
                    ┌─────▼────┐
                    │Monitoring│
                    │  Server  │
                    └──────────┘
```

## Prerequisites

- **BMI Health Tracker application already deployed and running**
- **Ubuntu 22.04 LTS**
- **Root or sudo access**
- **Monitoring server IP address** (both public and private)
- **PostgreSQL database running** with the BMI application
- **Nginx web server running**
- **Node.js backend running**

## Important Information You'll Need

Before starting, gather this information:

1. **Monitoring Server Private IP**: `_____________`
2. **Application Server Private IP**: `_____________`
3. **PostgreSQL Database Name**: `bmidb`
4. **PostgreSQL Username**: `bmi_user`
5. **PostgreSQL Password**: `_____________`

## Part 1: Initial Setup

### Step 1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install Essential Tools

```bash
sudo apt install -y wget curl git unzip tar jq
```

### Step 3: Configure Firewall

Allow the monitoring server to scrape metrics:

```bash
# Allow Prometheus to scrape Node Exporter
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9100 proto tcp

# Allow Prometheus to scrape PostgreSQL Exporter
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9187 proto tcp

# Allow Prometheus to scrape Nginx Exporter
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9113 proto tcp

# Allow Prometheus to scrape BMI Application Exporter
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9091 proto tcp

# Reload firewall
sudo ufw reload
```

## Part 2: Install Node Exporter (System Metrics)

### Step 1: Create Node Exporter User

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

### Step 2: Download and Install Node Exporter

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

Save and exit (Ctrl+X, Y, Enter).

### Step 4: Start Node Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

### Step 5: Verify Node Exporter

```bash
curl http://localhost:9100/metrics | head -20
```

You should see system metrics.

## Part 3: Install PostgreSQL Exporter (Database Metrics)

### Step 1: Download and Install PostgreSQL Exporter

```bash
cd /tmp
wget https://github.com/prometheus-community/postgres_exporter/releases/download/v0.15.0/postgres_exporter-0.15.0.linux-amd64.tar.gz
tar -xvf postgres_exporter-0.15.0.linux-amd64.tar.gz
sudo cp postgres_exporter-0.15.0.linux-amd64/postgres_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/postgres_exporter
rm -rf postgres_exporter-0.15.0.linux-amd64*
```

### Step 2: Create PostgreSQL User

```bash
sudo useradd --no-create-home --shell /bin/false postgres_exporter
```

### Step 3: Create PostgreSQL Monitoring User

Connect to PostgreSQL and create a monitoring user:

```bash
sudo -u postgres psql
```

Run these SQL commands:

```sql
-- Create monitoring user
CREATE USER postgres_exporter WITH PASSWORD 'secure_password_here';

-- Grant necessary permissions
ALTER USER postgres_exporter SET SEARCH_PATH TO postgres_exporter,pg_catalog;

-- Grant connection permission
GRANT CONNECT ON DATABASE bmidb TO postgres_exporter;

-- Grant usage on schema
\c bmidb
GRANT USAGE ON SCHEMA public TO postgres_exporter;

-- Grant select on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres_exporter;

-- Grant select on pg_stat views
GRANT pg_monitor TO postgres_exporter;

-- Exit
\q
```

### Step 4: Create Environment File

```bash
sudo nano /etc/default/postgres_exporter
```

Add the following (replace with your actual password):

```bash
DATA_SOURCE_NAME="postgresql://postgres_exporter:secure_password_here@localhost:5432/bmidb?sslmode=disable"
```

Save and exit.

Set permissions:

```bash
sudo chown postgres_exporter:postgres_exporter /etc/default/postgres_exporter
sudo chmod 600 /etc/default/postgres_exporter
```

### Step 5: Create Systemd Service

```bash
sudo nano /etc/systemd/system/postgres_exporter.service
```

Add the following content:

```ini
[Unit]
Description=PostgreSQL Exporter
After=network.target

[Service]
Type=simple
User=postgres_exporter
Group=postgres_exporter
EnvironmentFile=/etc/default/postgres_exporter
ExecStart=/usr/local/bin/postgres_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 6: Start PostgreSQL Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable postgres_exporter
sudo systemctl start postgres_exporter
sudo systemctl status postgres_exporter
```

### Step 7: Verify PostgreSQL Exporter

```bash
curl http://localhost:9187/metrics | grep pg_
```

You should see database metrics.

## Part 4: Install Nginx Exporter (Frontend Metrics)

### Step 1: Enable Nginx Stub Status

Edit your Nginx configuration:

```bash
sudo nano /etc/nginx/sites-available/bmi-health-tracker
```

Add the following location block inside your server block:

```nginx
server {
    # ... existing configuration ...

    # Nginx status endpoint for monitoring
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow YOUR_MONITORING_SERVER_IP;
        deny all;
    }

    # ... rest of configuration ...
}
```

Save and exit.

Test and reload Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Verify the status endpoint:

```bash
curl http://localhost/nginx_status
```

You should see output like:

```
Active connections: 2
server accepts handled requests
 10 10 15
Reading: 0 Writing: 1 Waiting: 1
```

### Step 2: Download and Install Nginx Exporter

```bash
cd /tmp
wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.11.0/nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
tar -xvf nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
sudo mv nginx-prometheus-exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/nginx-prometheus-exporter
rm nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
```

### Step 3: Create Nginx Exporter User

```bash
sudo useradd --no-create-home --shell /bin/false nginx_exporter
```

### Step 4: Create Systemd Service

```bash
sudo nano /etc/systemd/system/nginx_exporter.service
```

Add the following content:

```ini
[Unit]
Description=Nginx Prometheus Exporter
After=network.target

[Service]
Type=simple
User=nginx_exporter
Group=nginx_exporter
ExecStart=/usr/local/bin/nginx-prometheus-exporter \
  -nginx.scrape-uri=http://localhost/nginx_status
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 5: Start Nginx Exporter

```bash
sudo systemctl daemon-reload
sudo systemctl enable nginx_exporter
sudo systemctl start nginx_exporter
sudo systemctl status nginx_exporter
```

### Step 6: Verify Nginx Exporter

```bash
curl http://localhost:9113/metrics | grep nginx
```

You should see Nginx metrics.

## Part 5: Install BMI Custom Application Exporter (Backend Metrics)

### Step 1: Navigate to Project Directory

```bash
cd /path/to/your/bmi-project
```

### Step 2: Install PM2 (if not already installed)

```bash
sudo npm install -g pm2
```

### Step 3: Create Custom Exporter

The custom exporter is already in your project at `monitoring/exporters/bmi-app-exporter/`. We need to configure it.

Navigate to the exporter directory:

```bash
cd monitoring/exporters/bmi-app-exporter
```

### Step 4: Install Dependencies

```bash
npm install
```

### Step 5: Configure Environment

Create a `.env` file in the backend directory (if not exists) or verify it exists:

```bash
cd /path/to/your/bmi-project/backend
nano .env
```

Ensure it contains:

```bash
# Database connection
DATABASE_URL=postgresql://bmi_user:YOUR_PASSWORD@localhost:5432/bmidb

# Exporter port
EXPORTER_PORT=9091

# Application settings
PORT=3000
NODE_ENV=production
```

Save and exit.

### Step 6: Update PM2 Ecosystem Config

The exporter comes with an ecosystem config. Navigate to exporter directory:

```bash
cd /path/to/your/bmi-project/monitoring/exporters/bmi-app-exporter
```

Check the `ecosystem.config.js`:

```bash
cat ecosystem.config.js
```

It should look like:

```javascript
module.exports = {
  apps: [{
    name: 'bmi-app-exporter',
    script: './exporter.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '200M',
    env: {
      NODE_ENV: 'production',
      EXPORTER_PORT: 9091
    },
    error_file: '/var/log/pm2/bmi-app-exporter-error.log',
    out_file: '/var/log/pm2/bmi-app-exporter-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
```

### Step 7: Create Log Directory

```bash
sudo mkdir -p /var/log/pm2
sudo chown -R $USER:$USER /var/log/pm2
```

### Step 8: Start the Exporter with PM2

```bash
cd /path/to/your/bmi-project/monitoring/exporters/bmi-app-exporter
pm2 start ecosystem.config.js
pm2 save
```

### Step 9: Configure PM2 to Start on Boot

```bash
pm2 startup systemd
# Follow the command it outputs, usually something like:
# sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u YOUR_USER --hp /home/YOUR_USER
```

### Step 10: Verify BMI Application Exporter

```bash
curl http://localhost:9091/metrics | head -30
```

You should see custom application metrics like:

```
# HELP bmi_measurements_total Total number of measurements stored in database
# TYPE bmi_measurements_total gauge
bmi_measurements_total 150

# HELP bmi_average_value Average BMI value of all measurements
# TYPE bmi_average_value gauge
bmi_average_value 24.5
```

Check PM2 status:

```bash
pm2 status
pm2 logs bmi-app-exporter --lines 50
```

## Part 6: Install Promtail (Log Shipping)

### Step 1: Download and Install Promtail

```bash
cd /tmp
wget https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
rm promtail-linux-amd64.zip
```

### Step 2: Create Promtail User and Directories

```bash
sudo useradd --no-create-home --shell /bin/false promtail
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail
sudo chown promtail:promtail /var/lib/promtail
```

### Step 3: Add Promtail to Log Groups

```bash
sudo usermod -aG adm promtail
sudo usermod -aG systemd-journal promtail
```

### Step 4: Create Promtail Configuration

```bash
sudo nano /etc/promtail/promtail-config.yml
```

Add the following (replace `MONITORING_SERVER_IP` with your monitoring server's private IP):

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://MONITORING_SERVER_IP:3100/loki/api/v1/push

scrape_configs:
  # System logs
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          server: bmi-app-server
          __path__: /var/log/*.log

  # Nginx access logs
  - job_name: nginx_access
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx_access
          server: bmi-app-server
          tier: frontend
          __path__: /var/log/nginx/access.log

  # Nginx error logs
  - job_name: nginx_error
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx_error
          server: bmi-app-server
          tier: frontend
          __path__: /var/log/nginx/error.log

  # PostgreSQL logs
  - job_name: postgresql
    static_configs:
      - targets:
          - localhost
        labels:
          job: postgresql
          server: bmi-app-server
          tier: database
          __path__: /var/log/postgresql/*.log

  # PM2 application logs
  - job_name: pm2_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: bmi_backend
          server: bmi-app-server
          tier: backend
          __path__: /var/log/pm2/*.log
```

Save and exit.

Set ownership:

```bash
sudo chown promtail:promtail /etc/promtail/promtail-config.yml
```

### Step 5: Create Systemd Service

```bash
sudo nano /etc/systemd/system/promtail.service
```

Add the following content:

```ini
[Unit]
Description=Promtail Log Shipper
After=network.target

[Service]
Type=simple
User=promtail
Group=promtail
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

### Step 6: Start Promtail

```bash
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail
sudo systemctl status promtail
```

### Step 7: Verify Promtail

```bash
# Check if Promtail is running
curl http://localhost:9080/ready

# Check Promtail metrics
curl http://localhost:9080/metrics | grep promtail
```

## Part 7: Verification and Testing

### Step 1: Check All Exporters

```bash
# Node Exporter
curl http://localhost:9100/metrics | head -10

# PostgreSQL Exporter
curl http://localhost:9187/metrics | grep pg_ | head -10

# Nginx Exporter
curl http://localhost:9113/metrics | grep nginx | head -10

# BMI Application Exporter
curl http://localhost:9091/metrics | grep bmi | head -10

# Promtail
curl http://localhost:9080/ready
```

### Step 2: Check Service Status

```bash
sudo systemctl status node_exporter
sudo systemctl status postgres_exporter
sudo systemctl status nginx_exporter
pm2 status
sudo systemctl status promtail
```

### Step 3: Test from Monitoring Server

From your **monitoring server**, test connectivity:

```bash
# Replace APPLICATION_SERVER_PRIVATE_IP with your app server's private IP

# Test Node Exporter
curl http://APPLICATION_SERVER_PRIVATE_IP:9100/metrics | head -10

# Test PostgreSQL Exporter
curl http://APPLICATION_SERVER_PRIVATE_IP:9187/metrics | grep pg_ | head -10

# Test Nginx Exporter
curl http://APPLICATION_SERVER_PRIVATE_IP:9113/metrics | grep nginx | head -10

# Test BMI Application Exporter
curl http://APPLICATION_SERVER_PRIVATE_IP:9091/metrics | grep bmi | head -10
```

All commands should return metrics successfully.

### Step 4: Verify in Prometheus

On your monitoring server, go to Prometheus:

```
http://MONITORING_SERVER_PUBLIC_IP:9090/targets
```

All targets for your application server should now show as **UP** and green.

### Step 5: Create Test Data

To verify metrics are being collected, create some test measurements in your BMI application:

```bash
# Create a test measurement via API
curl -X POST http://localhost:3000/api/measurements \
  -H "Content-Type: application/json" \
  -d '{
    "weightKg": 70,
    "heightCm": 170,
    "age": 30,
    "sex": "male",
    "activity": "moderate"
  }'
```

Then check the exporter:

```bash
curl http://localhost:9091/metrics | grep bmi_measurements_total
```

You should see the count increase.

## Part 8: PM2 Application Management

### View All PM2 Processes

```bash
pm2 list
```

You should see your backend application and the exporter running.

### View Logs

```bash
# Backend logs
pm2 logs bmi-backend --lines 50

# Exporter logs
pm2 logs bmi-app-exporter --lines 50
```

### Restart Services

```bash
# Restart backend
pm2 restart bmi-backend

# Restart exporter
pm2 restart bmi-app-exporter

# Restart all
pm2 restart all
```

### Stop/Start Services

```bash
# Stop
pm2 stop bmi-app-exporter

# Start
pm2 start bmi-app-exporter
```

## Troubleshooting

### Exporter Not Responding

```bash
# Check service status
sudo systemctl status node_exporter
sudo systemctl status postgres_exporter
sudo systemctl status nginx_exporter
pm2 status

# Check logs
sudo journalctl -u node_exporter -f
sudo journalctl -u postgres_exporter -f
sudo journalctl -u nginx_exporter -f
pm2 logs bmi-app-exporter --lines 100
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
psql -U postgres_exporter -d bmidb -h localhost -c "SELECT 1;"

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

### Firewall Issues

```bash
# Check UFW status
sudo ufw status numbered

# Test connectivity from monitoring server
telnet APPLICATION_SERVER_IP 9100
telnet APPLICATION_SERVER_IP 9187
telnet APPLICATION_SERVER_IP 9113
telnet APPLICATION_SERVER_IP 9091
```

### Port Already in Use

```bash
# Check what's using a port
sudo netstat -tlnp | grep 9100
sudo lsof -i :9100

# Kill the process if needed
sudo kill -9 PID
```

### PM2 Exporter Issues

```bash
# Delete and restart
pm2 delete bmi-app-exporter
cd /path/to/your/bmi-project/monitoring/exporters/bmi-app-exporter
pm2 start ecosystem.config.js
pm2 save

# Check environment variables
pm2 env bmi-app-exporter
```

## Maintenance

### Update Exporters

```bash
# Stop services
sudo systemctl stop node_exporter
sudo systemctl stop postgres_exporter
sudo systemctl stop nginx_exporter
pm2 stop bmi-app-exporter

# Download new versions (same process as installation)
# Then restart services

# Start services
sudo systemctl start node_exporter
sudo systemctl start postgres_exporter
sudo systemctl start nginx_exporter
pm2 start bmi-app-exporter
```

### Backup Configuration

```bash
# Backup all exporter configs
sudo tar -czf exporter-configs-backup-$(date +%Y%m%d).tar.gz \
  /etc/systemd/system/node_exporter.service \
  /etc/systemd/system/postgres_exporter.service \
  /etc/systemd/system/nginx_exporter.service \
  /etc/default/postgres_exporter \
  /etc/promtail/promtail-config.yml \
  /path/to/your/bmi-project/monitoring/exporters/bmi-app-exporter/ecosystem.config.js
```

## Security Best Practices

1. **Use strong passwords** for PostgreSQL monitoring user
2. **Restrict firewall rules** to only monitoring server IP
3. **Regular updates** of exporters and dependencies
4. **Monitor exporter logs** for unusual activity
5. **Secure .env files** with proper permissions
6. **Use private IPs** for communication between servers

## Performance Considerations

- **Node Exporter**: Minimal impact, collects system metrics efficiently
- **PostgreSQL Exporter**: Runs read-only queries, minimal impact
- **Nginx Exporter**: Very lightweight, negligible impact
- **BMI Custom Exporter**: Runs queries every 15 seconds, optimized
- **Promtail**: Tails log files, minimal CPU usage

## Next Steps

1. **Access Grafana** on your monitoring server
2. **Import pre-configured dashboards**
3. **Verify all metrics** are being collected
4. **Set up alerts** for critical conditions
5. **Test alert notifications**

## Useful Commands Reference

```bash
# Check all services
sudo systemctl status node_exporter postgres_exporter nginx_exporter promtail
pm2 status

# View all metrics
curl localhost:9100/metrics | less  # Node Exporter
curl localhost:9187/metrics | less  # PostgreSQL
curl localhost:9113/metrics | less  # Nginx
curl localhost:9091/metrics | less  # BMI App

# Restart all exporters
sudo systemctl restart node_exporter postgres_exporter nginx_exporter promtail
pm2 restart bmi-app-exporter

# Check connectivity
curl -I http://MONITORING_SERVER_IP:9090
```

---

**Setup Complete!** Your application server is now fully instrumented and sending metrics to your monitoring server. Proceed to Grafana to visualize your metrics!
