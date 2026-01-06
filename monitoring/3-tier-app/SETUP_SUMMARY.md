# Three-Tier Application Monitoring - Complete Setup Summary

## What Has Been Created

A comprehensive monitoring solution for your BMI Health Tracker three-tier application with both **manual** and **automated** setup options.

## Folder Structure

```
monitoring/3-tier-app/
├── README.md                               # Main documentation
├── QUICK_START.md                          # Fast setup guide (30 min)
├── MANUAL_MONITORING_SERVER_SETUP.md       # Detailed monitoring server manual setup
├── MANUAL_APPLICATION_SERVER_SETUP.md      # Detailed application server manual setup
│
├── scripts/
│   ├── setup-monitoring-server.sh          # Automated monitoring server installer
│   └── setup-application-server.sh         # Automated application server installer
│
├── config/
│   ├── prometheus.yml                      # Prometheus scrape configuration
│   └── alert_rules.yml                     # Alert rules for all tiers
│
└── dashboards/
    └── three-tier-application-dashboard.json  # Comprehensive Grafana dashboard
```

## Setup Options

### Option 1: Automated Setup (Recommended)

**Time:** ~30 minutes  
**Difficulty:** Easy  
**Best for:** Quick deployment, production use

**Steps:**
1. Run `setup-monitoring-server.sh` on monitoring server
2. Run `setup-application-server.sh` on application server
3. Import dashboard in Grafana
4. Done!

**Follow:** [QUICK_START.md](QUICK_START.md)

### Option 2: Manual Setup

**Time:** ~2-3 hours  
**Difficulty:** Intermediate  
**Best for:** Learning, customization, understanding components

**Steps:**
1. Follow step-by-step guide for monitoring server
2. Follow step-by-step guide for application server
3. Import dashboard in Grafana
4. Done!

**Follow:**
- [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md)
- [MANUAL_APPLICATION_SERVER_SETUP.md](MANUAL_APPLICATION_SERVER_SETUP.md)

## What Gets Monitored

### 1. System Tier (Infrastructure)
**Exporter:** Node Exporter (Port 9100)

**Metrics:**
- CPU usage per core and total
- Memory usage (total, available, cached)
- Disk usage and I/O
- Network traffic (bytes in/out)
- System load (1m, 5m, 15m)
- Process count

### 2. Frontend Tier (Nginx)
**Exporter:** Nginx Exporter (Port 9113)

**Metrics:**
- Active connections
- Total requests
- Request rate
- Connection states (reading, writing, waiting)
- Accepted/handled connections

### 3. Backend Tier (Node.js Application)
**Exporter:** BMI Custom Application Exporter (Port 9091)

**Metrics:**
- Total measurements in database
- Measurements created in last 24 hours
- Measurements created in last 1 hour
- Average BMI value
- BMI category distribution (Underweight, Normal, Overweight, Obese)
- Activity level distribution
- Gender distribution
- Database connection pool stats
- Application health status
- Metrics collection errors

### 4. Database Tier (PostgreSQL)
**Exporter:** PostgreSQL Exporter (Port 9187)

**Metrics:**
- Active database connections
- Transaction rates (commits/rollbacks)
- Database size in bytes
- Table sizes
- Query statistics
- Cache hit ratios
- Deadlocks
- Tuple statistics (inserted, updated, deleted)

### 5. Logs
**Shipper:** Promtail (Port 9080)

**Logs Collected:**
- System logs (`/var/log/*.log`)
- Nginx access logs
- Nginx error logs
- PostgreSQL logs
- PM2 application logs

## Monitoring Stack Components

### Monitoring Server

| Component | Port | Purpose |
|-----------|------|---------|
| **Prometheus** | 9090 | Metrics collection and storage |
| **Grafana** | 3001 | Visualization and dashboards |
| **Loki** | 3100 | Log aggregation |
| **AlertManager** | 9093 | Alert management and routing |
| **Node Exporter** | 9100 | Monitor the monitoring server itself |

### Application Server

| Component | Port | Purpose |
|-----------|------|---------|
| **Node Exporter** | 9100 | System metrics |
| **PostgreSQL Exporter** | 9187 | Database metrics |
| **Nginx Exporter** | 9113 | Web server metrics |
| **BMI Custom Exporter** | 9091 | Application metrics |
| **Promtail** | 9080 | Log shipping |

## Alert Rules Configured

### System Alerts
- ⚠️ High CPU Usage (>80% for 5min)
- 🔴 Critical CPU Usage (>95% for 2min)
- ⚠️ High Memory Usage (>85% for 5min)
- 🔴 Critical Memory Usage (>95% for 2min)
- ⚠️ Low Disk Space (<20% for 5min)
- 🔴 Critical Disk Space (<10% for 2min)

### Application Alerts
- 🔴 Backend Application Down (2min)
- 🔴 Backend Application Unhealthy (3min)
- ⚠️ High Metrics Collection Errors
- ⚠️ No Recent Measurements (30min)

### Database Alerts
- 🔴 Database Down (2min)
- ⚠️ High Database Connections (>80 for 5min)
- 🔴 Critical Database Connections (>95 for 2min)
- ⚠️ Database Deadlocks Detected
- ⚠️ High Transaction Rollback Rate (>10%)

### Frontend Alerts
- 🔴 Nginx Down (2min)
- ⚠️ High Nginx Connection Rate (>100/sec)
- ⚠️ High Active Connections (>200 for 10min)

### Monitoring Infrastructure Alerts
- ⚠️ Prometheus Target Down (5min)
- 🔴 Prometheus Config Reload Failed
- ⚠️ Prometheus TSDB Compactions Failing

## Dashboard Overview

The pre-built Grafana dashboard includes:

### Top Row - Service Status
- 🟢 Backend Status (UP/DOWN)
- 🟢 Database Status (UP/DOWN)
- 🟢 Frontend Status (UP/DOWN)
- 📊 CPU Usage Graph
- 📊 Memory Usage Graph

### Application Metrics Row
- 📈 Total Measurements
- 📈 Last 24h Measurements
- 📈 Average BMI
- 📈 Last 1h Measurements
- 🥧 BMI Category Distribution
- 🥧 Gender Distribution

### Database Metrics Row
- 📊 Active Connections
- 📊 Database Transactions (Commits/Rollbacks)
- 💾 Database Size
- 💾 Table Size

### Frontend Metrics Row
- 📊 Active Nginx Connections
- 📊 HTTP Requests Rate
- 📊 Connection States (Reading/Writing/Waiting)

### System Resources Row
- 📊 Disk Usage
- 📊 Network Traffic (Receive/Transmit)

## Network Communication

```
Internet
    │
    ├─→ :3001 → Grafana (Monitoring Server) ← You access dashboards
    ├─→ :9090 → Prometheus (Monitoring Server) ← Direct access (optional)
    │
    └─→ :80 → Nginx (Application Server) ← Users access BMI app

Internal Network:
    Monitoring Server ──→ Application Server
          :9090              :9100 (Node Exporter)
                            :9187 (PostgreSQL Exporter)
                            :9113 (Nginx Exporter)
                            :9091 (BMI Exporter)

    Application Server ──→ Monitoring Server
          Promtail           :3100 (Loki)
```

## Security Configuration

### Firewall Rules

**Monitoring Server:**
- Allow 22/tcp (SSH) from your IP
- Allow 3001/tcp (Grafana) from your IP
- Allow 9090/tcp (Prometheus) from your IP (optional)
- Allow 3100/tcp (Loki) from application server

**Application Server:**
- Allow 22/tcp (SSH) from your IP
- Allow 80/tcp (HTTP) from anywhere
- Allow 443/tcp (HTTPS) from anywhere
- Allow 9100,9187,9113,9091/tcp from monitoring server

### PostgreSQL Monitoring User

- Read-only access to `bmidb`
- No write permissions
- Limited to monitoring queries
- Strong password generated automatically

## Resource Requirements

### Monitoring Server
- **Minimum:** 2 vCPU, 4GB RAM, 30GB disk
- **Recommended:** 4 vCPU, 8GB RAM, 50GB disk
- **OS:** Ubuntu 22.04 LTS

### Application Server
- **Additional:** ~150MB RAM, ~3% CPU for all exporters
- **No impact** on application performance
- **OS:** Ubuntu 22.04 LTS

## Data Retention

- **Prometheus:** 30 days of metrics
- **Loki:** 31 days of logs (744 hours)
- **Grafana:** Unlimited dashboards/configs

To change retention:
- Prometheus: Edit `/etc/systemd/system/prometheus.service` → `--storage.tsdb.retention.time=`
- Loki: Edit `/etc/loki/loki-config.yml` → `retention_period:`

## Backup Recommendations

### What to Backup

1. **Grafana Dashboards:**
   - Export from UI or use API
   - Store JSON files in version control

2. **Configuration Files:**
   - `/etc/prometheus/prometheus.yml`
   - `/etc/prometheus/alert_rules.yml`
   - `/etc/alertmanager/alertmanager.yml`
   - `/etc/grafana/grafana.ini`

3. **Prometheus Data (optional):**
   - `/var/lib/prometheus/`
   - Can rebuild from scratch if lost

## Common Use Cases

### 1. Check Application Health

**Grafana Dashboard** → Top status indicators should be green

### 2. Investigate Performance Issues

**Grafana** → Check:
- CPU/Memory graphs for spikes
- Database connections for bottlenecks
- Request rates for unusual patterns

### 3. Troubleshoot Database Issues

**Prometheus** → Query:
```promql
pg_stat_database_numbackends{datname="bmidb"}
rate(pg_stat_database_xact_commit[5m])
```

### 4. View Application Logs

**Grafana** → Explore → Select Loki → Query logs

### 5. Test Alerts

**Prometheus** → Alerts → See active/firing alerts  
**AlertManager** → View alert routing and silences

## Maintenance Tasks

### Daily
- Check Grafana dashboard for anomalies
- Review any fired alerts

### Weekly
- Review disk usage on monitoring server
- Check for any DOWN targets in Prometheus

### Monthly
- Update exporters to latest versions
- Backup Grafana dashboards
- Review and tune alert thresholds

## Next Steps After Setup

1. ✅ **Verify** all services are running
2. ✅ **Access** Grafana and import dashboard
3. ✅ **Test** by creating sample measurements
4. ✅ **Configure** AlertManager email notifications
5. ✅ **Explore** Loki for log analysis
6. ✅ **Customize** dashboard for your needs
7. ✅ **Set up** Slack/Discord integrations (optional)
8. ✅ **Create** backup schedule

## Support Resources

### Documentation
- [README.md](README.md) - Main documentation
- [QUICK_START.md](QUICK_START.md) - Fast setup guide
- [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md) - Detailed monitoring setup
- [MANUAL_APPLICATION_SERVER_SETUP.md](MANUAL_APPLICATION_SERVER_SETUP.md) - Detailed application setup

### External Resources
- **Prometheus:** https://prometheus.io/docs/
- **Grafana:** https://grafana.com/docs/
- **Loki:** https://grafana.com/docs/loki/
- **AlertManager:** https://prometheus.io/docs/alerting/latest/alertmanager/

## Frequently Asked Questions

**Q: Can I monitor multiple application servers?**  
A: Yes! Just add more targets to `prometheus.yml` and run the application server setup script on each server.

**Q: How do I add email alerts?**  
A: Edit `/etc/alertmanager/alertmanager.yml` on monitoring server, add SMTP settings, restart AlertManager.

**Q: Can I use this in production?**  
A: Yes! This is a production-ready setup. Consider adding HTTPS for Grafana and using strong passwords.

**Q: What if I only have one server?**  
A: You can run monitoring and application on the same server, but two servers is recommended for production.

**Q: How do I scale this setup?**  
A: Add more application servers, consider Prometheus federation, or use Thanos for long-term storage.

**Q: Can I customize the dashboard?**  
A: Absolutely! Edit panels, add new queries, create your own dashboards.

## Success Metrics

After setup, you should have:

- ✅ All 5 exporters running and collecting metrics
- ✅ All Prometheus targets showing UP status
- ✅ Grafana dashboard displaying real-time data
- ✅ Alert rules configured and monitoring
- ✅ Logs being collected and viewable
- ✅ Zero impact on application performance
- ✅ Complete visibility into all three tiers

---

**Congratulations!** You now have enterprise-grade monitoring for your three-tier application! 🎉

For quick setup, start with: **[QUICK_START.md](QUICK_START.md)**
