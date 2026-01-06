# Three-Tier Application Monitoring - Documentation Index

## 📚 Documentation Overview

This monitoring setup provides complete observability for your BMI Health Tracker three-tier application. Choose the documentation that best fits your needs:

---

## 🚀 Getting Started (Start Here!)

### [QUICK_START.md](QUICK_START.md)
**⏱️ Time:** 30 minutes | **👤 Skill:** Beginner

The fastest way to get monitoring up and running. Uses automated scripts for both servers.

**Perfect for:**
- Quick deployment
- Production environments
- First-time setup
- Those who want results fast

**What you get:**
- Complete monitoring stack in 30 minutes
- Automated installation
- Pre-configured dashboards
- Working out of the box

---

## 📖 Complete Documentation

### [README.md](README.md)
**⏱️ Time:** 10 min read | **👤 Skill:** All levels

Comprehensive overview of the entire monitoring solution.

**Covers:**
- Architecture and design
- All components explained
- Features and capabilities
- Verification steps
- Troubleshooting guide
- Maintenance procedures

**Read this to:**
- Understand what you're building
- Learn about each component
- Plan your deployment
- Find troubleshooting steps

---

## 📋 Setup Guides

### Automated Setup (Recommended)

#### [QUICK_START.md](QUICK_START.md)
- ✅ Automated scripts
- ✅ Step-by-step instructions
- ✅ Verification commands
- ✅ Troubleshooting included
- ⏱️ Setup time: ~30 minutes

**Files you'll use:**
- `scripts/setup-monitoring-server.sh`
- `scripts/setup-application-server.sh`
- `dashboards/three-tier-application-dashboard.json`

---

### Manual Setup (For Learning)

#### [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md)
**⏱️ Time:** 1-2 hours | **👤 Skill:** Intermediate

Detailed manual installation of the monitoring server.

**Installs:**
- Prometheus
- Grafana
- Loki
- AlertManager
- Node Exporter

**Learn about:**
- How each component works
- Configuration options
- Service management
- Firewall setup

**Choose manual setup if you:**
- Want to understand each component
- Need custom configuration
- Are learning monitoring concepts
- Prefer step-by-step control

---

#### [MANUAL_APPLICATION_SERVER_SETUP.md](MANUAL_APPLICATION_SERVER_SETUP.md)
**⏱️ Time:** 1-2 hours | **👤 Skill:** Intermediate

Detailed manual installation of all application exporters.

**Installs:**
- Node Exporter (system metrics)
- PostgreSQL Exporter (database metrics)
- Nginx Exporter (web server metrics)
- BMI Custom Exporter (application metrics)
- Promtail (log shipping)

**Learn about:**
- Exporter configuration
- Database monitoring user setup
- PM2 process management
- Log collection setup

**Choose manual setup if you:**
- Want to customize each exporter
- Need to understand the details
- Are troubleshooting issues
- Prefer hands-on learning

---

## 📊 Reference Documentation

### [SETUP_SUMMARY.md](SETUP_SUMMARY.md)
**⏱️ Time:** 5 min read | **👤 Skill:** All levels

Quick reference guide covering everything in one place.

**Includes:**
- Complete folder structure
- All metrics explained
- Alert rules list
- Network diagram
- Security configuration
- FAQ section

**Use this for:**
- Quick reference
- Understanding what's monitored
- Checking configuration
- Finding specific information

---

## 🗂️ Configuration Files

### [config/prometheus.yml](config/prometheus.yml)
Prometheus scrape configuration for all exporters.

**Scrapes:**
- System metrics (Node Exporter)
- Database metrics (PostgreSQL)
- Web server metrics (Nginx)
- Application metrics (BMI Custom)

**Features:**
- Labeled by tier (infrastructure, data, frontend, application)
- 15-second scrape interval
- Pre-configured for application server

---

### [config/alert_rules.yml](config/alert_rules.yml)
Comprehensive alert rules for all tiers.

**Alert Categories:**
- System alerts (CPU, Memory, Disk)
- Application alerts (Backend health)
- Database alerts (Connections, Deadlocks)
- Frontend alerts (Nginx status)
- Monitoring alerts (Targets down)

**Severity Levels:**
- ⚠️ Warning (non-critical issues)
- 🔴 Critical (requires immediate attention)

---

## 📈 Dashboards

### [dashboards/three-tier-application-dashboard.json](dashboards/three-tier-application-dashboard.json)
Pre-built Grafana dashboard for complete application monitoring.

**Sections:**
1. **Service Status** - UP/DOWN indicators
2. **Application Metrics** - Measurements, BMI stats
3. **Database Metrics** - Connections, transactions
4. **Frontend Metrics** - Nginx requests, connections
5. **System Resources** - CPU, memory, disk, network

**Features:**
- Real-time updates
- Auto-refresh every 10 seconds
- Interactive graphs
- Filterable by time range
- Beautiful visualizations

---

## 🛠️ Scripts

### [scripts/setup-monitoring-server.sh](scripts/setup-monitoring-server.sh)
**⏱️ Runtime:** ~10 minutes

Automated installation script for the monitoring server.

**What it does:**
- Installs all monitoring components
- Configures services
- Sets up firewall
- Starts all services
- Verifies installation

**Usage:**
```bash
chmod +x monitoring/3-tier-app/scripts/setup-monitoring-server.sh
sudo ./monitoring/3-tier-app/scripts/setup-monitoring-server.sh
```

---

### [scripts/setup-application-server.sh](scripts/setup-application-server.sh)
**⏱️ Runtime:** ~15 minutes

Automated installation script for the application server.

**What it does:**
- Installs all exporters
- Configures Nginx, PostgreSQL, BMI app monitoring
- Sets up Promtail for logs
- Configures firewall
- Verifies all exporters

**Usage:**
```bash
chmod +x monitoring/3-tier-app/scripts/setup-application-server.sh
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
```

---

## 🎯 Quick Navigation by Task

### "I want to set this up quickly"
→ Go to [QUICK_START.md](QUICK_START.md)

### "I want to understand how it works"
→ Start with [README.md](README.md), then manual setup guides

### "I'm having issues and need to troubleshoot"
→ Check [README.md](README.md) Troubleshooting section

### "I want to see what metrics are collected"
→ Go to [SETUP_SUMMARY.md](SETUP_SUMMARY.md) → "What Gets Monitored"

### "I need to customize alert rules"
→ Edit [config/alert_rules.yml](config/alert_rules.yml)

### "I want to modify the dashboard"
→ Import [dashboards/three-tier-application-dashboard.json](dashboards/three-tier-application-dashboard.json) and edit in Grafana

### "I need to add more servers to monitor"
→ See [README.md](README.md) → "Maintenance" section

### "I want to configure email alerts"
→ See [QUICK_START.md](QUICK_START.md) → "Setting Up Alerts"

---

## 📁 Complete File Structure

```
monitoring/3-tier-app/
│
├── 📄 INDEX.md                               ← You are here!
├── 📄 README.md                              ← Main documentation
├── 📄 QUICK_START.md                         ← 30-minute automated setup
├── 📄 SETUP_SUMMARY.md                       ← Complete reference guide
├── 📄 MANUAL_MONITORING_SERVER_SETUP.md      ← Detailed monitoring server guide
├── 📄 MANUAL_APPLICATION_SERVER_SETUP.md     ← Detailed application server guide
│
├── 📂 scripts/
│   ├── 🔧 setup-monitoring-server.sh         ← Automated monitoring setup
│   └── 🔧 setup-application-server.sh        ← Automated application setup
│
├── 📂 config/
│   ├── ⚙️ prometheus.yml                     ← Prometheus configuration
│   └── ⚙️ alert_rules.yml                    ← Alert rules
│
└── 📂 dashboards/
    └── 📊 three-tier-application-dashboard.json  ← Grafana dashboard
```

---

## 🎓 Learning Path

### Beginner Path
1. Read [README.md](README.md) - Overview (10 min)
2. Follow [QUICK_START.md](QUICK_START.md) - Automated setup (30 min)
3. Explore dashboard in Grafana (15 min)
4. Review [SETUP_SUMMARY.md](SETUP_SUMMARY.md) - Understanding (10 min)

**Total time:** ~65 minutes

---

### Advanced Path
1. Read [README.md](README.md) - Complete understanding (20 min)
2. Follow [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md) (1-2 hours)
3. Follow [MANUAL_APPLICATION_SERVER_SETUP.md](MANUAL_APPLICATION_SERVER_SETUP.md) (1-2 hours)
4. Customize [config/alert_rules.yml](config/alert_rules.yml) (30 min)
5. Modify dashboard (30 min)

**Total time:** ~3-5 hours

---

## 💡 Tips for Success

### Before You Start
- ✅ Have two Ubuntu 22.04 servers ready
- ✅ Ensure BMI application is deployed on application server
- ✅ Note down server IP addresses (public and private)
- ✅ Verify firewall/security group access
- ✅ Have sudo access on both servers

### During Setup
- ✅ Follow instructions carefully
- ✅ Keep terminal output visible for errors
- ✅ Test connectivity between servers
- ✅ Verify each service starts successfully
- ✅ Check Prometheus targets frequently

### After Setup
- ✅ Import the Grafana dashboard
- ✅ Create test data to verify metrics
- ✅ Set up alert notifications
- ✅ Bookmark Grafana URL
- ✅ Document your setup

---

## 🆘 Getting Help

### Step 1: Check Documentation
- Review the relevant setup guide
- Check troubleshooting sections
- Verify all prerequisites

### Step 2: Check Logs
```bash
# Monitoring server
sudo journalctl -u prometheus -n 50
sudo journalctl -u grafana-server -n 50

# Application server
sudo journalctl -u node_exporter -n 50
pm2 logs bmi-app-exporter --lines 50
```

### Step 3: Verify Configuration
- Check Prometheus targets: `http://MONITORING_IP:9090/targets`
- Test exporter endpoints manually
- Verify firewall rules

### Step 4: Common Issues
See [QUICK_START.md](QUICK_START.md) → "Troubleshooting" section

---

## ✨ Features Summary

| Feature | Component | Benefit |
|---------|-----------|---------|
| Real-time Metrics | Prometheus | Instant visibility into system health |
| Beautiful Dashboards | Grafana | Easy-to-understand visualizations |
| Log Aggregation | Loki | Centralized log search and analysis |
| Smart Alerting | AlertManager | Proactive issue detection |
| System Monitoring | Node Exporter | Server health tracking |
| Database Insights | PostgreSQL Exporter | Database performance metrics |
| Web Server Metrics | Nginx Exporter | Frontend layer monitoring |
| Business Metrics | BMI Custom Exporter | Application-specific insights |

---

## 🚀 Ready to Start?

Choose your path:

**Quick Setup (30 min):**  
→ [QUICK_START.md](QUICK_START.md)

**Learning Setup (3-5 hours):**  
→ [MANUAL_MONITORING_SERVER_SETUP.md](MANUAL_MONITORING_SERVER_SETUP.md)

**Just Browsing:**  
→ [README.md](README.md)

---

**Happy Monitoring!** 📊✨

