# Three-Tier Application Monitoring Setup

Complete monitoring solution for the BMI Health Tracker three-tier application using Prometheus, Grafana, Loki, and AlertManager.

## Overview

This folder contains everything you need to set up comprehensive monitoring for your three-tier BMI Health Tracker application:

- **Frontend Tier**: Nginx web server monitoring
- **Backend Tier**: Node.js application and business metrics
- **Database Tier**: PostgreSQL performance and health
- **System Tier**: Server resources (CPU, RAM, disk, network)
- **Logs**: Centralized log aggregation with Loki

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Server                        │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────┐  ┌──────────────┐   │
│  │Prometheus│  │ Grafana  │  │ Loki │  │ AlertManager │   │
│  │  :9090   │  │  :3001   │  │:3100 │  │    :9093     │   │
│  └────┬─────┘  └────┬─────┘  └──┬───┘  └──────────────┘   │
│       │             │            │                          │
│       │ Scrapes     │ Display    │ Logs                     │
│       │ Metrics     │ Dashboards │ Aggregation              │
└───────┼─────────────┼────────────┼──────────────────────────┘
        │             │            │
        │             │            │
        ▼             ▼            ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Server (BMI App)                   │
│                                                             │
│  ┌──────────┐  ┌─────────────┐  ┌──────────────┐          │
│  │  Nginx   │  │  Node.js    │  │  PostgreSQL  │          │
│  │ (Static) │  │  (Backend)  │  │  (Database)  │          │
│  └────┬─────┘  └──────┬──────┘  └──────┬───────┘          │
│       │               │                 │                   │
│  ┌────▼────┐    ┌─────▼────┐     ┌─────▼──────┐           │
│  │ Nginx   │    │   BMI    │     │PostgreSQL  │           │
│  │Exporter │    │ Exporter │     │  Exporter  │           │
│  └─────────┘    └──────────┘     └────────────┘           │
│                                                             │
│  ┌────────────────────────────────────────────┐            │
│  │      Node Exporter (System Metrics)        │            │
│  └────────────────────────────────────────────┘            │
│                                                             │
│  ┌────────────────────────────────────────────┐            │
│  │      Promtail (Log Shipping)               │            │
│  └────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Features

### System Monitoring
- CPU, memory, disk, and network usage
- System load and process statistics
- Disk I/O performance

### Frontend Monitoring (Nginx)
- HTTP request rates
- Active connections
- Response times
- Error rates

### Backend Monitoring (Node.js)
- Total measurements in database
- Recent measurement activity
- Average BMI calculations
- BMI category distribution
- Activity level distribution
- Gender distribution
- Database connection pool statistics

### Database Monitoring (PostgreSQL)
- Active connections
- Transaction rates (commits/rollbacks)
- Database size
- Table sizes
- Query performance
- Deadlocks and conflicts

### Log Aggregation
- System logs
- Nginx access and error logs
- PostgreSQL logs
- Application logs (PM2)

## Quick Start

### Two-Server Setup

You need TWO Ubuntu 22.04 servers:

1. **Monitoring Server**: Runs Prometheus, Grafana, Loki, AlertManager
2. **Application Server**: Your BMI app with all exporters

### Automated Setup (Recommended)

#### Step 1: Setup Monitoring Server

```bash
# SSH to monitoring server
ssh ubuntu@monitoring-server-ip

# Clone repository
git clone <your-repo-url>
cd single-server-3tier-webapp-monitoring

# Make script executable
chmod +x monitoring/3-tier-app/scripts/setup-monitoring-server.sh

# Run setup script
sudo ./monitoring/3-tier-app/scripts/setup-monitoring-server.sh
```

The script will:
- Install Prometheus, Grafana, Loki, AlertManager, Node Exporter
- Configure all services
- Set up firewall rules
- Ask for your application server IP

#### Step 2: Setup Application Server

```bash
# SSH to application server (where BMI app is running)
ssh ubuntu@application-server-ip

# Navigate to project
cd /path/to/single-server-3tier-webapp-monitoring

# Make script executable
chmod +x monitoring/3-tier-app/scripts/setup-application-server.sh

# Run setup script
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
```

The script will:
- Install Node Exporter, PostgreSQL Exporter, Nginx Exporter
- Install and configure BMI custom exporter
- Install Promtail for log shipping
- Configure firewall rules
- Ask for your monitoring server IP

#### Step 3: Access Grafana

```bash
# Open browser
http://MONITORING_SERVER_PUBLIC_IP:3001

# Login credentials
Username: admin
Password: admin (change on first login)
```

#### Step 4: Import Dashboard

1. In Grafana, click **Dashboards** → **Import**
2. Upload the dashboard JSON file:
   ```
   monitoring/3-tier-app/dashboards/three-tier-application-dashboard.json
   ```
3. Select **Prometheus** as the data source
4. Click **Import**

### Manual Setup

For detailed step-by-step manual setup:

- **Monitoring Server**: See [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md)
- **Application Server**: See [MANUAL_APPLICATION_SERVER_SETUP.md](MANUAL_APPLICATION_SERVER_SETUP.md)

## Folder Structure

```
monitoring/3-tier-app/
├── README.md                              # This file
├── MANUAL_MONITORING_SERVER_SETUP.md      # Manual setup for monitoring server
├── MANUAL_APPLICATION_SERVER_SETUP.md     # Manual setup for application server
├── scripts/
│   ├── setup-monitoring-server.sh         # Automated monitoring server setup
│   └── setup-application-server.sh        # Automated application server setup
├── config/
│   ├── prometheus.yml                     # Prometheus configuration
│   └── alert_rules.yml                    # Alert rules
└── dashboards/
    └── three-tier-application-dashboard.json  # Grafana dashboard
```

## What Gets Monitored

### Metrics Collected

| Metric Type | Exporter | Port | Description |
|------------|----------|------|-------------|
| System Metrics | Node Exporter | 9100 | CPU, RAM, Disk, Network |
| Database Metrics | PostgreSQL Exporter | 9187 | Connections, transactions, size |
| Web Server Metrics | Nginx Exporter | 9113 | Requests, connections, status |
| Application Metrics | BMI Custom Exporter | 9091 | Business metrics, BMI data |
| Logs | Promtail | 9080 | All system and application logs |

### Key Application Metrics

- `bmi_measurements_total` - Total measurements in database
- `bmi_measurements_created_24h` - Measurements in last 24 hours
- `bmi_measurements_created_1h` - Measurements in last hour
- `bmi_average_value` - Average BMI value
- `bmi_category_count` - Count by BMI category
- `bmi_activity_level_count` - Count by activity level
- `bmi_gender_count` - Count by gender
- `bmi_database_size_bytes` - Database size
- `bmi_app_healthy` - Application health status

### Alert Rules

Alerts are configured for:

- **System**: High CPU/Memory/Disk usage
- **Application**: Backend down, unhealthy status
- **Database**: High connections, deadlocks, down
- **Frontend**: Nginx down, high connection rate
- **Monitoring**: Target down, config reload failed

## Access Points

After setup, you can access:

- **Grafana**: `http://MONITORING_SERVER_IP:3001`
  - Username: `admin`
  - Password: `admin` (change on first login)

- **Prometheus**: `http://MONITORING_SERVER_IP:9090`
  - Check targets: `/targets`
  - Run queries: `/graph`

- **AlertManager**: `http://MONITORING_SERVER_IP:9093`

- **Loki**: `http://MONITORING_SERVER_IP:3100`

## Verification

### Check Monitoring Server

```bash
# Check all services
sudo systemctl status prometheus grafana-server loki alertmanager node_exporter

# Test Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### Check Application Server

```bash
# Check systemd services
sudo systemctl status node_exporter postgres_exporter nginx_exporter promtail

# Check PM2 exporter
pm2 status

# Test exporters
curl http://localhost:9100/metrics | head -20  # Node Exporter
curl http://localhost:9187/metrics | grep pg_ | head -10  # PostgreSQL
curl http://localhost:9113/metrics | grep nginx | head -10  # Nginx
curl http://localhost:9091/metrics | grep bmi | head -10  # BMI App
```

### View in Grafana

1. Log in to Grafana
2. Go to **Dashboards** → **BMI Health Tracker - Three-Tier Application Dashboard**
3. Verify all panels show data
4. Check that all services show as "UP" (green)

## Troubleshooting

### Prometheus Shows Targets as DOWN

```bash
# From monitoring server, test connectivity to application server
curl http://APPLICATION_SERVER_PRIVATE_IP:9100/metrics
curl http://APPLICATION_SERVER_PRIVATE_IP:9187/metrics
curl http://APPLICATION_SERVER_PRIVATE_IP:9113/metrics
curl http://APPLICATION_SERVER_PRIVATE_IP:9091/metrics
```

If these fail:
- Check firewall rules on application server
- Verify exporters are running
- Check security groups (AWS)

### BMI Exporter Not Working

```bash
# Check PM2 status
pm2 status

# View logs
pm2 logs bmi-app-exporter --lines 100

# Restart
pm2 restart bmi-app-exporter

# Check database connection
curl http://localhost:9091/health
```

### PostgreSQL Exporter Issues

```bash
# Check service
sudo systemctl status postgres_exporter

# View logs
sudo journalctl -u postgres_exporter -n 50 --no-pager

# Test database connection
psql -U postgres_exporter -d bmidb -c "SELECT 1;"
```

### Grafana Shows "No Data"

1. Check data sources are configured:
   - **Configuration** → **Data Sources**
   - Verify Prometheus URL: `http://localhost:9090`
   - Click "Save & Test"

2. Check Prometheus is scraping:
   - Go to Prometheus: `http://MONITORING_SERVER_IP:9090/targets`
   - All targets should be UP

3. Verify metrics exist:
   - In Prometheus, go to **Graph**
   - Query: `up`
   - Should show all targets

## Maintenance

### Update Exporters

```bash
# Stop services
sudo systemctl stop node_exporter postgres_exporter nginx_exporter
pm2 stop bmi-app-exporter

# Download new versions (follow installation steps)
# Restart services

sudo systemctl start node_exporter postgres_exporter nginx_exporter
pm2 start bmi-app-exporter
```

### Backup Grafana Dashboards

```bash
# Export from Grafana UI
# Dashboards → Manage → Select Dashboard → Settings → JSON Model

# Or use API
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://MONITORING_SERVER_IP:3001/api/dashboards/uid/bmi-3tier-dashboard > dashboard-backup.json
```

### View Logs

```bash
# Prometheus
sudo journalctl -u prometheus -f

# Grafana
sudo journalctl -u grafana-server -f

# Loki
sudo journalctl -u loki -f

# Application exporters
sudo journalctl -u node_exporter -f
sudo journalctl -u postgres_exporter -f
sudo journalctl -u nginx_exporter -f
pm2 logs bmi-app-exporter
```

## Security Best Practices

1. **Change default passwords** (Grafana admin)
2. **Use private IPs** for communication between servers
3. **Configure firewall** to restrict access to monitoring ports
4. **Enable HTTPS** for Grafana in production
5. **Secure PostgreSQL monitoring user** with strong password
6. **Regular updates** of all monitoring components
7. **Backup configurations** regularly

## Performance Impact

The monitoring setup is designed to be lightweight:

- **Node Exporter**: ~10-20 MB RAM, <1% CPU
- **PostgreSQL Exporter**: ~20-30 MB RAM, <1% CPU
- **Nginx Exporter**: ~5-10 MB RAM, <0.5% CPU
- **BMI Custom Exporter**: ~30-50 MB RAM, <1% CPU
- **Promtail**: ~20-40 MB RAM, <1% CPU

Total overhead: ~100-150 MB RAM, ~2-3% CPU

## Support and Documentation

- **Prometheus Docs**: https://prometheus.io/docs/
- **Grafana Docs**: https://grafana.com/docs/
- **Loki Docs**: https://grafana.com/docs/loki/
- **Node Exporter**: https://github.com/prometheus/node_exporter
- **PostgreSQL Exporter**: https://github.com/prometheus-community/postgres_exporter
- **Nginx Exporter**: https://github.com/nginxinc/nginx-prometheus-exporter

## License

This monitoring setup is part of the BMI Health Tracker project.

## Contributing

To improve this monitoring setup:

1. Test the setup on a fresh environment
2. Document any issues or improvements
3. Update dashboards with additional useful metrics
4. Add more alert rules as needed

---

**Questions or Issues?**

Check the manual setup guides for detailed troubleshooting steps:
- [Monitoring Server Manual Setup](MANUAL_MONITORING_SERVER_SETUP.md)
- [Application Server Manual Setup](MANUAL_APPLICATION_SERVER_SETUP.md)
