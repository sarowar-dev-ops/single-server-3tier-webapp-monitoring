# BMI & Health Tracker

> A production-ready 3-tier web application with comprehensive monitoring stack for tracking health metrics including BMI, BMR, and daily calorie needs with trend visualization.

![Project Status](https://img.shields.io/badge/status-production--ready-brightgreen)
![Architecture](https://img.shields.io/badge/architecture-3--tier-blue)
![Platform](https://img.shields.io/badge/platform-AWS%20EC2-orange)
![Monitoring](https://img.shields.io/badge/monitoring-Prometheus%20%7C%20Grafana%20%7C%20Loki-informational)

---

## 📋 Table of Contents

- [What is This Project?](#-what-is-this-project)
- [For Junior DevOps Engineers](#-for-junior-devops-engineers)
- [Architecture Overview](#-architecture-overview)
- [Technology Stack](#-technology-stack)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start Deployment](#-quick-start-deployment)
- [Monitoring Stack Setup](#-monitoring-stack-setup)
- [Understanding 3-Tier Architecture](#-understanding-3-tier-architecture)
- [How Components Communicate](#-how-components-communicate)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)
- [API Documentation](#-api-documentation)

---

## 🎯 What is This Project?

**BMI & Health Tracker** is a full-stack web application that helps users:
- 📊 Track body measurements (weight, height, age, activity level)
- 🧮 Calculate health metrics automatically (BMI, BMR, daily calories)
- 📅 Store historical measurements with custom dates
- 📈 Visualize BMI trends over 30 days
- 📱 Access from any device (responsive design)

### Real-World Use Case

This application demonstrates a **production-grade 3-tier architecture** commonly used in enterprise environments. As a DevOps engineer, you'll frequently work with similar architectures for:
- E-commerce platforms (product catalog, shopping cart, checkout)
- SaaS applications (user management, data processing, analytics)
- Healthcare systems (patient records, appointments, billing)
- Financial services (transactions, reporting, compliance)

---

## 👨‍💻 For Junior DevOps Engineers

### What You'll Learn

By working with this project, you'll gain hands-on experience with:

✅ **Infrastructure Setup**
- Setting up Linux servers (Ubuntu)
- Installing and configuring services (PostgreSQL, Nginx, Node.js)
- Managing firewalls (UFW) and security

✅ **Application Deployment**
- Deploying Node.js backend applications
- Building and serving React frontends
- Running database migrations
- Process management with PM2

✅ **Networking & Routing**
- Configuring reverse proxies with Nginx
- Understanding HTTP request routing
- CORS (Cross-Origin Resource Sharing)
- Port management and exposure

✅ **Database Management**
- PostgreSQL installation and configuration
- Creating users, databases, and permissions
- Running SQL migrations
- Backup and restore procedures

✅ **Monitoring & Troubleshooting**
- Reading application logs
- Debugging connection issues
- Health check endpoints
- Performance monitoring with PM2

### Why This Project?

This project uses **real production patterns** you'll encounter in the industry:
- **Environment variables** for configuration management
- **Process managers** (PM2) for application reliability
- **Reverse proxies** (Nginx) for routing and security
- **Connection pooling** for database efficiency
- **Logging** for debugging and monitoring
- **Migrations** for database version control

---

## 🏗 Architecture Overview

### 3-Tier Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                         INTERNET                             │
│                      (Users/Browsers)                        │
└───────────────────────────┬──────────────────────────────────┘
                            │ HTTP/HTTPS (Port 80/443)
                            │
┌───────────────────────────▼──────────────────────────────────┐
│                    TIER 1: PRESENTATION                      │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │              Nginx Web Server (Port 80/443)              │ │
│ │  - Serves React static files (HTML, CSS, JS)             │ │
│ │  - Reverse proxy for API requests                        │ │
│ │  - SSL/TLS termination (HTTPS)                           │ │
│ │  - Compression & caching                                 │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│   Frontend: React 18 + Vite                                  │
│   - User Interface Components                                │
│   - Forms, Charts, Dashboard                                 │
│   - Client-side validation                                   │
└────────────────┬─────────────────────────┬───────────────────┘
                 │ Static Files            │ API Requests
                 │                         │ GET/POST /api/*
                 │                         │
                 │                         ▼
┌────────────────┴─────────────────────────┬───────────────────┐
│                 TIER 2: APPLICATION                          │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │         Node.js + Express API (Port 3000)                │ │
│ │  - RESTful API endpoints                                 │ │
│ │  - Business logic (BMI/BMR calculations)                 │ │
│ │  - Input validation                                      │ │
│ │  - Error handling                                        │ │
│ │  - Managed by PM2 process manager                        │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│   Backend API Routes:                                        │
│   - POST /api/measurements (create)                          │
│   - GET  /api/measurements (read all)                        │
│   - GET  /api/measurements/trends (analytics)                │
│   - GET  /health (health check)                              │
└───────────────────────────────┬──────────────────────────────┘
                                │ SQL Queries
                                │ (pg driver)
                                │
┌───────────────────────────────▼───────────────────────────────┐
│                     TIER 3: DATA                              │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │           PostgreSQL Database (Port 5432)                │  │
│ │  - Stores measurements table                             │  │
│ │  - Enforces data integrity (constraints)                 │  │
│ │  - Indexes for performance                               │  │
│ │  - Transaction management                                │  │
│ └──────────────────────────────────────────────────────────┘  │
│                                                               │
│   Database: bmidb                                             │
│   User: bmi_user                                              │
│   Table: measurements (12 columns)                            │
└───────────────────────────────────────────────────────────────┘
```

### What is Each Tier?

#### Tier 1: Presentation Layer (Frontend)
**What:** The user interface that people see and interact with  
**Technology:** React (JavaScript framework) built with Vite  
**Responsibility:** Display data, collect user input, render charts  
**Served by:** Nginx web server  

#### Tier 2: Application Layer (Backend)
**What:** The business logic and API that processes requests  
**Technology:** Node.js with Express framework  
**Responsibility:** Validate data, perform calculations, coordinate with database  
**Managed by:** PM2 process manager  

#### Tier 3: Data Layer (Database)
**What:** Storage for all application data  
**Technology:** PostgreSQL relational database  
**Responsibility:** Store, retrieve, and manage data persistently  
**Protected:** Only accessible from application layer (not public)  

---

## 💻 Technology Stack

### Backend (Application Tier)
| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 18+ LTS | JavaScript runtime for backend |
| **Express.js** | 4.18.2 | Web framework for REST API |
| **PostgreSQL Driver (pg)** | 8.10.0 | Database connection |
| **CORS** | 2.8.5 | Cross-origin request handling |
| **dotenv** | 16.0.0 | Environment variable management |
| **PM2** | Latest | Process manager for production |

### Frontend (Presentation Tier)
| Technology | Version | Purpose |
|------------|---------|---------|
| **React** | 18.2.0 | UI framework |
| **Vite** | 5.0.0 | Build tool & dev server |
| **Axios** | 1.4.0 | HTTP client for API calls |
| **Chart.js** | 4.4.0 | Data visualization library |
| **react-chartjs-2** | 5.2.0 | React wrapper for Chart.js |

### Database (Data Tier)
| Technology | Version | Purpose |
|------------|---------|---------|
| **PostgreSQL** | 14+ | Relational database management system |

### Infrastructure
| Technology | Purpose |
|------------|---------|
| **Nginx** | Web server & reverse proxy |
| **Ubuntu** | Operating system (22.04 LTS) |
| **UFW** | Firewall management |
| **Certbot** | SSL/TLS certificate management (optional) |

---

## ✨ Features

### User Features
- ✅ Add health measurements with custom dates
- ✅ View real-time statistics dashboard
- ✅ Browse historical measurements
- ✅ Visualize 30-day BMI trends with interactive charts
- ✅ Automatic health metric calculations
- ✅ Responsive design for mobile and desktop

### DevOps Features
- ✅ Automated deployment script
- ✅ Database migration system
- ✅ Health check endpoint for monitoring
- ✅ Structured logging (PM2)
- ✅ Environment-based configuration
- ✅ Connection pooling for database efficiency
- ✅ Nginx reverse proxy configuration
- ✅ Firewall rules (UFW)

### Health Calculations
- **BMI (Body Mass Index):** weight(kg) / height(m)²
- **BMI Category:** Underweight (<18.5), Normal (18.5-24.9), Overweight (25-29.9), Obese (≥30)
- **BMR (Basal Metabolic Rate):** Mifflin-St Jeor equation
  - Male: 10×weight + 6.25×height - 5×age + 5
  - Female: 10×weight + 6.25×height - 5×age - 161
- **Daily Calories:** BMR × activity level multiplier (1.2 to 1.9)

---

## 📦 Prerequisites

### For Local Development

#### Required Software
- **Node.js:** v18+ LTS ([Download](https://nodejs.org/))
- **npm:** v9+ (comes with Node.js)
- **PostgreSQL:** v14+ ([Download](https://www.postgresql.org/download/))
- **Git:** For version control

#### System Requirements
- **RAM:** 2GB minimum, 4GB recommended
- **Storage:** 1GB free space
- **OS:** Windows 10+, macOS 10.15+, or Linux (Ubuntu 20.04+)

### For Production Deployment (AWS EC2)

#### AWS Account Setup
1. Create an AWS account at [aws.amazon.com](https://aws.amazon.com)
2. Launch an EC2 instance:
   - **Instance Type:** t2.small or better (t2.micro may work but is slower)
   - **OS:** Ubuntu Server 22.04 LTS
   - **Storage:** 20GB gp3 EBS volume

#### Security Groups Configuration
Configure inbound rules:
- **SSH:** Port 22 (from your IP only)
- **HTTP:** Port 80 (from anywhere: 0.0.0.0/0)
- **HTTPS:** Port 443 (from anywhere: 0.0.0.0/0)

#### SSH Access
```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

---

## 🚀 Quick Start Guide

### Option A: Local Development (Recommended for Learning)

#### Step 1: Clone the Project
```bash
git clone <your-repo-url>
cd single-server-3tier-webapp-monitoring
```

#### Step 2: Setup Database
```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt update
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE USER bmi_user WITH PASSWORD 'your_password';
CREATE DATABASE bmidb OWNER bmi_user;
\c bmidb
GRANT ALL PRIVILEGES ON DATABASE bmidb TO bmi_user;
EOF

# Run migrations
sudo -u postgres psql -U bmi_user -d bmidb -f backend/migrations/001_create_measurements.sql
sudo -u postgres psql -U bmi_user -d bmidb -f backend/migrations/002_add_measurement_date.sql
```

#### Step 3: Setup Backend
```bash
cd backend

# Install dependencies
npm install

# Create .env file
cat > .env << EOF
PORT=3000
NODE_ENV=development
DATABASE_URL=postgresql://bmi_user:your_password@localhost:5432/bmidb
CORS_ORIGIN=*
FRONTEND_URL=http://localhost:5173
EOF

# Start backend in development mode
npm run dev
```

Backend should now be running at `http://localhost:3000`

#### Step 4: Setup Frontend
```bash
# Open a new terminal
cd frontend

# Install dependencies
npm install

# Start frontend development server
npm run dev
```

Frontend should now be running at `http://localhost:5173`

#### Step 5: Access the Application
Open your browser and navigate to:
```
http://localhost:5173
```

### Option B: Automated Production Deployment

#### Using the Automated Script
```bash
# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Clone the repository
git clone <your-repo-url>
cd single-server-3tier-webapp-monitoring

# Make scripts executable
chmod +x IMPLEMENTATION_AUTO.sh
chmod +x database/setup-database.sh

# Run automated deployment
sudo ./IMPLEMENTATION_AUTO.sh

# Follow the prompts to enter:
# - Database username (default: bmi_user)
# - Database password
# - Database name (default: bmidb)
```

The script will automatically:
1. Install all prerequisites (Node.js, PostgreSQL, Nginx, PM2)
2. Setup database with user and permissions
3. Run database migrations
4. Install backend dependencies
5. Build frontend for production
6. Configure Nginx reverse proxy
7. Start backend with PM2
8. Configure firewall (UFW)

After completion, access your application at:
```
http://your-ec2-public-ip
```

---

## 🔧 Deployment Options

### Manual Deployment Steps

For a complete manual deployment guide, see [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md).

### Deployment Checklist

- [ ] EC2 instance launched and accessible via SSH
- [ ] Security groups configured (ports 22, 80, 443)
- [ ] PostgreSQL installed and running
- [ ] Database created with correct permissions
- [ ] Migrations executed successfully
- [ ] Backend dependencies installed (`npm install`)
- [ ] Backend .env file configured
- [ ] Frontend built (`npm run build`)
- [ ] Nginx installed and configured
- [ ] PM2 installed globally (`npm install -g pm2`)
- [ ] Backend started with PM2 (`pm2 start`)
- [ ] PM2 configured for auto-restart (`pm2 startup`, `pm2 save`)
- [ ] UFW firewall configured and enabled
- [ ] Application accessible from browser

---

## 📚 Understanding 3-Tier Architecture

### Why 3 Tiers?

Traditional monolithic applications combine all logic in one place. The 3-tier model **separates concerns** into distinct layers:

#### Benefits of Separation

1. **Scalability:** Scale each tier independently
   - High traffic? Add more web servers (Tier 1)
   - Heavy processing? Add more application servers (Tier 2)
   - Large datasets? Upgrade database server (Tier 3)

2. **Maintainability:** Changes are isolated
   - Update UI without touching backend code
   - Modify business logic without database changes
   - Upgrade database without frontend impact

3. **Security:** Defense in depth
   - Database not directly exposed to internet
   - Application layer validates all inputs
   - Web server handles SSL/TLS termination

4. **Team Collaboration:** Different teams work on different tiers
   - Frontend developers work on React (Tier 1)
   - Backend developers work on Express API (Tier 2)
   - DBAs manage PostgreSQL (Tier 3)

### Real-World Example

**E-commerce Website:**
- **Tier 1:** Product catalog, shopping cart UI (React)
- **Tier 2:** Payment processing, inventory management (Node.js API)
- **Tier 3:** Customer data, order history (PostgreSQL)

---

## 🔄 How Components Communicate

### Request Flow: Adding a Measurement

Let's trace a single user action through all three tiers:

```
┌─────────────────────────────────────────────────────────────┐
│ USER ACTION: Clicks "Save Measurement" button               │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: Frontend (React)                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 1. MeasurementForm.jsx collects form data:              │ │
│ │    { weightKg: 70, heightCm: 175, age: 30, ... }        │ │
│ │                                                         │ │
│ │ 2. Sends HTTP POST request via api.js (Axios):          │ │
│ │    POST /api/measurements                               │ │
│ │    Content-Type: application/json                       │ │
│ │    Body: { weightKg: 70, ... }                          │ │
│ └─────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP Request
                        │ (Development: localhost:5173 → localhost:3000)
                        │ (Production: /api/* → Nginx → localhost:3000)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ TIER 2: Backend (Node.js + Express)                         │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 3. server.js receives request:                          │ │
│ │    - CORS middleware checks origin                      │ │
│ │    - body-parser parses JSON                            │ │
│ │                                                         │ │
│ │ 4. routes.js handler executes:                          │ │
│ │    - Validates required fields                          │ │
│ │    - Validates value ranges                             │ │
│ │                                                         │ │
│ │ 5. calculations.js calculates metrics:                  │ │
│ │    - BMI = 70 / (1.75)² = 22.9                          │ │
│ │    - BMR = 1668 (Mifflin-St Jeor)                       │ │
│ │    - Daily Calories = 1668 × 1.55 = 2585                │ │
│ │    - BMI Category = "Normal"                            │ │
│ │                                                         │ │
│ │ 6. db.js prepares SQL query:                            │ │
│ │    INSERT INTO measurements (...)                       │ │
│ │    VALUES ($1, $2, $3, ...)                             │ │
│ └─────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ SQL Query
                        │ (PostgreSQL protocol on port 5432)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ TIER 3: Database (PostgreSQL)                               │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 7. PostgreSQL executes:                                 │ │
│ │    - Validates CHECK constraints                        │ │
│ │    - Inserts row into measurements table                │ │
│ │    - Updates indexes                                    │ │
│ │    - Returns new row with ID                            │ │
│ └─────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ Result Set
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ TIER 2: Backend (Response)                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 8. routes.js formats response:                          │ │
│ │    Status: 201 Created                                  │ │
│ │    Body: { measurement: { id: 1, bmi: 22.9, ... } }     │ │
│ └─────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTP Response
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: Frontend (Update UI)                                │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 9. MeasurementForm.jsx receives response:               │ │
│ │    - Shows success message                              │ │
│ │    - Calls onSaved() callback                           │ │
│ │                                                         │ │
│ │ 10. App.jsx reloads data:                               │ │
│ │     - Fetches updated measurements list                 │ │
│ │     - Updates stats cards                               │ │
│ │     - Refreshes recent measurements                     │ │
│ └─────────────────────────────────────────────────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ USER SEES: Success message & updated dashboard              │
└─────────────────────────────────────────────────────────────┘
```

### Key Communication Patterns

#### Development Mode
- **Frontend** (Vite port 5173) → **Backend** (Express port 3000)
- Vite proxy configuration handles `/api/*` requests
- CORS allows `localhost:5173` origin

#### Production Mode
- **Browser** → **Nginx** (port 80/443)
- Nginx serves static React files
- Nginx proxies `/api/*` to **Backend** (port 3000)
- Backend connects to **PostgreSQL** (port 5432)

---

## 📊 Monitoring Stack Setup

### Overview

This project includes a comprehensive monitoring solution with:
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization dashboards  
- **Loki** - Log aggregation
- **Promtail** - Log shipping
- **AlertManager** - Alert routing and notifications
- **Exporters** - Node, PostgreSQL, Nginx, and custom BMI app metrics

### Quick Setup

#### Option 1: Automated Setup (Recommended)

**Application Server:**
```bash
# Clone repository
cd ~/single-server-3tier-webapp-monitoring

# Run automated deployment script
sudo ./IMPLEMENTATION_AUTO.sh

# This will:
# - Setup database (PostgreSQL)
# - Deploy backend (systemd service)
# - Deploy frontend (Nginx)
# - Install all exporters (node, postgres, nginx, bmi-app)
# - Configure Promtail log shipping
```

**Monitoring Server:**
```bash
cd ~/single-server-3tier-webapp-monitoring

# Run monitoring stack setup
sudo ./monitoring/MONITORING_SERVER_SETUP.sh

# This installs:
# - Prometheus (metrics storage)
# - Grafana (visualization)
# - Loki (log aggregation)
# - AlertManager (alerting)
# - Pre-configured dashboards
```

#### Option 2: Individual Component Setup

Use scripts in `monitoring/scripts/` for granular control:

**Application Server:**
```bash
# Setup exporters and promtail
sudo ./monitoring/scripts/setup-application-exporters.sh
```

**Monitoring Server:**
```bash
# Setup monitoring stack
sudo ./monitoring/scripts/setup-monitoring-server.sh
```

#### Option 3: Enhanced 3-Tier Monitoring

Full production setup with additional features:

**Application Server:**
```bash
sudo ./monitoring/3-tier-app/scripts/setup-application-server.sh
```

**Monitoring Server:**
```bash
sudo ./monitoring/3-tier-app/scripts/setup-monitoring-server.sh
```

### Access Monitoring

After setup, access these URLs (replace `<monitoring-ip>` with your server IP):

- **Grafana**: `http://<monitoring-ip>:3000` (admin/admin)
- **Prometheus**: `http://<monitoring-ip>:9090`
- **AlertManager**: `http://<monitoring-ip>:9093`

### Pre-configured Dashboards

The setup automatically provisions these dashboards in Grafana:

1. **Three-Tier Application Dashboard** - Complete system overview
2. **Loki Logs Dashboard** - Centralized log viewer
3. **System Overview** - Infrastructure metrics
4. **BMI Application Metrics** - Custom app metrics

### Metrics Collected

| Exporter | Port | Metrics |
|----------|------|---------|
| **Node Exporter** | 9100 | CPU, Memory, Disk, Network |
| **PostgreSQL Exporter** | 9187 | DB connections, queries, transactions |
| **Nginx Exporter** | 9113 | HTTP requests, response codes |
| **BMI App Exporter** | 9091 | Custom app metrics, measurement counts |

### Log Collection

Promtail collects logs from:
- **Backend**: `/var/log/bmi-backend.log` (systemd service logs)
- **Nginx Access**: `/var/log/nginx/*access.log`
- **Nginx Error**: `/var/log/nginx/*error.log`
- **PostgreSQL**: `/var/log/postgresql/*.log`
- **System**: `/var/log/syslog`, `/var/log/auth.log`

### Application Health Checks

#### Systemd Service Management
```bash
# Check backend status
sudo systemctl status bmi-backend

# View real-time logs
sudo tail -f /var/log/bmi-backend.log

# Restart backend
sudo systemctl restart bmi-backend

# Stop backend
sudo systemctl stop bmi-backend

# Start backend
sudo systemctl start bmi-backend
```

#### Nginx Status
```bash
# Check Nginx status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration (without downtime)
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# View access logs
sudo tail -f /var/log/nginx/access.log

# View error logs
sudo tail -f /var/log/nginx/error.log
```

#### Database Health
```bash
# Connect to database
sudo -u postgres psql -U bmi_user -d bmidb

# Check table size
\dt+

# View recent measurements
SELECT * FROM measurements ORDER BY created_at DESC LIMIT 5;

# Check database connections
SELECT count(*) FROM pg_stat_activity WHERE datname = 'bmidb';

# Exit psql
\q
```

#### API Health Check
```bash
# Check backend health endpoint
curl http://localhost:3000/health

# Expected response:
# {"status":"ok","environment":"production"}

# Check measurements endpoint
curl http://localhost:3000/api/measurements

# Check from external network (replace with your IP)
curl http://your-ec2-ip/api/health
```

### Log Locations

| Component | Log Location |
|-----------|-------------|
| **Backend (PM2)** | `/home/ubuntu/bmi-health-tracker/backend/logs/` |
| **Nginx Access** | `/var/log/nginx/access.log` |
| **Nginx Error** | `/var/log/nginx/error.log` |
| **PostgreSQL** | `/var/log/postgresql/` |
| **System** | `/var/log/syslog` |

### Backup Procedures

#### Database Backup
```bash
# Create backup
pg_dump -U bmi_user bmidb > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
psql -U bmi_user bmidb < backup_20260101_120000.sql

# Automated daily backup (cron)
echo "0 2 * * * pg_dump -U bmi_user bmidb > /home/ubuntu/backups/bmidb_\$(date +\%Y\%m\%d).sql" | crontab -
```

#### Application Backup
```bash
# Backup entire application
tar -czf bmi-app-backup-$(date +%Y%m%d).tar.gz \
  /home/ubuntu/bmi-health-tracker/ \
  /etc/nginx/sites-available/bmi-health-tracker \
  /var/www/bmi-health-tracker/

# Restore application
tar -xzf bmi-app-backup-20260101.tar.gz -C /
```

---

## 🔍 Troubleshooting

### Common Issues & Solutions

#### Issue 1: Backend Not Starting

**Symptoms:**
- `pm2 status` shows backend as "errored" or "stopped"
- Can't access `http://localhost:3000/health`

**Diagnosis:**
```bash
# Check PM2 logs for errors
pm2 logs bmi-backend --lines 50

# Check if port 3000 is in use
sudo netstat -tulpn | grep 3000

# Test database connection
psql -U bmi_user -d bmidb -c "SELECT 1;"
```

**Solutions:**
- **Database connection error:** Check DATABASE_URL in `.env`
- **Port already in use:** Kill process or change PORT in `.env`
- **Missing dependencies:** Run `npm install` in backend folder
- **Syntax error:** Check PM2 logs for line number

#### Issue 2: Frontend Shows Network Error

**Symptoms:**
- Frontend loads but can't fetch data
- Browser console shows "Network Error" or "Failed to fetch"
- API calls return 404 or CORS errors

**Diagnosis:**
```bash
# Check if backend is running
pm2 status bmi-backend

# Test API directly
curl http://localhost:3000/api/measurements

# Check Nginx proxy configuration
sudo nginx -t
cat /etc/nginx/sites-available/bmi-health-tracker | grep -A 5 "location /api"
```

**Solutions:**
- **Development:** Ensure Vite proxy is configured in `vite.config.js`
- **Production:** Check Nginx reverse proxy configuration
- **CORS error:** Verify CORS_ORIGIN in backend `.env`
- **Wrong URL:** Frontend should use `/api/` not `http://localhost:3000/api/`

#### Issue 3: Database Connection Failed

**Symptoms:**
- Backend logs show "Database connection failed"
- Can't connect with psql command

**Diagnosis:**
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check PostgreSQL port
sudo netstat -tulpn | grep 5432

# Test connection
psql -U bmi_user -d bmidb -h localhost

# Check pg_hba.conf authentication
sudo cat /etc/postgresql/14/main/pg_hba.conf | grep "bmi_user"
```

**Solutions:**
- **PostgreSQL not running:** `sudo systemctl start postgresql`
- **Wrong password:** Reset with `ALTER USER bmi_user WITH PASSWORD 'newpass';`
- **Database doesn't exist:** Create with `CREATE DATABASE bmidb;`
- **Authentication error:** Edit `pg_hba.conf` to use `md5` method

#### Issue 4: Nginx 502 Bad Gateway

**Symptoms:**
- Browser shows "502 Bad Gateway"
- Nginx error log shows "Connection refused"

**Diagnosis:**
```bash
# Check backend is running
pm2 status bmi-backend

# Check Nginx error log
sudo tail -f /var/log/nginx/error.log

# Test backend directly
curl http://127.0.0.1:3000/health
```

**Solutions:**
- **Backend not running:** `pm2 start bmi-backend`
- **Wrong proxy port:** Check Nginx config uses `proxy_pass http://127.0.0.1:3000/`
- **Firewall blocking:** Check UFW allows port 3000 locally

#### Issue 5: Chart Not Showing Data

**Symptoms:**
- Dashboard loads but BMI trend chart is empty
- "No trend data available" message

**Diagnosis:**
```bash
# Check if measurements exist
psql -U bmi_user -d bmidb -c "SELECT COUNT(*) FROM measurements;"

# Test trends API endpoint
curl http://localhost:3000/api/measurements/trends

# Check browser console for errors
```

**Solutions:**
- **No measurements:** Add measurements using the form
- **Old measurements:** Add measurements within last 30 days
- **API error:** Check backend logs with `pm2 logs bmi-backend`
- **Chart.js error:** Check browser console for missing Chart.js components

### Getting Help

1. **Check Logs:** Always start with PM2, Nginx, and PostgreSQL logs
2. **Search Documentation:** Review AGENT.md and IMPLEMENTATION_GUIDE.md
3. **Test Components:** Isolate issues by testing each tier separately
4. **Community Support:** Search GitHub issues or Stack Overflow

---

## 📖 Learning Resources

### For DevOps Engineers

#### 3-Tier Architecture
- [AWS Architecture Patterns](https://aws.amazon.com/architecture/)
- [3-Tier Architecture Guide](https://www.nginx.com/blog/three-tier-architecture/)

#### Node.js & Express
- [Express.js Official Docs](https://expressjs.com/)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)

#### PostgreSQL
- [PostgreSQL Tutorial](https://www.postgresqltutorial.com/)
- [Database Indexing Explained](https://use-the-index-luke.com/)

#### Nginx
- [Nginx Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
- [Reverse Proxy Configuration](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)

#### PM2 Process Management
- [PM2 Official Documentation](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [PM2 Production Best Practices](https://pm2.keymetrics.io/docs/usage/pm2-doc-single-page/)

#### AWS & Cloud Deployment
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Linux Server Administration](https://linuxjourney.com/)

### Understanding the Code

#### Key Files to Study (in order)

1. **Backend Entry Point:** `backend/src/server.js`
   - Understand Express middleware order
   - CORS configuration
   - Error handling

2. **Database Connection:** `backend/src/db.js`
   - Connection pooling
   - Error handling
   - Query execution

3. **API Routes:** `backend/src/routes.js`
   - REST API patterns
   - Input validation
   - Error responses

4. **Business Logic:** `backend/src/calculations.js`
   - Health metric formulas
   - Data transformation

5. **Frontend Entry:** `frontend/src/main.jsx`
   - React initialization

6. **API Client:** `frontend/src/api.js`
   - Axios configuration
   - Request/response interceptors
   - Error handling

7. **Main Component:** `frontend/src/App.jsx`
   - State management
   - Component composition
   - Data flow

### Hands-On Exercises

Try these to deepen your understanding:

1. **Add a New Feature:** Add BMI history comparison (current vs. 30 days ago)
2. **Modify Calculations:** Add BMI Prime calculation (BMI / 25)
3. **Enhance Security:** Add rate limiting to API endpoints
4. **Improve Monitoring:** Add Prometheus metrics endpoint
5. **Database Optimization:** Add composite index on (user_id, measurement_date)
6. **Frontend Enhancement:** Add date range filter for measurements

---

## 📁 Project Structure

```
single-server-3tier-webapp-monitoring/
│
├── README.md                         # Main documentation
├── IMPLEMENTATION_GUIDE.md           # Manual deployment guide
├── IMPLEMENTATION_AUTO.sh            # Automated deployment script
│
├── backend/                          # Tier 2: Application Layer
│   ├── package.json                  # Backend dependencies
│   ├── .env                          # Environment variables
│   │
│   ├── src/
│   │   ├── server.js                 # Express server (systemd service)
│   │   ├── routes.js                 # API route handlers
│   │   ├── db.js                     # PostgreSQL connection pool
│   │   ├── metrics.js                # Custom Prometheus metrics
│   │   └── calculations.js           # Health metrics logic
│   │
│   └── migrations/                   # Database migrations
│       ├── 001_create_measurements.sql
│       └── 002_add_measurement_date.sql
│
├── frontend/                         # Tier 1: Presentation Layer
│   ├── package.json                  # Frontend dependencies
│   ├── vite.config.js                # Vite build configuration
│   ├── index.html                    # HTML entry point
│   │
│   └── src/
│       ├── main.jsx                  # React entry point
│       ├── App.jsx                   # Main application component
│       ├── api.js                    # Axios API client
│       ├── index.css                 # Global styles
│       │
│       └── components/
│           ├── MeasurementForm.jsx   # Add measurement form
│           └── TrendChart.jsx        # BMI trend chart
│
├── database/
│   └── setup-database.sh             # Database initialization
│
├── monitoring/                       # Monitoring Stack
│   │
│   ├── MONITORING_SERVER_SETUP.sh    # Quick monitoring setup
│   ├── Basic_Monitoring_Setup.sh     # Basic exporters setup
│   │
│   ├── scripts/                      # Individual setup scripts
│   │   ├── setup-application-exporters.sh
│   │   └── setup-monitoring-server.sh
│   │
│   ├── 3-tier-app/                   # Enhanced production setup
│   │   ├── scripts/
│   │   │   ├── setup-application-server.sh
│   │   │   └── setup-monitoring-server.sh
│   │   │
│   │   └── dashboards/
│   │       ├── three-tier-application-dashboard.json
│   │       └── loki-logs-dashboard.json
│   │
│   ├── prometheus/
│   │   ├── prometheus.yml            # Prometheus config template
│   │   └── alert_rules.yml           # Alert rules
│   │
│   ├── promtail/
│   │   └── promtail-config.yml       # Log shipping config
│   │
│   ├── loki/
│   │   └── loki-config.yml           # Loki config
│   │
│   ├── alertmanager/
│   │   └── alertmanager.yml          # Alert routing
│   │
│   ├── exporters/
│   │   └── bmi-app-exporter/         # Custom app metrics
│   │       ├── exporter.js
│   │       ├── package.json
│   │       └── ecosystem.config.js
│   │
│   └── grafana/
│       └── dashboards/
│           ├── bmi-application-metrics.json
│           └── system-overview.json
│
├── bmi-application-metrics.json      # Grafana dashboard export
└── system-overview.json              # System metrics dashboard
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `backend/.env` | Database credentials, port configuration |
| `/etc/systemd/system/bmi-backend.service` | Backend service definition |
| `/etc/nginx/sites-available/bmi-health-tracker` | Nginx reverse proxy config |
| `/etc/promtail/promtail-config.yml` | Log collection config |
| `/etc/prometheus/prometheus.yml` | Metrics scraping config |
| `/var/log/bmi-backend.log` | Backend application logs |

---

## 🔌 API Documentation

### Base URL
- **Development:** `http://localhost:3000/api`
- **Production:** `http://your-domain/api`

### Endpoints

#### Health Check
```http
GET /health
```

**Description:** Check if backend is running  
**Authentication:** None  
**Response:**
```json
{
  "status": "ok",
  "environment": "production"
}
```

---

#### Create Measurement
```http
POST /api/measurements
```

**Description:** Add a new health measurement  
**Content-Type:** `application/json`  
**Request Body:**
```json
{
  "weightKg": 70,
  "heightCm": 175,
  "age": 30,
  "sex": "male",
  "activity": "moderate",
  "measurementDate": "2026-01-01"
}
```

**Field Validation:**
- `weightKg`: Required, number, 0-1000
- `heightCm`: Required, number, 0-300
- `age`: Required, integer, 0-150
- `sex`: Required, string, "male" or "female"
- `activity`: Optional, string, one of: "sedentary", "light", "moderate", "active", "very_active"
- `measurementDate`: Optional, date (YYYY-MM-DD), defaults to today

**Response (201 Created):**
```json
{
  "measurement": {
    "id": 1,
    "weight_kg": "70.00",
    "height_cm": "175.00",
    "age": 30,
    "sex": "male",
    "activity_level": "moderate",
    "bmi": "22.9",
    "bmi_category": "Normal",
    "bmr": 1668,
    "daily_calories": 2585,
    "measurement_date": "2026-01-01",
    "created_at": "2026-01-01T12:00:00.000Z"
  }
}
```

**Error Responses:**
- `400 Bad Request`: Missing or invalid fields
- `500 Internal Server Error`: Database or server error

---

#### Get All Measurements
```http
GET /api/measurements
```

**Description:** Retrieve all measurements, ordered by date (newest first)  
**Response (200 OK):**
```json
{
  "rows": [
    {
      "id": 1,
      "weight_kg": "70.00",
      "height_cm": "175.00",
      "age": 30,
      "sex": "male",
      "activity_level": "moderate",
      "bmi": "22.9",
      "bmi_category": "Normal",
      "bmr": 1668,
      "daily_calories": 2585,
      "measurement_date": "2026-01-01",
      "created_at": "2026-01-01T12:00:00.000Z"
    }
  ]
}
```

---

#### Get BMI Trends
```http
GET /api/measurements/trends
```

**Description:** Get 30-day BMI trend data (average BMI per day)  
**Response (200 OK):**
```json
{
  "rows": [
    {
      "day": "2026-01-01",
      "avg_bmi": "22.9"
    },
    {
      "day": "2026-01-02",
      "avg_bmi": "23.1"
    }
  ]
}
```

**Note:** Only includes data from the last 30 days

---

## 🤝 Contributing

This project is designed for learning. To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

### Suggested Improvements

- Add user authentication (JWT or session-based)
- Implement user accounts (multi-user support)
- Add data export (CSV/PDF)
- Add weight/height unit conversion (kg/lb, cm/inches)
- Implement measurement editing/deletion
- Add BMI percentile charts
- Add Docker/Docker Compose support
- Add CI/CD pipeline (GitHub Actions)

---

## 📄 License

This project is intended for educational purposes.

---

## 💬 Support & Questions

**For Junior DevOps Engineers:**
- Review the [Understanding 3-Tier Architecture](#-understanding-3-tier-architecture) section
- Work through the [Quick Start Guide](#-quick-start-guide)
- Check [Troubleshooting](#-troubleshooting) for common issues
- Study the [Project Structure](#-project-structure) to understand file organization

**For Complete Project Recreation:**
- See [AGENT.md](AGENT.md) for full source code and step-by-step instructions

**For Manual Deployment:**
- See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for detailed manual deployment steps

---

## 🎓 Next Steps

After successfully deploying this application, consider:

1. **SSL/HTTPS Setup:** Add Let's Encrypt certificate for production
2. **Domain Configuration:** Point a domain name to your EC2 instance
3. **Monitoring:** Add Prometheus + Grafana for metrics
4. **Logging:** Centralize logs with ELK stack
5. **CI/CD:** Automate deployment with GitHub Actions
6. **Containerization:** Convert to Docker containers
7. **Kubernetes:** Deploy on K8s cluster for high availability
8. **Cloud Native:** Use AWS RDS, ECS, ALB for managed services

---

## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, WPP Production - Dhaka  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/

---
