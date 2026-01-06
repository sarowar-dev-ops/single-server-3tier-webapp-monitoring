# Three-Tier Application Server - Manual Monitoring Setup Guide

## Overview

This comprehensive guide walks you through manually setting up monitoring exporters on your three-tier BMI Health Tracker application server. These exporters will send metrics and logs to your centralized monitoring server.

**Companion to**: `monitoring/3-tier-app/scripts/setup-application-server.sh` (automated version)

## What Will Be Installed

This setup includes exporters for all three tiers of your application:

1. **System Metrics**: Node Exporter v1.7.0 (CPU, Memory, Disk, Network)
2. **Frontend Tier**: Nginx Exporter v0.11.0 (Web server metrics)
3. **Backend Tier**: 
   - BMI Backend as systemd service (with proper logging)
   - Custom BMI Application Exporter v1.0 via PM2 (API metrics, business metrics)
4. **Database Tier**: PostgreSQL Exporter v0.15.0 (Database performance)
5. **Log Collection**: Promtail v2.9.3 (Ships logs to Loki)

## Key Features

- **Fully idempotent**: Safe to run multiple times
- **Automatic dependency installation**: Node.js, PM2, PostgreSQL, Nginx (if missing)
- **Backend runs as systemd service**: Logs to `/var/log/bmi-backend.log`
- **Secure**: Firewall rules restrict access to monitoring server only
- **Comprehensive logging**: All tiers ship logs to Loki

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

### Required
- **Ubuntu 22.04 LTS**
- **Root or sudo access**
- **Monitoring server IP address** (both public and private)
- **BMI Health Tracker application code deployed** (on the server)

### Auto-Installed if Missing
The setup process will automatically install these if not present:
- **Node.js v20.x LTS** (required for BMI exporter)
- **PM2** (process manager for BMI exporter)
- **PostgreSQL** (if not installed, will be installed and configured)
- **Nginx** (if not installed, will be installed and configured)

## Important Information You'll Need

Before starting, gather this information:

1. **Monitoring Server Private IP**: `_____________`
2. **Application Server Private IP**: `_____________`
3. **PostgreSQL Database Name**: `bmidb`
4. **PostgreSQL Username**: `bmi_user`
5. **PostgreSQL Password**: `_____________`

## Part 1: Initial Setup

### Step 1: Connect and Prepare

```bash
# Connect to your application server
ssh -i your-key.pem ubuntu@YOUR_APPLICATION_SERVER_IP

# Switch to root
sudo su -

# Or run commands with sudo
```

### Step 2: Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### Step 3: Install Essential Tools

```bash
sudo apt install -y wget curl git unzip tar jq net-tools
```

### Step 4: Detect Server IP Addresses

The server will automatically detect its IP addresses, but you can verify manually:

```bash
# Get private IP (AWS EC2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP: $PRIVATE_IP"

# Get public IP (AWS EC2)
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: $PUBLIC_IP"

# For non-AWS servers:
hostname -I | awk '{print $1}'
```

### Step 5: Install Node.js (if not present)

Check if Node.js is installed:

```bash
node --version
```

If not installed, install Node.js 20.x LTS:

```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -

# Install Node.js
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

### Step 6: Install PM2 (if not present)

```bash
# Install PM2 globally
sudo npm install -g pm2

# Verify installation
pm2 --version
```

### Step 7: Check/Install PostgreSQL

Check if PostgreSQL is installed:

```bash
psql --version
```

If not installed:

```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify
sudo systemctl status postgresql
```

### Step 8: Check/Install Nginx

Check if Nginx is installed:

```bash
nginx -v
```

If not installed:

```bash
# Install Nginx
sudo apt install -y nginx

# Start and enable service
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify
sudo systemctl status nginx
```

### Step 9: Configure Firewall

**Important**: Replace `MONITORING_SERVER_PRIVATE_IP` with your actual monitoring server's private IP address.

```bash
# Set your monitoring server IP
MONITORING_SERVER_IP="YOUR_MONITORING_SERVER_PRIVATE_IP"

# Allow Prometheus to scrape Node Exporter
sudo ufw allow from $MONITORING_SERVER_IP to any port 9100 proto tcp comment 'Node Exporter'

# Allow Prometheus to scrape PostgreSQL Exporter
sudo ufw allow from $MONITORING_SERVER_IP to any port 9187 proto tcp comment 'PostgreSQL Exporter'

# Allow Prometheus to scrape Nginx Exporter
sudo ufw allow from $MONITORING_SERVER_IP to any port 9113 proto tcp comment 'Nginx Exporter'

# Allow Prometheus to scrape BMI Application Exporter
sudo ufw allow from $MONITORING_SERVER_IP to any port 9091 proto tcp comment 'BMI App Exporter'

# Reload firewall
sudo ufw reload

# Verify rules
sudo ufw status numbered
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

Connect to PostgreSQL and create a monitoring user with a secure password:

```bash
# Generate a secure password
PG_EXPORTER_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
echo "Generated password: $PG_EXPORTER_PASSWORD"
# IMPORTANT: Save this password somewhere safe!

# Create monitoring user in PostgreSQL
sudo -u postgres psql -d bmidb <<EOF
-- Create monitoring user if not exists
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'postgres_exporter') THEN
      CREATE USER postgres_exporter WITH PASSWORD '$PG_EXPORTER_PASSWORD';
   END IF;
END
\$\$;

-- Grant necessary permissions
ALTER USER postgres_exporter SET SEARCH_PATH TO postgres_exporter,pg_catalog;
GRANT CONNECT ON DATABASE bmidb TO postgres_exporter;
GRANT USAGE ON SCHEMA public TO postgres_exporter;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres_exporter;
GRANT pg_monitor TO postgres_exporter;
EOF
```

**Alternative manual method:**

```bash
sudo -u postgres psql -d bmidb
```

Then run these SQL commands:

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

### Step 5: Enable Nginx Stub Status

Find your Nginx configuration file:

```bash
# Check if BMI-specific config exists
if [ -f "/etc/nginx/sites-available/bmi-health-tracker" ]; then
    NGINX_CONFIG="/etc/nginx/sites-available/bmi-health-tracker"
elif [ -f "/etc/nginx/sites-available/default" ]; then
    NGINX_CONFIG="/etc/nginx/sites-available/default"
else
    echo "Nginx config not found!"
    exit 1
fi

echo "Using Nginx config: $NGINX_CONFIG"

# Backup the configuration
sudo cp $NGINX_CONFIG ${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)
```

Edit your Nginx configuration:

```bash
sudo nano $NGINX_CONFIG
```

Add the following location block inside your server block (before the last closing brace):

```nginx
server {
    # ... existing configuration ...

    # Nginx status endpoint for monitoring
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow YOUR_MONITORING_SERVER_IP;  # Replace with actual IP
        deny all;
    }

    # ... rest of configuration ...
}
```

**Automated method:**

```bash
# Set your monitoring server IP
MONITORING_SERVER_IP="YOUR_MONITORING_SERVER_PRIVATE_IP"

# Add stub_status if not already present
if ! sudo grep -q "stub_status" "$NGINX_CONFIG"; then
    echo "Adding stub_status configuration..."
    sudo sed -i '/^}$/i \    # Nginx status endpoint for monitoring\n    location /nginx_status {\n        stub_status on;\n        access_log off;\n        allow 127.0.0.1;\n        allow '"$MONITORING_SERVER_IP"';\n        deny all;\n    }\n' "$NGINX_CONFIG"
else
    echo "stub_status already configured"
fi
```

Test and reload Nginx:

```bash
# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Step 6: Verify Nginx Status Endpoint

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
tar -xf nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
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

## Part 4.5: Setup BMI Backend Application Service

This section sets up your BMI backend application to run as a systemd service (not PM2). This ensures proper logging to `/var/log/bmi-backend.log` which will be shipped to Loki.

### Step 1: Verify Backend Directory

```bash
# Set your project directory
PROJECT_ROOT="/path/to/your/bmi-project"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Check if backend exists
if [ ! -d "$BACKEND_DIR" ]; then
    echo "Backend directory not found: $BACKEND_DIR"
    echo "Please update PROJECT_ROOT variable"
    exit 1
fi

echo "Backend directory found: $BACKEND_DIR"
```

### Step 2: Stop Any Existing Backend Processes

```bash
# Check for existing backend process
BACKEND_PID=$(pgrep -f "node.*backend/src/server.js" || true)

if [ -n "$BACKEND_PID" ]; then
    echo "Found existing backend process (PID: $BACKEND_PID). Stopping..."
    sudo kill $BACKEND_PID 2>/dev/null || true
    sleep 2
fi

# Check PM2 for backend
if pm2 describe bmi-backend &>/dev/null; then
    echo "Found backend in PM2, stopping..."
    pm2 delete bmi-backend
fi
```

### Step 3: Install Backend Dependencies

```bash
cd $BACKEND_DIR

# Set proper ownership (run as your regular user)
sudo chown -R $USER:$USER $BACKEND_DIR

# Install dependencies
npm install
```

### Step 4: Configure Backend Environment

Check if `.env` file exists:

```bash
ls -la $BACKEND_DIR/.env
```

If not found, create it:

```bash
# Create from template if it exists
if [ -f "$BACKEND_DIR/.env.example" ]; then
    cp $BACKEND_DIR/.env.example $BACKEND_DIR/.env
else
    # Create minimal .env
    cat > $BACKEND_DIR/.env <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bmidb
DB_USER=bmi_user
DB_PASSWORD=your_password_here
PORT=3000
NODE_ENV=production
EOF
fi

# Update database credentials if needed
nano $BACKEND_DIR/.env
```

### Step 5: Create Backend Log File

```bash
# Create log file with proper permissions
sudo touch /var/log/bmi-backend.log
sudo chown $USER:$USER /var/log/bmi-backend.log
```

### Step 6: Detect Node.js Path

The systemd service needs the full path to Node.js:

```bash
# Find Node.js path
NODE_PATH=$(which node)
echo "Node.js path: $NODE_PATH"

# If using nvm, Node.js might be in your home directory
# Example: /home/ubuntu/.nvm/versions/node/v20.11.0/bin/node
```

### Step 7: Create Backend Systemd Service

```bash
# Get current user
CURRENT_USER=$USER

# Create systemd service
sudo tee /etc/systemd/system/bmi-backend.service > /dev/null <<EOF
[Unit]
Description=BMI Health Tracker Backend API
After=network.target postgresql.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$BACKEND_DIR
Environment=NODE_ENV=production
ExecStart=$NODE_PATH src/server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/bmi-backend.log
StandardError=append:/var/log/bmi-backend.log

[Install]
WantedBy=multi-user.target
EOF
```

### Step 8: Start Backend Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable bmi-backend

# Start service
sudo systemctl start bmi-backend

# Wait a few seconds
sleep 3

# Check status
sudo systemctl status bmi-backend
```

### Step 9: Verify Backend is Running

```bash
# Check service status
sudo systemctl is-active bmi-backend

# View logs
sudo tail -f /var/log/bmi-backend.log
# Press Ctrl+C to exit

# Test API
curl http://localhost:3000/api/health || curl http://localhost:3000/

# If API responds, backend is working!
```

### Troubleshooting Backend Service

If the service fails to start:

```bash
# View recent logs
sudo journalctl -u bmi-backend -n 50 --no-pager

# Check if port is in use
sudo netstat -tlnp | grep 3000

# Check environment variables
sudo systemctl show bmi-backend --property=Environment

# Manually test the backend
cd $BACKEND_DIR
node src/server.js
# Press Ctrl+C to stop
```

## Part 5: Install BMI Custom Application Exporter (Backend Metrics)

**Important**: The BMI custom exporter runs under PM2 as a separate process from the backend. The backend itself runs as a systemd service (configured in Part 4.5).

### Step 1: Navigate to Project Directory

```bash
# Set your project path
PROJECT_ROOT="/path/to/your/bmi-project"
EXPORTER_DIR="$PROJECT_ROOT/monitoring/exporters/bmi-app-exporter"

# Verify exporter exists
if [ ! -d "$EXPORTER_DIR" ]; then
    echo "Exporter directory not found: $EXPORTER_DIR"
    exit 1
fi

cd $EXPORTER_DIR
```

### Step 2: PM2 Should Already Be Installed

Verify PM2 is installed (from Part 1, Step 6):

```bash
pm2 --version
```

If not installed:

```bash
sudo npm install -g pm2
```

### Step 3: Fix Directory Ownership

```bash
# Ensure proper ownership for npm install
sudo chown -R $USER:$USER $EXPORTER_DIR

# If project is in /root, fix entire project
if [[ "$PROJECT_ROOT" == /root/* ]]; then
    sudo chown -R $USER:$USER $PROJECT_ROOT
fi
```

### Step 4: Install Exporter Dependencies

```bash
cd $EXPORTER_DIR
npm install
```

### Step 5: Verify Backend .env Configuration

The exporter reads the backend's `.env` file for database connection:

```bash
BACKEND_DIR="$PROJECT_ROOT/backend"

# Check if .env exists
if [ ! -f "$BACKEND_DIR/.env" ]; then
    echo "Backend .env not found! Create it first (see Part 4.5)."
    exit 1
fi

# Verify EXPORTER_PORT is set
if ! grep -q "EXPORTER_PORT" "$BACKEND_DIR/.env"; then
    echo "Adding EXPORTER_PORT to .env..."
    echo "" >> $BACKEND_DIR/.env
    echo "# Exporter Configuration" >> $BACKEND_DIR/.env
    echo "EXPORTER_PORT=9091" >> $BACKEND_DIR/.env
fi

# Show configuration (excluding sensitive data)
grep -v PASSWORD $BACKEND_DIR/.env
```

### Step 6: Create PM2 Log Directory

```bash
# Create log directory
sudo mkdir -p /var/log/pm2
sudo chown -R $USER:$USER /var/log/pm2

# Also create logs directory in exporter
mkdir -p $EXPORTER_DIR/logs
```

### Step 7: Clean Up Any Existing Exporter Processes

```bash
# Stop any existing bmi-app-exporter from PM2
pm2 delete bmi-app-exporter 2>/dev/null || true

# Also check root's PM2 (in case it was started by mistake)
sudo pm2 delete bmi-app-exporter 2>/dev/null || true

# Wait for cleanup
sleep 2
```

### Step 8: Start the Exporter with PM2

**Important**: We start the exporter directly with PM2 (NOT using ecosystem.config.js) to ensure proper environment variable handling:

```bash
cd $EXPORTER_DIR

# Start the exporter with explicit configuration
pm2 start exporter.js \
    --name bmi-app-exporter \
    --cwd $EXPORTER_DIR \
    --error $EXPORTER_DIR/logs/err.log \
    --output $EXPORTER_DIR/logs/out.log \
    --time \
    --env production

# Save PM2 process list
pm2 save

# Wait a moment for startup
sleep 3
```

### Step 9: Configure PM2 to Start on Boot

**Important**: Only configure this once, not every time you restart the exporter:

```bash
# Check if PM2 startup is already configured
if ! systemctl is-enabled pm2-$USER &>/dev/null; then
    echo "Configuring PM2 startup..."
    pm2 startup systemd -u $USER --hp $HOME
    # Follow the command it outputs (usually starts with 'sudo')
    # Example: sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
else
    echo "PM2 startup already configured"
fi
```

### Step 10: Verify BMI Application Exporter

Check PM2 status:

```bash
# View PM2 process list
pm2 list

# Should show bmi-app-exporter with status "online"
```

Check metrics endpoint:

Check metrics endpoint:

```bash
# Test metrics endpoint
curl http://localhost:9091/metrics | head -30

# Check for BMI-specific metrics
curl http://localhost:9091/metrics | grep bmi
```

You should see custom application metrics like:

```
# HELP bmi_measurements_total Total number of measurements stored in database
# TYPE bmi_measurements_total gauge
bmi_measurements_total 150

# HELP bmi_average_value Average BMI value of all measurements
# TYPE bmi_average_value gauge
bmi_average_value 24.5

# HELP bmi_api_requests_total Total number of API requests
# TYPE bmi_api_requests_total counter
bmi_api_requests_total 1234
```

Check PM2 logs:

```bash
# View logs in real-time
pm2 logs bmi-app-exporter --lines 50

# Check if any errors
pm2 logs bmi-app-exporter --err --lines 20
```

### Troubleshooting BMI Exporter

If the exporter shows errors:

```bash
# View full logs
pm2 logs bmi-app-exporter --lines 100

# Check environment variables PM2 is using
pm2 env bmi-app-exporter

# Restart the exporter
pm2 restart bmi-app-exporter

# If issues persist, delete and recreate
pm2 delete bmi-app-exporter
cd $EXPORTER_DIR
pm2 start exporter.js --name bmi-app-exporter
pm2 save

# Check database connection
psql -U bmi_user -d bmidb -h localhost -c "SELECT COUNT(*) FROM measurements;"
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

**Important**: Replace `MONITORING_SERVER_IP` with your monitoring server's private IP address.

```bash
MONITORING_SERVER_IP="YOUR_MONITORING_SERVER_PRIVATE_IP"

sudo tee /etc/promtail/promtail-config.yml > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://${MONITORING_SERVER_IP}:3100/loki/api/v1/push

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
  - job_name: nginx-access
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-access
          server: bmi-app-server
          tier: frontend
          __path__: /var/log/nginx/*access.log

  # Nginx error logs
  - job_name: nginx-error
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-error
          server: bmi-app-server
          tier: frontend
          __path__: /var/log/nginx/*error.log

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

  # BMI Backend application logs (systemd service)
  - job_name: bmi-backend
    static_configs:
      - targets:
          - localhost
        labels:
          job: bmi-backend
          server: bmi-app-server
          tier: backend
          __path__: /var/log/bmi-backend.log
EOF
```

**Manual method:**

```bash
sudo nano /etc/promtail/promtail-config.yml
```

Copy and paste the above YAML configuration (update `MONITORING_SERVER_IP`).

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

### Step 1: Check All Services

Check systemd services:

```bash
# Check all systemd services
sudo systemctl status node_exporter
sudo systemctl status postgres_exporter
sudo systemctl status nginx_exporter
sudo systemctl status bmi-backend
sudo systemctl status promtail

# Quick check if all are active
for service in node_exporter postgres_exporter nginx_exporter bmi-backend promtail; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service is running"
    else
        echo "✗ $service is NOT running"
    fi
done
```

Check PM2 process:

```bash
# Check PM2 status
pm2 list

# Should show bmi-app-exporter as "online"
```

### Step 2: Check All Exporters

Test each exporter endpoint:

```bash
# Node Exporter (system metrics)
curl http://localhost:9100/metrics | head -20

# PostgreSQL Exporter (database metrics)
curl http://localhost:9187/metrics | grep pg_ | head -10

# Nginx Exporter (web server metrics)
curl http://localhost:9113/metrics | grep nginx | head -10

# BMI Application Exporter (business metrics)
curl http://localhost:9091/metrics | grep bmi | head -10

# Promtail (log shipper)
curl http://localhost:9080/ready
curl http://localhost:9080/metrics | grep promtail
```

### Step 3: Verify Backend Application

```bash
# Check backend service
sudo systemctl status bmi-backend

# View recent logs
sudo tail -n 50 /var/log/bmi-backend.log

# Test API endpoint
curl http://localhost:3000/api/health || curl http://localhost:3000/

# Check if backend is listening
sudo netstat -tlnp | grep 3000
```

### Step 3: Test from Monitoring Server

From your **monitoring server**, test connectivity to all exporters:

```bash
# Replace with your application server's private IP
APP_SERVER_IP="YOUR_APPLICATION_SERVER_PRIVATE_IP"

# Test Node Exporter
curl http://$APP_SERVER_IP:9100/metrics | head -10

# Test PostgreSQL Exporter
curl http://$APP_SERVER_IP:9187/metrics | grep pg_ | head -10

# Test Nginx Exporter
curl http://$APP_SERVER_IP:9113/metrics | grep nginx | head -10

# Test BMI Application Exporter
curl http://$APP_SERVER_IP:9091/metrics | grep bmi | head -10
```

All commands should return metrics successfully. If not, check firewall rules.

### Step 4: Verify in Prometheus

On your monitoring server, access Prometheus web UI:

```
http://MONITORING_SERVER_PUBLIC_IP:9090/targets
```

You should see targets for your application server:
- `node_exporter` - UP (green)
- `postgres_exporter` - UP (green)
- `nginx_exporter` - UP (green)
- `bmi-app-exporter` - UP (green)

All targets should show **UP** status and green color.

### Step 5: Verify Logs in Grafana

On your monitoring server, access Grafana:

```
http://MONITORING_SERVER_PUBLIC_IP:3000
```

1. Go to **Explore** → Select **Loki** datasource
2. Try these queries:
   - `{job="bmi-backend"}` - Backend application logs
   - `{job="nginx-access"}` - Nginx access logs
   - `{job="postgresql"}` - Database logs
   - `{server="bmi-app-server"}` - All logs from your app server

You should see logs streaming from your application server.

### Step 6: Create Test Data

Create test measurements to verify metrics are updating:

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

# Check metrics updated
curl http://localhost:9091/metrics | grep bmi_measurements_total

# The count should increase
```

## Part 8: Service Management

### Backend Application (Systemd)

```bash
# View status
sudo systemctl status bmi-backend

# Start service
sudo systemctl start bmi-backend

# Stop service
sudo systemctl stop bmi-backend

# Restart service
sudo systemctl restart bmi-backend

# View logs (real-time)
sudo tail -f /var/log/bmi-backend.log

# View logs (last 50 lines)
sudo tail -n 50 /var/log/bmi-backend.log

# View systemd journal logs
sudo journalctl -u bmi-backend -f
sudo journalctl -u bmi-backend -n 100 --no-pager

# Enable auto-start on boot
sudo systemctl enable bmi-backend

# Disable auto-start
sudo systemctl disable bmi-backend
```

### BMI Exporter (PM2)

```bash
# View all PM2 processes
pm2 list

# View logs (real-time)
pm2 logs bmi-app-exporter

# View last 50 lines
pm2 logs bmi-app-exporter --lines 50

# View only errors
pm2 logs bmi-app-exporter --err --lines 20

# Restart exporter
pm2 restart bmi-app-exporter

# Stop exporter
pm2 stop bmi-app-exporter

# Start exporter
pm2 start bmi-app-exporter

# Delete and recreate
pm2 delete bmi-app-exporter
cd /path/to/project/monitoring/exporters/bmi-app-exporter
pm2 start exporter.js --name bmi-app-exporter
pm2 save

# View detailed process info
pm2 show bmi-app-exporter

# Monitor in real-time
pm2 monit
```

### System Exporters (Systemd)

```bash
# Restart all exporters
sudo systemctl restart node_exporter
sudo systemctl restart postgres_exporter
sudo systemctl restart nginx_exporter
sudo systemctl restart promtail

# View logs for any exporter
sudo journalctl -u node_exporter -f
sudo journalctl -u postgres_exporter -f
sudo journalctl -u nginx_exporter -f
sudo journalctl -u promtail -f

# Check status of all services
for service in node_exporter postgres_exporter nginx_exporter bmi-backend promtail; do
    echo "=== $service ==="
    systemctl is-active $service
done
```

## Troubleshooting

### Backend Service Issues

```bash
# Check if backend is running
sudo systemctl status bmi-backend

# View recent errors
sudo journalctl -u bmi-backend -n 50 --no-pager

# Check if port 3000 is in use
sudo netstat -tlnp | grep 3000
sudo lsof -i :3000

# Test backend directly
curl http://localhost:3000/

# Check Node.js path in service
cat /etc/systemd/system/bmi-backend.service | grep ExecStart

# Verify .env file
ls -la /path/to/backend/.env
cat /path/to/backend/.env | grep -v PASSWORD

# Check database connectivity from backend
cd /path/to/backend
node -e "require('dotenv').config(); console.log(process.env)"
```

### Exporter Not Responding

```bash
# Check service status
sudo systemctl status node_exporter
sudo systemctl status postgres_exporter
sudo systemctl status nginx_exporter
pm2 status

# Check logs
sudo journalctl -u node_exporter -n 50 --no-pager
sudo journalctl -u postgres_exporter -n 50 --no-pager
sudo journalctl -u nginx_exporter -n 50 --no-pager
pm2 logs bmi-app-exporter --lines 100

# Check if services are listening
sudo netstat -tlnp | grep -E '9100|9187|9113|9091'

# Restart exporters
sudo systemctl restart node_exporter postgres_exporter nginx_exporter
pm2 restart bmi-app-exporter
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

# Test connectivity from monitoring server (run on monitoring server)
telnet APPLICATION_SERVER_IP 9100
telnet APPLICATION_SERVER_IP 9187
telnet APPLICATION_SERVER_IP 9113
telnet APPLICATION_SERVER_IP 9091

# Or use curl from monitoring server
curl http://APPLICATION_SERVER_IP:9100/metrics
curl http://APPLICATION_SERVER_IP:9187/metrics
curl http://APPLICATION_SERVER_IP:9113/metrics
curl http://APPLICATION_SERVER_IP:9091/metrics

# If blocked, add firewall rules again
MONITORING_SERVER_IP="YOUR_MONITORING_SERVER_IP"
sudo ufw allow from $MONITORING_SERVER_IP to any port 9100 proto tcp
sudo ufw allow from $MONITORING_SERVER_IP to any port 9187 proto tcp
sudo ufw allow from $MONITORING_SERVER_IP to any port 9113 proto tcp
sudo ufw allow from $MONITORING_SERVER_IP to any port 9091 proto tcp
sudo ufw reload
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
# View full logs
pm2 logs bmi-app-exporter --lines 100

# Check environment variables
pm2 env bmi-app-exporter

# Check if backend .env exists and is readable
ls -la /path/to/backend/.env

# Test database connection manually
psql -U bmi_user -d bmidb -h localhost -c "SELECT COUNT(*) FROM measurements;"

# Restart with fresh setup
pm2 delete bmi-app-exporter
cd /path/to/project/monitoring/exporters/bmi-app-exporter
pm2 start exporter.js --name bmi-app-exporter
pm2 save

# Check file permissions
ls -la /path/to/project/monitoring/exporters/bmi-app-exporter/
```

### Promtail Not Shipping Logs

```bash
# Check Promtail status
sudo systemctl status promtail

# View Promtail logs
sudo journalctl -u promtail -n 100 --no-pager

# Check configuration
sudo cat /etc/promtail/promtail-config.yml

# Test connectivity to Loki
curl http://MONITORING_SERVER_IP:3100/ready

# Check positions file
sudo cat /var/lib/promtail/positions.yaml

# Verify log files exist and are readable
ls -la /var/log/bmi-backend.log
ls -la /var/log/nginx/access.log
ls -la /var/log/postgresql/

# Check Promtail groups
groups promtail

# Restart Promtail
sudo systemctl restart promtail
```

### Nginx Exporter Issues

```bash
# Check if stub_status is accessible
curl http://localhost/nginx_status

# If not accessible, check Nginx config
sudo nginx -t
cat /etc/nginx/sites-available/bmi-health-tracker | grep -A 10 "stub_status"

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx and exporter
sudo systemctl restart nginx
sudo systemctl restart nginx_exporter
```

## Maintenance

### Update Exporters

```bash
# Stop services before updating
sudo systemctl stop node_exporter postgres_exporter nginx_exporter
pm2 stop bmi-app-exporter

# Download new versions (follow same installation steps with new version numbers)
# Update version variables:
NODE_EXPORTER_VERSION="1.7.0"
POSTGRES_EXPORTER_VERSION="0.15.0"
NGINX_EXPORTER_VERSION="0.11.0"
PROMTAIL_VERSION="2.9.3"

# Then re-run installation steps for each component

# Start services after updating
sudo systemctl start node_exporter postgres_exporter nginx_exporter
pm2 start bmi-app-exporter
```

### Update Backend Application

```bash
# Stop backend
sudo systemctl stop bmi-backend

# Navigate to backend directory
cd /path/to/project/backend

# Pull latest code
git pull

# Install dependencies
npm install

# Run migrations if needed
npm run migrate

# Start backend
sudo systemctl start bmi-backend

# Check status
sudo systemctl status bmi-backend
sudo tail -f /var/log/bmi-backend.log
```

### Backup Configuration

```bash
# Create backup directory
sudo mkdir -p /root/monitoring-backups

# Backup all configurations
sudo tar -czf /root/monitoring-backups/exporter-configs-$(date +%Y%m%d).tar.gz \
  /etc/systemd/system/node_exporter.service \
  /etc/systemd/system/postgres_exporter.service \
  /etc/systemd/system/nginx_exporter.service \
  /etc/systemd/system/bmi-backend.service \
  /etc/default/postgres_exporter \
  /etc/promtail/promtail-config.yml \
  /path/to/project/backend/.env

# List backups
ls -lh /root/monitoring-backups/
```

### Clean Up Old Logs

```bash
# View log file sizes
du -sh /var/log/bmi-backend.log
du -sh /var/log/nginx/*.log
du -sh /var/log/postgresql/*.log

# Rotate logs manually if needed
sudo logrotate -f /etc/logrotate.conf

# Or truncate specific log
sudo truncate -s 0 /var/log/bmi-backend.log
```

## Security Best Practices

1. **Use strong passwords** for PostgreSQL monitoring user (auto-generated by script)
2. **Restrict firewall rules** to only monitoring server IP
3. **Regular updates** of exporters and dependencies
4. **Monitor exporter logs** for unusual activity
5. **Secure .env files** with proper permissions (600)
6. **Use private IPs** for communication between servers
7. **Run services as dedicated users** (not root)
8. **Enable systemd security features** (consider adding `NoNewPrivileges=true`, `PrivateTmp=true`)

### Verify File Permissions

```bash
# Check sensitive files
ls -la /etc/default/postgres_exporter  # Should be 600
ls -la /path/to/backend/.env            # Should be 600 or 640

# Fix if needed
sudo chmod 600 /etc/default/postgres_exporter
chmod 600 /path/to/backend/.env
```

## Performance Considerations

- **Node Exporter**: Minimal impact (<1% CPU), collects system metrics efficiently
- **PostgreSQL Exporter**: Runs read-only queries, <1% CPU impact on database
- **Nginx Exporter**: Very lightweight, negligible impact (<0.5% CPU)
- **BMI Custom Exporter**: Runs optimized queries every 15 seconds, ~1-2% CPU
- **Promtail**: Tails log files efficiently, minimal CPU usage (~1%)
- **Total overhead**: Typically 3-5% CPU, 50-100MB RAM

### Monitor Exporter Resource Usage

```bash
# Check CPU and memory usage
top -b -n 1 | grep -E 'node_export|postgres_exp|nginx_prom|promtail|node.*exporter'

# Check specific process
ps aux | grep node_exporter
ps aux | grep postgres_exporter

# PM2 monitoring
pm2 monit
```

## Next Steps

1. **Verify all targets in Prometheus** - `http://MONITORING_SERVER_IP:9090/targets`
2. **Access Grafana** - `http://MONITORING_SERVER_IP:3000`
3. **Import pre-configured dashboards**:
   - `monitoring/grafana/dashboards/bmi-application-metrics.json`
   - `monitoring/grafana/dashboards/system-overview.json`
4. **Verify metrics** in Grafana dashboards
5. **Check logs** in Grafana Explore with Loki datasource
6. **Set up alerts** for critical conditions (optional)
7. **Test alert notifications** (optional)

### Quick Dashboard Import

In Grafana:
1. Click **Dashboards** → **Import**
2. Click **Upload JSON file**
3. Select `bmi-application-metrics.json` from your project
4. Select **Prometheus** as datasource
5. Click **Import**
6. Repeat for `system-overview.json`

## Useful Commands Reference

```bash
# === Backend Management ===
sudo systemctl status bmi-backend              # Check status
sudo systemctl restart bmi-backend             # Restart
sudo tail -f /var/log/bmi-backend.log          # View logs
sudo journalctl -u bmi-backend -f              # View systemd logs

# === Exporter Status ===
sudo systemctl status node_exporter postgres_exporter nginx_exporter promtail
pm2 status                                      # Check PM2 processes

# === View All Metrics ===
curl localhost:9100/metrics | less             # Node Exporter
curl localhost:9187/metrics | less             # PostgreSQL
curl localhost:9113/metrics | less             # Nginx
curl localhost:9091/metrics | less             # BMI App
curl localhost:9080/ready                      # Promtail health

# === Quick Health Check ===
for port in 9100 9187 9113 9091; do
    if curl -s http://localhost:$port/metrics > /dev/null; then
        echo "✓ Port $port is responding"
    else
        echo "✗ Port $port is NOT responding"
    fi
done

# === Restart All Exporters ===
sudo systemctl restart node_exporter postgres_exporter nginx_exporter promtail
pm2 restart bmi-app-exporter

# === Check Connectivity from Monitoring Server ===
# (Run on monitoring server)
APP_IP="YOUR_APP_SERVER_IP"
curl http://$APP_IP:9100/metrics | head -5
curl http://$APP_IP:9187/metrics | head -5
curl http://$APP_IP:9113/metrics | head -5
curl http://$APP_IP:9091/metrics | head -5
```

---

## Summary

✅ **Installed Components:**
- ✓ Node Exporter v1.7.0 - System metrics on port 9100
- ✓ PostgreSQL Exporter v0.15.0 - Database metrics on port 9187
- ✓ Nginx Exporter v0.11.0 - Web server metrics on port 9113
- ✓ BMI Backend Service - Application running as systemd service
- ✓ BMI Custom Exporter v1.0 - Business metrics on port 9091 (PM2)
- ✓ Promtail v2.9.3 - Log shipping to Loki on port 9080

✅ **Monitoring Coverage:**
- ✓ **Frontend Tier**: Nginx access/error logs, web server metrics
- ✓ **Backend Tier**: Application logs, API metrics, business metrics
- ✓ **Database Tier**: PostgreSQL logs, database performance metrics
- ✓ **System Tier**: CPU, memory, disk, network metrics

✅ **Access Points:**
- **Prometheus**: `http://MONITORING_SERVER_IP:9090`
- **Grafana**: `http://MONITORING_SERVER_IP:3000` (admin/admin)
- **Application**: `http://APP_SERVER_IP` or `http://APP_SERVER_IP:3000`

---

**Setup Complete!** 🎉

Your three-tier application is now fully instrumented and monitored. All metrics are being collected and all logs are being shipped to your centralized monitoring server.

For automated setup, you can also use:
```bash
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
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
