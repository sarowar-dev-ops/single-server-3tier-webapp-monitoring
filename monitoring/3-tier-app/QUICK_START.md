# Quick Start Guide - Three-Tier Application Monitoring

Get your complete monitoring stack up and running in under 30 minutes!

## What You'll Get

- **Prometheus** v2.48.0 (30-day retention)
- **Grafana** latest (port 3001)
- **Loki** v2.9.3 (31-day retention)
- **AlertManager** v0.26.0
- **5 Exporters** (Node, PostgreSQL, Nginx, BMI Custom, Promtail)
- **2 Pre-built Dashboards** (Application + Logs)
- **Comprehensive Alert Rules**

## Prerequisites

- **Two Ubuntu 22.04 servers:**
  1. Monitoring Server (2 vCPU, 4GB RAM minimum)
  2. Application Server (with BMI app already deployed)
- **Root/sudo access** on both servers
- **Security Groups/Firewall** configured to allow:
  - SSH access to both servers
  - Grafana port 3001 from your IP to monitoring server
  - Exporter ports (9100, 9187, 9113, 9091) from monitoring to application server

## Step-by-Step Setup

### 1. Setup Monitoring Server (10 minutes)

SSH to your monitoring server and run:

```bash
# Clone the repository
git clone <your-repo-url>
cd single-server-3tier-webapp-monitoring

# Make the script executable
chmod +x monitoring/3-tier-app/scripts/setup-monitoring-server.sh

# Run the automated setup
sudo ./monitoring/3-tier-app/scripts/setup-monitoring-server.sh
```

**What happens:**
- Installs Prometheus, Grafana, Loki, AlertManager
- Configures all services to start automatically
- Sets up firewall rules
- **You'll be asked for:** Application Server Private IP

**Expected output:** 
```
✓ Prometheus started successfully (with 30-day retention)
✓ Grafana started successfully (port 3001 with auto-provisioning)
✓ Loki started successfully (with 31-day retention)
✓ AlertManager started successfully
✓ Node Exporter started successfully

Access Points:
  Grafana:       http://YOUR_PUBLIC_IP:3001
  Prometheus:    http://YOUR_PUBLIC_IP:9090
  Loki:          http://YOUR_PUBLIC_IP:3100
  AlertManager:  http://YOUR_PUBLIC_IP:9093

ℹ️  Grafana datasources (Prometheus & Loki) are auto-provisioned!
```

### 2. Setup Application Server (15 minutes)

SSH to your application server and run:

```bash
# Navigate to your project directory
cd /path/to/single-server-3tier-webapp-monitoring

# Make the script executable
chmod +x monitoring/3-tier-app/scripts/setup-application-server.sh

# Run the automated setup
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
```

**What happens:**
- Installs all exporters (Node, PostgreSQL, Nginx, BMI Custom)
- Configures Nginx stub_status endpoint
- Sets up PostgreSQL monitoring user
- Starts BMI backend as systemd service
- Starts BMI custom exporter with PM2
- Installs and configures Promtail for logs
- **You'll be asked for:** Monitoring Server Private IP

**Expected output:**
```
✓ Node Exporter started successfully
✓ PostgreSQL Exporter started successfully
✓ Nginx Exporter started successfully
✓ BMI Application Exporter started successfully
✓ Promtail started successfully

All exporters are running successfully!
```

### 3. Verify in Prometheus (2 minutes)

1. Open browser: `http://MONITORING_SERVER_PUBLIC_IP:9090`
2. Click **Status** → **Targets**
3. Verify all targets show as **UP** (green):
   - ✓ prometheus
   - ✓ node_exporter
   - ✓ node_exporter_monitoring
   - ✓ postgresql
   - ✓ nginx
   - ✓ bmi-backend

### 4. Access Grafana (2 minutes)

1. Open browser: `http://MONITORING_SERVER_PUBLIC_IP:3001`
2. Login:
   - **Username:** `admin`
   - **Password:** `admin`
3. Change password when prompted

### 5. Import Dashboards (3 minutes)

**Note:** If you used the automated setup, datasources are already configured!

#### Import Application Dashboard

1. In Grafana, click **Dashboards** → **Import**
2. Click **Upload JSON file**
3. Select:
   ```
   monitoring/3-tier-app/dashboards/three-tier-application-dashboard.json
   ```
4. Select **Prometheus** as the data source
5. Click **Import**

#### Import Logs Dashboard (Optional)

1. Click **Dashboards** → **Import**
2. Upload:
   ```
   monitoring/3-tier-app/dashboards/loki-logs-dashboard.json
   ```
3. Select **Loki** as the data source
4. Click **Import**

### 6. View Your Metrics! 🎉

You should now see:

**Application Status:**
- ✓ Backend Status (green = UP)
- ✓ Database Status (green = UP)
- ✓ Frontend Status (green = UP)

**Metrics Panels:**
- Total Measurements
- Recent Activity (24h, 1h)
- Average BMI
- BMI Category Distribution
- CPU/Memory Usage
- Database Connections
- Nginx Request Rate
- System Resources

## Quick Verification Commands

### On Monitoring Server

```bash
# Check all services running
sudo systemctl status prometheus grafana-server loki alertmanager node_exporter

# All should show: Active: active (running)
```

### On Application Server

```bash
# Check systemd services
sudo systemctl status node_exporter postgres_exporter nginx_exporter promtail

# Check PM2 exporter
pm2 status  # Should show bmi-app-exporter online

# Test all exporters respond
curl -s http://localhost:9100/metrics | head -5   # Node Exporter
curl -s http://localhost:9187/metrics | head -5   # PostgreSQL
curl -s http://localhost:9113/metrics | head -5   # Nginx
curl -s http://localhost:9091/metrics | head -5   # BMI App
```

## Troubleshooting

### Targets Show as DOWN in Prometheus

**Check connectivity from monitoring server:**
```bash
# SSH to monitoring server
curl http://APPLICATION_SERVER_PRIVATE_IP:9100/metrics
```

If it fails:
```bash
# On application server, check firewall
sudo ufw status

# Ensure monitoring server IP is allowed
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9100 proto tcp
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9187 proto tcp
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9113 proto tcp
sudo ufw allow from MONITORING_SERVER_PRIVATE_IP to any port 9091 proto tcp
sudo ufw reload
```

### BMI Exporter Shows Errors

```bash
# Check logs
pm2 logs bmi-app-exporter --lines 50

# Common issues:
# 1. Database connection - check backend/.env
# 2. Missing dependencies - run: cd monitoring/exporters/bmi-app-exporter && npm install

# Restart exporter
pm2 restart bmi-app-exporter
```

### Grafana Shows "No Data"

1. **Check Prometheus data source:**
   - Grafana → Configuration → Data Sources → Prometheus
   - URL should be: `http://localhost:9090`
   - Click "Save & Test" - should show green checkmark

2. **Check metrics are being collected:**
   - Open Prometheus: `http://MONITORING_SERVER_IP:9090`
   - Run query: `up`
   - Should show all targets with value 1

3. **Refresh Grafana dashboard:**
   - Change time range to "Last 5 minutes"
   - Click refresh icon

### PostgreSQL Exporter Issues

```bash
# Test database connection
sudo -u postgres psql -d bmidb -c "SELECT version();"

# Check exporter logs
sudo journalctl -u postgres_exporter -n 50 --no-pager

# Verify environment file exists
sudo cat /etc/default/postgres_exporter

# Restart exporter
sudo systemctl restart postgres_exporter
```

## What to Monitor

### Key Metrics to Watch

1. **System Health:**
   - CPU usage < 80%
   - Memory usage < 85%
   - Disk space > 20%

2. **Application Health:**
   - Backend Status = UP (green)
   - Recent measurements > 0
   - No collection errors

3. **Database Health:**
   - Active connections < 80
   - Transaction rate steady
   - No deadlocks

4. **Frontend Health:**
   - Nginx Status = UP (green)
   - Active connections reasonable
   - Request rate normal

### Setting Up Alerts

Alerts are pre-configured for:
- High CPU/Memory/Disk usage
- Services down
- High database connections
- Application errors

To add email notifications:
1. Edit AlertManager config: `/etc/alertmanager/alertmanager.yml`
2. Add your email settings
3. Restart: `sudo systemctl restart alertmanager`

## Next Steps

### 1. Create Test Data

Generate some measurements to see metrics in action:

```bash
curl -X POST http://YOUR_APP_SERVER_IP/api/measurements \
  -H "Content-Type: application/json" \
  -d '{
    "weightKg": 70,
    "heightCm": 175,
    "age": 30,
    "sex": "male",
    "activity": "moderate"
  }'
```

Then refresh Grafana dashboard to see updated metrics!

### 2. Explore Grafana

- Try different time ranges
- Zoom in on graphs
- Set up dashboard variables
- Create custom panels

### 3. Set Up Alerting

- Configure AlertManager with your email
- Test alert rules
- Set up Slack/Discord notifications

### 4. Monitor Logs

- Add Loki data source in Grafana
- Create log exploration dashboards
- Set up log-based alerts

## Useful Commands Reference

```bash
# Monitoring Server
sudo systemctl status prometheus grafana-server loki alertmanager
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f

# Application Server
sudo systemctl status node_exporter postgres_exporter nginx_exporter promtail
pm2 status
pm2 logs bmi-app-exporter

# Test connectivity (from monitoring server)
curl http://APP_SERVER_IP:9100/metrics | head -10
curl http://APP_SERVER_IP:9187/metrics | grep pg_ | head -10
curl http://APP_SERVER_IP:9113/metrics | grep nginx | head -10
curl http://APP_SERVER_IP:9091/metrics | grep bmi | head -10

# Restart services
sudo systemctl restart prometheus grafana-server
pm2 restart bmi-app-exporter
```

## Support

If you encounter issues:

1. **Check the comprehensive manual guides:**
   - [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md) - 1400+ lines with troubleshooting
   - [MANUAL_APPLICATION_SERVER_SETUP.md](MANUAL_APPLICATION_SERVER_SETUP.md) - 1800+ lines with diagnostics
   - Both include extensive troubleshooting, maintenance, and security sections

2. **Review logs:**
   ```bash
   sudo journalctl -u <service-name> -n 100 --no-pager
   ```

3. **Verify configuration files:**
   - `/etc/prometheus/prometheus.yml`
   - `/etc/grafana/grafana.ini`
   - `/etc/loki/loki-config.yml`
   - Backend `.env` file

## Success Checklist

- [ ] Both scripts ran without errors
- [ ] All services show as "active (running)"
- [ ] Prometheus shows all targets as UP
- [ ] Grafana accessible and password changed
- [ ] Dashboard imported and showing data
- [ ] All status indicators are green
- [ ] Metrics updating in real-time
- [ ] Can view logs in Loki (optional)

**Congratulations!** Your three-tier application is now fully monitored! 🎉

---

**Time to setup:** ~30 minutes
**Difficulty:** Easy (automated scripts)
**Result:** Complete production-ready monitoring stack

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
