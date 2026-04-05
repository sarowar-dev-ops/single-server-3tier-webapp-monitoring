# Monitoring Server Setup Guide

Manual walkthrough of every step performed by `setup-monitoring-server.sh`.  
The script is fully idempotent — safe to run again if any step fails.

**Server:** BMI Monitoring Server (dedicated server for Prometheus, Grafana, Loki, AlertManager)  
**Run order:** Run this FIRST, before `setup-application-server.sh`.

---

## Prerequisites

| Requirement | Details |
|---|---|
| OS | Ubuntu 22.04 LTS |
| Minimum specs | 2 vCPU, 4 GB RAM, 30 GB disk |
| Access | Root or sudo |
| Internet | Required for downloads |
| Versions | Prometheus 2.48.0, Node Exporter 1.7.0, Loki 2.9.3, AlertManager 0.26.0, Grafana latest |

**You will be prompted once during Step 4 for:**
- Application Server Private IP address

---

## Run the Script

```bash
# SSH to your monitoring server
ssh -i your-key.pem ubuntu@MONITORING_SERVER_IP

# Clone the repository
git clone https://github.com/sarowar-dev-ops/single-server-3tier-webapp-monitoring.git
cd single-server-3tier-webapp-monitoring

# Make executable
chmod +x monitoring/3-tier-app/scripts/setup-monitoring-server.sh

# Run with sudo
sudo ./monitoring/3-tier-app/scripts/setup-monitoring-server.sh
```

---

## Step 1 — Initial System Setup

**What the script does:**
- Detects the server's public and private IP via EC2 IMDSv2 metadata
- Runs `apt update && apt upgrade`
- Installs: `wget curl git unzip tar jq net-tools software-properties-common apt-transport-https ca-certificates`

**Verify after step:**
```bash
# Confirm tools installed
which wget curl jq

# Confirm IP detection worked (check script output)
curl -s http://169.254.169.254/latest/meta-data/local-ipv4
```
✅ **Expected:** Script prints `[SUCCESS] Monitoring Server Public IP: X.X.X.X` and private IP

---

## Step 2 — Configure Firewall

**What the script does:**
- Enables UFW
- Opens only the ports needed for the monitoring stack:

| Port | Service | Source |
|---|---|---|
| 22 | SSH | Anywhere |
| 3001 | Grafana | Anywhere |
| 9090 | Prometheus | Anywhere (debugging) |
| 3100 | Loki | Anywhere (receives logs from app server) |

**Note:** AlertManager (9093) is intentionally NOT opened to the internet — it is only accessed internally on localhost by Prometheus.

**Verify after step:**
```bash
sudo ufw status
```
✅ **Expected:**
```
22/tcp     ALLOW
3001/tcp   ALLOW
9090/tcp   ALLOW
3100/tcp   ALLOW
```

---

## Step 3 — Install Prometheus (v2.48.0)

**What the script does:**
- Creates `prometheus` system user (no shell, no home)
- Creates directories: `/etc/prometheus`, `/var/lib/prometheus`
- Downloads `prometheus-2.48.0.linux-amd64.tar.gz` from GitHub
- Installs binaries to `/usr/local/bin/prometheus` and `/usr/local/bin/promtool`
- Copies `consoles/` and `console_libraries/` to `/etc/prometheus/`
- Cleans up `/tmp` download files

**At this point Prometheus is installed but not yet configured or started.** Configuration happens in Step 4.

**Verify after step:**
```bash
# Binary installed
prometheus --version

# Promtool available
promtool --version
```
✅ **Expected:** `prometheus, version 2.48.0` printed

---

## Step 4 — Configure Prometheus

**What the script does:**
- Checks if `/etc/prometheus/prometheus.yml` already exists
  - If yes: extracts existing App Server IP and lets you keep or change it
  - If no: prompts you to enter the App Server Private IP
- Writes a full `prometheus.yml` with **9 scrape jobs**:

| Job | Target | Labels |
|---|---|---|
| `prometheus` | localhost:9090 | role: monitoring |
| `node_exporter` | APP_SERVER_IP:9100 | server: bmi-app-server, tier: infrastructure |
| `postgresql` | APP_SERVER_IP:9187 | database: bmidb, tier: data |
| `nginx` | APP_SERVER_IP:9113 | tier: frontend |
| `bmi-backend` | APP_SERVER_IP:9091 | application: bmi-health-tracker, tier: application |
| `node_exporter_monitoring` | localhost:9100 | server: monitoring-server |
| `grafana` | localhost:3001 | role: visualization |
| `loki` | localhost:3100 | role: log-aggregation |
| `alertmanager` | localhost:9093 | role: alerting |

- Writes `/etc/prometheus/alert_rules.yml` with 3 alert groups:
  - `system_alerts`: HighCPUUsage (>80%), HighMemoryUsage (>85%), DiskSpaceLow (<15%)
  - `application_alerts`: ApplicationDown, MonitoringServiceDown, DatabaseDown, NginxDown
  - `database_alerts`: DatabaseConnectionsHigh (>80 connections)
- Creates systemd service with 30-day retention and `--web.enable-lifecycle`
- Starts and enables the service

**You will be prompted:**
```
Please enter your Application Server Private IP address:
Application Server IP: <type it here>
```

**Verify after step:**
```bash
# Service status
sudo systemctl status prometheus

# Config validation
promtool check config /etc/prometheus/prometheus.yml

# Alert rules validation
promtool check rules /etc/prometheus/alert_rules.yml

# API responding
curl -s http://localhost:9090/-/ready

# Check configured targets (will show DOWN until app server is set up)
curl -s http://localhost:9090/api/v1/targets | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d['data']['activeTargets']:
    print(t['labels']['job'], '->', t['health'])
"
```
✅ **Expected:** Service `active (running)`, config check returns `SUCCESS`, `localhost` targets show `up`

---

## Step 5 — Install Node Exporter (v1.7.0)

**What the script does:**
- Creates `node_exporter` system user
- Downloads Node Exporter binary from GitHub
- Installs to `/usr/local/bin/node_exporter`
- Creates systemd service (runs as `node_exporter` user, no arguments needed)
- Starts and enables the service

This provides system metrics (CPU, memory, disk, network) for the **monitoring server itself**.

**Verify after step:**
```bash
# Service status
sudo systemctl status node_exporter

# Metrics endpoint
curl -s http://localhost:9100/metrics | head -10

# Specific metrics
curl -s http://localhost:9100/metrics | grep "node_memory_MemAvailable_bytes"
curl -s http://localhost:9100/metrics | grep "node_cpu_seconds_total" | head -3
```
✅ **Expected:** Service `active (running)`, metrics output with CPU/memory data

---

## Step 6 — Install Grafana (latest)

**What the script does:**
- Adds the Grafana APT repository (if not already added)
- Installs Grafana via `apt`
- Changes the default port from `3000` to `3001` in `/etc/grafana/grafana.ini`
- Creates provisioning directories: `/etc/grafana/provisioning/datasources/`, `/etc/grafana/provisioning/dashboards/`
- Creates `/var/lib/grafana/dashboards/`

**Datasources auto-provisioned (no manual setup needed):**

`/etc/grafana/provisioning/datasources/prometheus.yml`:
- Name: `Prometheus`, URL: `http://localhost:9090`, set as **default**

`/etc/grafana/provisioning/datasources/loki.yml`:
- Name: `Loki`, URL: `http://localhost:3100`

**Dashboard provider configured:**
- Folder: `BMI Health Tracker`
- Watches: `/var/lib/grafana/dashboards/`
- Auto-reloads every 30 seconds

**Dashboards auto-copied from `monitoring/3-tier-app/dashboards/`:**
All `*.json` files are copied dynamically — currently 5 dashboards:
- `three-tier-application-dashboard.json`
- `loki-logs-dashboard.json`
- `nodejs-runtime-dashboard.json`
- `monitoring-server-health-dashboard.json`
- `bmi-business-metrics-dashboard.json`

- Starts and enables the service

**Verify after step:**
```bash
# Service status
sudo systemctl status grafana-server

# Port is 3001 (not 3000)
curl -s http://localhost:3001/api/health

# Datasources provisioned (wait ~10s after start)
curl -s http://admin:admin@localhost:3001/api/datasources | python3 -m json.tool | grep '"name"'

# Dashboards provisioned
curl -s http://admin:admin@localhost:3001/api/search | python3 -m json.tool | grep '"title"'

# Confirm dashboards were copied
ls -la /var/lib/grafana/dashboards/
```
✅ **Expected:** Health check returns `{"database":"ok","version":"..."}`, both datasources listed, 5 dashboards visible

---

## Step 7 — Install Loki (v2.9.3)

**What the script does:**
- Downloads `loki-linux-amd64.zip` from GitHub
- Installs to `/usr/local/bin/loki`
- Creates `loki` system user, `/etc/loki/`, `/var/lib/loki/`
- Writes `/etc/loki/loki-config.yml`:
  - HTTP port: `3100`, gRPC port: `9096`
  - Storage: filesystem (chunks at `/var/lib/loki/chunks`)
  - Schema: `boltdb-shipper`, `v11`
  - Log retention: **31 days** (`744h`)
  - AlertManager integration: `http://localhost:9093`
- Creates systemd service
- Starts and enables the service

**Verify after step:**
```bash
# Service status
sudo systemctl status loki

# Ready endpoint
curl -s http://localhost:3100/ready

# Metrics (Loki exposes its own metrics)
curl -s http://localhost:3100/metrics | grep "^loki_" | head -5

# Check config
cat /etc/loki/loki-config.yml | grep -E "http_listen_port|retention_period"
```
✅ **Expected:** Service `active (running)`, `/ready` returns `ready`, port 3100 metrics available

---

## Step 8 — Install AlertManager (v0.26.0)

**What the script does:**
- Downloads `alertmanager-0.26.0.linux-amd64.tar.gz` from GitHub
- Installs `alertmanager` and `amtool` to `/usr/local/bin/`
- Creates `alertmanager` system user, `/etc/alertmanager/`, `/var/lib/alertmanager/`
- Writes `/etc/alertmanager/alertmanager.yml`:
  - Default receiver (no notifications by default — add email/Slack later)
  - Repeat interval: 12 hours
  - Inhibit rules: critical suppresses warning for same alert
- Creates systemd service
- Starts and enables the service

**Verify after step:**
```bash
# Service status
sudo systemctl status alertmanager

# AlertManager API
curl -s http://localhost:9093/-/ready

# View current alerts (empty at first)
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool

# Validate config
amtool check-config /etc/alertmanager/alertmanager.yml
```
✅ **Expected:** Service `active (running)`, ready endpoint responds, config check `SUCCESS`

---

## Step 9 — Verify Grafana Datasources

**What the script does:**
- Waits 10 seconds for Grafana to fully initialize
- Calls the Grafana API to confirm `Prometheus` datasource is registered
- Calls the Grafana API to confirm `Loki` datasource is registered
- Logs warnings (not errors) if not found — provisioning may need another moment

**Verify manually:**
```bash
# Both datasources via API
curl -s http://admin:admin@localhost:3001/api/datasources | python3 -c "
import json,sys
for ds in json.load(sys.stdin):
    print(ds['name'], '->', ds['url'], '(default:', ds.get('isDefault', False), ')')
"

# Test Prometheus datasource
curl -s "http://admin:admin@localhost:3001/api/datasources/proxy/1/api/v1/query?query=up" | python3 -m json.tool | grep '"status"'
```
✅ **Expected:** `Prometheus -> http://localhost:9090 (default: True)` and `Loki -> http://localhost:3100`

---

## Step 10 — Final Verification

**What the script does:**
- Checks each of the 5 installed services with `systemctl is-active`:
  - `prometheus`, `grafana-server`, `loki`, `alertmanager`, `node_exporter`
- Fails with exit code 1 if any service is not running

**Run the same check manually:**
```bash
for svc in prometheus grafana-server loki alertmanager node_exporter; do
  status=$(systemctl is-active $svc)
  echo "$svc: $status"
done
```
✅ **Expected:** All 5 services show `active`

---

## What Gets Installed — Summary

| Component | Binary | Config | Port | Manager |
|---|---|---|---|---|
| Prometheus | `/usr/local/bin/prometheus` | `/etc/prometheus/prometheus.yml` | 9090 | systemd |
| Node Exporter | `/usr/local/bin/node_exporter` | none | 9100 | systemd |
| Grafana | apt package | `/etc/grafana/grafana.ini` | 3001 | systemd |
| Loki | `/usr/local/bin/loki` | `/etc/loki/loki-config.yml` | 3100 | systemd |
| AlertManager | `/usr/local/bin/alertmanager` | `/etc/alertmanager/alertmanager.yml` | 9093 | systemd |

---

## Access Points After Completion

The script prints these at the end:

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://PUBLIC_IP:3001` | admin / admin (change on first login) |
| Prometheus | `http://PUBLIC_IP:9090` | none |
| AlertManager | `http://PUBLIC_IP:9093` | none |
| Loki | `http://PUBLIC_IP:3100` | none |

---

## Troubleshooting

**Prometheus targets show DOWN:**
```bash
# Check targets
curl -s http://localhost:9090/api/v1/targets | python3 -c "
import json,sys
for t in json.load(sys.stdin)['data']['activeTargets']:
    if t['health'] != 'up':
        print('DOWN:', t['labels']['job'], t['scrapeUrl'], t.get('lastError',''))
"

# Verify app server IP in config
grep -E "APP_SERVER_IP|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" /etc/prometheus/prometheus.yml

# Reload after fixing config
curl -X POST http://localhost:9090/-/reload
```

**Grafana dashboards not showing:**
```bash
# Check dashboards were copied
ls -la /var/lib/grafana/dashboards/

# Copy them manually if missing
sudo cp /home/ubuntu/single-server-3tier-webapp-monitoring/monitoring/3-tier-app/dashboards/*.json /var/lib/grafana/dashboards/
sudo chown grafana:grafana /var/lib/grafana/dashboards/*.json

# Trigger reload without restart
curl -s -X POST http://admin:admin@localhost:3001/api/admin/provisioning/dashboards/reload
```

**Loki not receiving logs:**
```bash
# Check Loki is ready
curl http://localhost:3100/ready

# Check firewall allows port 3100 from app server
sudo ufw status | grep 3100

# Confirm Promtail on app server has correct Loki URL
ssh ubuntu@APP_SERVER_IP "grep url /etc/promtail/promtail-config.yml"
```

**AlertManager not receiving alerts from Prometheus:**
```bash
# Verify AlertManager is in Prometheus config
grep -A 3 "alertmanagers:" /etc/prometheus/prometheus.yml

# Check AlertManager is running
sudo systemctl status alertmanager
curl http://localhost:9093/-/ready
```

**Grafana can't query Prometheus:**
```bash
# Test Prometheus API directly
curl "http://localhost:9090/api/v1/query?query=up"

# Test from Grafana datasource proxy
curl http://admin:admin@localhost:3001/api/datasources/1/health
```

---

## Next Step

Once this script completes, run `setup-application-server.sh` on the **App Server**.

After that, verify all 9 Prometheus targets are UP:
```
http://MONITORING_SERVER_PUBLIC_IP:9090/targets
```
