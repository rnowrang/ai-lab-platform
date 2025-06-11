# 🚀 AI Lab Platform - Startup Visualization Guide

This guide explains how to use the startup visualization tools to monitor your AI Lab Platform startup process and service health.

## 📋 Overview

I've created a comprehensive startup visualization system with multiple interfaces:

1. **Terminal-based Real-time Monitor** (`startup-monitor.sh`)
2. **Web-based Dashboard** (`status-dashboard.html`)
3. **Command-line Status API** (`get-service-status.py`)

## 🖥️ Terminal Monitor (`startup-monitor.sh`)

### Features
- **Real-time service monitoring** with colorful progress bars
- **Service health status** with visual indicators (✅ ❌ ⏳)
- **Connectivity testing** for all critical endpoints
- **Live log streaming** from the startup process
- **Progress tracking** showing overall platform readiness

### Usage Options

#### 1. Real-time Monitoring (Default)
```bash
./startup-monitor.sh
# or
./startup-monitor.sh --monitor
```
**What it does:**
- Continuously monitors all services in real-time
- Updates every 3 seconds with current status
- Shows progress bar indicating overall health
- Displays recent activity logs
- Auto-exits when all services are healthy

#### 2. Quick Status Check
```bash
./startup-monitor.sh --status
```
**What it does:**
- Instant snapshot of all service statuses
- Connectivity tests for key endpoints
- Perfect for quick health checks

#### 3. Full Startup Sequence Visualization
```bash
./startup-monitor.sh --full
```
**What it does:**
- Shows the complete startup sequence with timed phases
- Visualizes each startup phase with progress bars
- Transitions to real-time monitoring after sequence
- Great for watching a full platform restart

#### 4. Help
```bash
./startup-monitor.sh --help
```

### Visual Indicators

| Symbol | Meaning | Status |
|--------|---------|---------|
| ✅ | Green checkmark | Service healthy/ready |
| ❌ | Red X | Service failed/unhealthy |
| ⏳ | Yellow clock | Service starting up |
| ℹ️ | Blue info | Service running (status unknown) |

### Example Output
```
════════════════════════════════════════════════════════════════════
                  🚀 AI Lab Platform Startup Monitor
════════════════════════════════════════════════════════════════════

⚙️ Service Status Overview
────────────────────────────────────────────
✅ postgres        Healthy (Ready for connections)
✅ redis           Healthy (Responding to ping)
✅ backend         Healthy (API responding)
✅ mlflow          Healthy (Tracking server ready)
✅ nginx           Healthy (Web interface ready)
✅ grafana         Running (Up 2 minutes)
✅ prometheus      Running (Up 2 minutes)
✅ torchserve      Running (Up 1 minute)
────────────────────────────────────────────
📊 Overall Progress: [████████████████████████████████████████] 100% (8/8 services ready)

ℹ️ Recent Activity
────────────────────────────────────────────
[INFO] All services health check completed
[INFO] Platform status updated
[INFO] Web interface accessible
[INFO] API endpoints responding normally

✅ All services are healthy! Platform is ready.
🌐 Access the platform at: https://localhost/
```

## 🌐 Web Dashboard (`status-dashboard.html`)

### Features
- **Modern responsive web interface** with glassmorphism design
- **Real-time auto-refresh** every 5 seconds
- **Service categorization** (Core vs Application services)
- **Visual progress bars** and status indicators
- **Connectivity test results**
- **Live activity logs**
- **Mobile-friendly responsive design**

### How to Access

#### Option 1: Serve via nginx (Recommended)
Copy the dashboard to nginx directory:
```bash
cp status-dashboard.html /usr/share/nginx/html/status.html
```
Then access at: `https://localhost/status.html`

#### Option 2: Simple HTTP Server
```bash
python3 -m http.server 8080
```
Then access at: `http://localhost:8080/status-dashboard.html`

#### Option 3: Direct File Access
Open the file directly in your browser:
```bash
firefox status-dashboard.html
# or
chrome status-dashboard.html
```

### Dashboard Sections

1. **Core Services** - Database, Redis, Monitoring
2. **Application Services** - Backend, MLflow, TorchServe, Web Server
3. **Overall Progress** - Visual progress bar with completion percentage
4. **Connectivity Tests** - Real-time endpoint testing
5. **Recent Activity** - Live log feed

### Visual Elements
- **Pulsing dots** indicate service activity
- **Color coding**: Green (healthy), Yellow (starting), Red (failed), Gray (stopped)
- **Progress bar** changes color based on overall health
- **Auto-refresh indicator** shows last update time

## 🔧 Status API (`get-service-status.py`)

### Features
- **Detailed JSON status reports** for individual services
- **Comprehensive health checks** (Docker + connectivity)
- **Batch status checking** for all services
- **Scriptable interface** for automation

### Usage

#### Check Individual Service
```bash
python3 get-service-status.py backend
python3 get-service-status.py postgres
python3 get-service-status.py nginx
```

#### Check All Services
```bash
python3 get-service-status.py all
```

#### Example Output
```json
{
  "service": "backend",
  "status": "healthy",
  "details": "API responding",
  "docker_status": "healthy",
  "connectivity": true,
  "timestamp": "2025-06-10T21:14:15.686308"
}
```

#### Comprehensive Report (all services)
```json
{
  "overall": {
    "timestamp": "2025-06-10T21:15:30.123456",
    "total_services": 8,
    "healthy_services": 8,
    "health_percentage": 100.0,
    "overall_status": "healthy"
  },
  "services": {
    "postgres": { "status": "healthy", ... },
    "redis": { "status": "healthy", ... },
    ...
  }
}
```

## 🎯 Use Cases

### During Startup
```bash
# Watch the complete startup sequence
./startup-monitor.sh --full
```

### Troubleshooting
```bash
# Quick status check
./startup-monitor.sh --status

# Detailed service analysis
python3 get-service-status.py all | jq '.'
```

### Continuous Monitoring
```bash
# Real-time monitoring
./startup-monitor.sh

# Or use the web dashboard for remote monitoring
```

### Automation/Scripting
```bash
# Check if platform is ready
if python3 get-service-status.py all | jq -r '.overall.overall_status' | grep -q "healthy"; then
    echo "Platform is ready!"
else
    echo "Platform not ready yet"
fi
```

## 🔍 Integration with Existing Tools

### With Post-Reboot Automation
The monitoring tools work seamlessly with the existing post-reboot automation:

```bash
# Run automation and monitor progress simultaneously
sudo systemctl restart ai-lab-startup.service &
./startup-monitor.sh --full
```

### With Health Monitoring
The tools complement the existing cron-based health monitoring:

```bash
# Manual health check
./startup-monitor.sh --status

# View health monitor logs
tail -f /var/log/ai-lab-health-monitor.log
```

### With Docker Compose
```bash
# Start services and monitor
docker compose -f docker-compose.production.yml --env-file production.env up -d &
./startup-monitor.sh
```

## 🚨 Troubleshooting

### Monitor Shows Services as "Unknown"
- Check if Docker containers are running: `docker ps`
- Verify container names match expected format: `ai-lab-*`

### Web Dashboard Not Updating
- Check browser console for JavaScript errors
- Verify you have network access to the endpoints
- Try refreshing the page manually

### Connectivity Tests Failing
- Ensure services are actually accessible
- Check firewall settings
- Verify SSL certificates (use `-k` flag for curl if needed)

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x startup-monitor.sh get-service-status.py

# Install required Python packages if needed
pip install requests
```

## 📊 Understanding Status Indicators

### Service Status Types
- **healthy**: Service is running and responding correctly
- **running**: Service is up but connectivity unknown
- **starting**: Service is in startup phase
- **unhealthy**: Service is running but not responding
- **stopped**: Service is not running
- **failed**: Service failed to start

### Overall Platform Status
- **healthy**: All services operational
- **degraded**: Some services down but platform functional
- **down**: Critical services unavailable

## 🎉 Quick Start

1. **For immediate status check:**
   ```bash
   ./startup-monitor.sh --status
   ```

2. **For startup monitoring:**
   ```bash
   ./startup-monitor.sh
   ```

3. **For web-based monitoring:**
   - Open `status-dashboard.html` in browser
   - Or serve via nginx: `cp status-dashboard.html /usr/share/nginx/html/status.html`

4. **For automation:**
   ```bash
   python3 get-service-status.py all
   ```

These tools give you complete visibility into your AI Lab Platform startup process and ongoing health! 🚀 