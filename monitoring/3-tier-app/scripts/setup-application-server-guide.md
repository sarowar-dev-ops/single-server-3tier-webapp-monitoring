# Application Server Monitoring Setup Guide

Manual walkthrough of every step performed by `setup-application-server.sh`.  
The script is fully idempotent — safe to run again if any step fails.

**Server:** BMI App Server (where the BMI application is deployed)  
**Run order:** Run this AFTER `setup-monitoring-server.sh` has completed on the monitoring server.

---

## Prerequisites

| Requirement | Details |
|---|---|
| OS | Ubuntu 22.04 LTS |
| Access | Root or sudo |
| Internet | Required for downloads |
| BMI App | Must already be deployed (`IMPLEMENTATION_AUTO.sh` completed) |
| Versions installed | Node Exporter 1.7.0, PostgreSQL Exporter 0.15.0, Nginx Exporter 0.11.0, Promtail 2.9.3 |

**You will be prompted once at the start for:**
- Monitoring Server Private IP address

---

## Run the Script

```bash
# SSH to your app server
ssh -i your-key.pem ubuntu@APP_SERVER_IP

# Navigate to project directory
cd /home/ubuntu/single-server-3tier-webapp-monitoring

# Make executable
chmod +x monitoring/3-tier-app/scripts/setup-application-server.sh

# Run with sudo
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
```

---

## Step 1 — Initial System Setup

**What the script does:**
- Detects the server's public and private IP via EC2 IMDSv2 metadata
- Prompts you to enter the Monitoring Server Private IP
- Runs `apt update && apt upgrade`
- Installs: `wget curl git unzip tar jq net-tools`

**You will be prompted:**
```
Enter your Monitoring Server Private IP address:
Monitoring Server Private IP: <type it here>
```

**Verify after step:**
```bash
# Confirm essential tools are available
which wget curl jq net-tools
# Confirm IPs were detected (check script output for [SUCCESS] lines)
hostname -I
```

✅ **Expected:** Script prints `[SUCCESS] Application Server Public IP: X.X.X.X` and `[SUCCESS] Monitoring Server IP: X.X.X.X`

---

## Dependency Checks (Auto-installed if missing)

The script checks for and installs these if not already present:

### PostgreSQL
- Verifies `psql` is available and `postgresql` service is running
- If missing: installs `postgresql postgresql-contrib` and starts the service

**Verify:**
```bash
sudo systemctl status postgresql
psql --version
```
✅ **Expected:** `Active: active (running)`, version output shown

### Nginx
- Verifies `nginx` is available and running
- If missing: installs and starts Nginx

**Verify:**
```bash
sudo systemctl status nginx
nginx -v
```
✅ **Expected:** `Active: active (running)`

### Node.js (v20.x LTS)
- Checks if `node` is in PATH
- If missing: installs via NodeSource setup script

**Verify:**
```bash
node --version    # Should show v20.x.x
npm --version
```
✅ **Expected:** `v20.x.x`

### PM2
- Checks if `pm2` is in PATH
- If missing: runs `npm install -g pm2`

**Verify:**
```bash
pm2 --version
```
✅ **Expected:** Version number printed

---

## Step 2 — Configure Firewall

**What the script does:**
- Opens 4 exporter ports, but **only from the monitoring server's IP** (not from anywhere):

| Port | Exporter | Rule |
|---|---|---|
| 9100 | Node Exporter | Allow from MONITORING_SERVER_IP |
| 9187 | PostgreSQL Exporter | Allow from MONITORING_SERVER_IP |
| 9113 | Nginx Exporter | Allow from MONITORING_SERVER_IP |
| 9091 | BMI App Exporter | Allow from MONITORING_SERVER_IP |

**Verify after step:**
```bash
sudo ufw status | grep -E "9100|9187|9113|9091"
```
✅ **Expected:** 4 lines showing `ALLOW` with your monitoring server's IP as source

---

## Step 3 — Install Node Exporter (v1.7.0)

**What the script does:**
- Creates `node_exporter` system user (no shell, no home)
- Downloads Node Exporter binary from GitHub
- Installs to `/usr/local/bin/node_exporter`
- Creates systemd service
- Starts and enables the service

**Verify after step:**
```bash
# Service status
sudo systemctl status node_exporter

# Metrics endpoint responding
curl -s http://localhost:9100/metrics | head -5

# Check a specific metric
curl -s http://localhost:9100/metrics | grep node_cpu_seconds_total | head -3
```
✅ **Expected:** Service `active (running)`, metrics output with `# HELP` and `# TYPE` lines

---

## Step 4 — Install PostgreSQL Exporter (v0.15.0)

**What the script does:**
- Downloads PostgreSQL Exporter binary from GitHub
- Creates `postgres_exporter` system user
- Creates a dedicated PostgreSQL monitoring user in the `bmidb` database with read-only permissions
- Generates a random password for the monitoring user
- Writes connection string to `/etc/default/postgres_exporter` (mode 600)
- Creates systemd service using `EnvironmentFile`
- Starts and enables the service

**Created PostgreSQL user permissions:**
- `CONNECT` on `bmidb`
- `USAGE` on `public` schema
- `SELECT` on all tables
- `pg_monitor` role (for system catalog access)

**Verify after step:**
```bash
# Service status
sudo systemctl status postgres_exporter

# Metrics endpoint responding
curl -s http://localhost:9187/metrics | grep "^pg_" | head -10

# Verify monitoring user exists in database
sudo -u postgres psql -c "\du postgres_exporter"
```
✅ **Expected:** Service `active (running)`, `pg_` prefixed metrics visible

---

## Step 5 — Install Nginx Exporter (v0.11.0)

**What the script does:**
- Finds the Nginx config for the BMI app (`/etc/nginx/sites-available/bmi-health-tracker`)
- Adds a `/nginx_status` location block with `stub_status on` (if not already present)
  - Access restricted to `127.0.0.1` and the monitoring server IP
  - Original config backed up with timestamp
- Reloads Nginx to apply changes
- Downloads Nginx Exporter binary
- Installs to `/usr/local/bin/nginx-prometheus-exporter`
- Creates `nginx_exporter` system user
- Creates systemd service pointing at `http://localhost/nginx_status`
- Starts and enables the service

**Verify after step:**
```bash
# Service status
sudo systemctl status nginx_exporter

# Stub status endpoint (used by exporter internally)
curl -s http://localhost/nginx_status

# Exporter metrics endpoint
curl -s http://localhost:9113/metrics | grep "^nginx_" | head -10
```
✅ **Expected:** `nginx_status` shows active connections, `nginx_connections_active` metric visible

---

## Step 5.5 — Set Up BMI Backend Application Service

**What the script does:**
- Verifies backend directory exists at the project root
- Stops any orphan `node src/server.js` processes
- Runs `npm install` in the backend directory as the original (non-root) user
- Creates `backend/.env` if missing (from `.env.example` or minimal template)
  - Default PORT is `3010`
- Creates `/var/log/bmi-backend.log`
- Creates systemd service `bmi-backend` running as the original user
- Starts and enables the service

**Verify after step:**
```bash
# Service status
sudo systemctl status bmi-backend

# Health endpoint
curl http://localhost:3010/health

# Live logs
sudo tail -f /var/log/bmi-backend.log
```
✅ **Expected:** `{"status":"ok","environment":"production"}` from health check, service `active (running)`

---

## Step 6 — Install BMI Custom Application Exporter

**What the script does:**
- Verifies `monitoring/exporters/bmi-app-exporter/exporter.js` exists
- Fixes directory ownership to the original (non-root) user
- Runs `npm install` in the exporter directory as the original user
- Verifies/creates `backend/.env` with `EXPORTER_PORT=9091`
- Creates `/var/log/pm2/` and `exporter/logs/` directories
- Starts the exporter via PM2 as the original user:
  - Name: `bmi-app-exporter`
  - Reads `DATABASE_URL` from `backend/.env`
  - Logs to `monitoring/exporters/bmi-app-exporter/logs/`
- Runs `pm2 save` to persist the process list
- Configures `pm2 startup` systemd integration for boot persistence

**Verify after step:**
```bash
# PM2 status (run as ubuntu user, not root)
pm2 list

# Exporter metrics
curl -s http://localhost:9091/metrics | grep "^bmi_" | head -20

# Key BMI metrics to confirm
curl -s http://localhost:9091/metrics | grep -E "bmi_measurements_total|bmi_app_healthy|bmi_average_value"

# Check logs if something is wrong
pm2 logs bmi-app-exporter --lines 50
```
✅ **Expected:** `bmi-app-exporter` shows `online` in PM2 list, all `bmi_` metrics visible

---

## Step 7 — Install Promtail (v2.9.3)

**What the script does:**
- Downloads Promtail binary from GitHub
- Installs to `/usr/local/bin/promtail`
- Creates `promtail` system user
- Adds `promtail` to `adm` and `systemd-journal` groups (required for log access)
- Creates `/etc/promtail/promtail-config.yml` with 5 log scrape jobs:

| Job | Source Path | Labels |
|---|---|---|
| `varlogs` | `/var/log/*.log` | `server: bmi-app-server` |
| `nginx-access` | `/var/log/nginx/*access.log` | `tier: frontend` |
| `nginx-error` | `/var/log/nginx/*error.log` | `tier: frontend` |
| `postgresql` | `/var/log/postgresql/*.log` | `tier: database` |
| `bmi-backend` | `/var/log/bmi-backend.log` | `tier: backend` |

- Ships logs to `http://MONITORING_SERVER_IP:3100/loki/api/v1/push`
- Creates systemd service, starts and enables it

**Verify after step:**
```bash
# Service status
sudo systemctl status promtail

# Promtail ready endpoint
curl -s http://localhost:9080/ready

# Check Promtail is connecting to Loki (check logs)
sudo journalctl -u promtail -n 30

# Verify config has correct monitoring server IP
grep "url:" /etc/promtail/promtail-config.yml
```
✅ **Expected:** `ready` response, no connection errors in journal, correct Loki URL shown

---

## Step 8 — Final Verification

**What the script does:**
- Tests each exporter's HTTP endpoint with `curl`
- Checks each systemd service is `active`
- Checks PM2 shows `bmi-app-exporter` as `online`
- Exits with error if anything is not running

**All checks performed:**

| Component | Check Method | Port |
|---|---|---|
| node_exporter | `curl /metrics` | 9100 |
| postgres_exporter | `curl /metrics` | 9187 |
| nginx_exporter | `curl /metrics` | 9113 |
| bmi-app-exporter | `curl /metrics` | 9091 |
| promtail | `curl /ready` | 9080 |
| node_exporter | `systemctl is-active` | — |
| postgres_exporter | `systemctl is-active` | — |
| nginx_exporter | `systemctl is-active` | — |
| bmi-backend | `systemctl is-active` | — |
| promtail | `systemctl is-active` | — |
| bmi-app-exporter | `pm2 list \| grep online` | — |

**Run all checks manually:**
```bash
for port in 9100 9187 9113 9091; do
  echo -n "Port $port: "
  curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/metrics
  echo ""
done

echo -n "Promtail: "
curl -s http://localhost:9080/ready

for svc in node_exporter postgres_exporter nginx_exporter bmi-backend promtail; do
  echo "$svc: $(systemctl is-active $svc)"
done

pm2 list | grep bmi-app-exporter
```
✅ **Expected:** All ports return `200`, all services `active`, PM2 shows `online`

---

## What Gets Installed — Summary

| Component | Binary | Config | Port | Manager |
|---|---|---|---|---|
| Node Exporter | `/usr/local/bin/node_exporter` | none | 9100 | systemd |
| PostgreSQL Exporter | `/usr/local/bin/postgres_exporter` | `/etc/default/postgres_exporter` | 9187 | systemd |
| Nginx Exporter | `/usr/local/bin/nginx-prometheus-exporter` | `/etc/nginx/sites-available/bmi-health-tracker` | 9113 | systemd |
| BMI App Exporter | `monitoring/exporters/bmi-app-exporter/` | `backend/.env` | 9091 | PM2 |
| Promtail | `/usr/local/bin/promtail` | `/etc/promtail/promtail-config.yml` | 9080 | systemd |
| BMI Backend | `backend/src/server.js` | `backend/.env` | 3010 | systemd |

---

## Troubleshooting

**PostgreSQL Exporter fails to connect:**
```bash
# Check environment file
sudo cat /etc/default/postgres_exporter

# Test connection manually
psql "$(sudo cat /etc/default/postgres_exporter | cut -d= -f2-)" -c "SELECT 1;"

# Check postgres_exporter user exists
sudo -u postgres psql -c "\du postgres_exporter"
```

**BMI App Exporter not starting:**
```bash
# Check logs
pm2 logs bmi-app-exporter --lines 100

# Verify .env has correct DATABASE_URL
cat /home/ubuntu/single-server-3tier-webapp-monitoring/backend/.env

# Test database connection manually
node -e "const {Pool}=require('pg');const p=new Pool({connectionString:process.env.DATABASE_URL});p.query('SELECT 1').then(()=>console.log('OK')).catch(console.error)"
```

**Nginx Exporter fails:**
```bash
# Check stub_status is accessible
curl http://localhost/nginx_status

# If 403 or 404, check Nginx config
cat /etc/nginx/sites-available/bmi-health-tracker | grep -A 8 nginx_status

# Reload Nginx after any config change
sudo nginx -t && sudo systemctl reload nginx
```

**Promtail not shipping logs:**
```bash
# Check connectivity to Loki
curl -s http://MONITORING_SERVER_IP:3100/ready

# Confirm promtail config has correct IP
grep url /etc/promtail/promtail-config.yml

# Live log view
sudo journalctl -u promtail -f
```

---

## Next Step

Once this script completes successfully, go to the **Monitoring Server** and verify all targets are UP:

```
http://MONITORING_SERVER_IP:9090/targets
```

All 9 scrape targets should show **State: UP**:
- `prometheus`, `node_exporter_monitoring`, `grafana`, `loki`, `alertmanager` (on monitoring server)
- `node_exporter`, `postgresql`, `nginx`, `bmi-backend` (on app server)

---

## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, WPP Production - Dhaka  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
