# AI Lab Platform Restart Guide

This guide provides step-by-step instructions for restarting the AI Lab Platform after server reboots, maintenance, or issues.

## 🚀 Quick Reference

### **Automatic Restart (Recommended)**
```bash
# Full automation with all fixes and health checks
sudo ./post-reboot-automation.sh
```

### **Manual Docker Restart (Fast)**
```bash
# Quick restart of services only
cd /home/llurad/ai-lab-platform
sudo docker compose -f docker-compose.production.yml restart
```

### **Check Status**
```bash
sudo docker compose -f docker-compose.production.yml ps
curl -k https://localhost/api/health
```

---

## 🤖 **NEW: Post-Reboot Automation System**

**Your AI Lab Platform now includes full automation that handles all post-reboot issues automatically!**

### **Automatic Startup on Boot**
- **Service**: `ai-lab-startup.service` (systemd)
- **Status**: `systemctl is-enabled ai-lab-startup.service` → `enabled`
- **What it does**: Automatically runs after every reboot
- **Time**: 2-4 minutes for complete startup with verification

### **Manual Automation Execution**
```bash
# Run the full automation sequence manually
sudo ./post-reboot-automation.sh

# Test automation via systemd
sudo systemctl start ai-lab-startup.service

# Monitor automation progress
sudo journalctl -u ai-lab-startup.service -f
```

### **Automation Features**
✅ **Docker client fixes** - Ensures backend can create environments  
✅ **Port conflict resolution** - Removes orphaned containers  
✅ **Permission fixing** - Sets correct data directory permissions  
✅ **Data consistency** - Verifies unified data structure  
✅ **Health checks** - Tests all services after startup  
✅ **Monitoring setup** - Installs continuous health monitoring  

### **Automation Control**
```bash
# Check automation status
sudo systemctl status ai-lab-startup.service

# View automation logs
sudo journalctl -u ai-lab-startup.service --no-pager

# Disable automation (if needed)
sudo systemctl disable ai-lab-startup.service

# Re-enable automation
sudo systemctl enable ai-lab-startup.service
```

---

## 📋 Pre-Restart Checklist

Before restarting, verify these prerequisites:

- [ ] You have `sudo` access
- [ ] You're in the `/home/llurad/ai-lab-platform` directory
- [ ] The `production.env` file exists and contains your configuration
- [ ] SSL certificates are in the `ssl/` directory
- [ ] (Optional) Automation system is enabled: `systemctl is-enabled ai-lab-startup.service`

---

## 🔄 Restart Scenarios

### Scenario 1: After Server Reboot (Fully Automatic - NEW!)

**What happens automatically:**
1. System boots up
2. Docker daemon starts
3. **AI Lab automation runs automatically** (`ai-lab-startup.service`)
4. All post-reboot issues are fixed automatically
5. All services start with health checks
6. Platform ready for use

**Verification:**
```bash
# Check automation ran successfully
sudo systemctl status ai-lab-startup.service

# Verify all services are healthy
curl -k https://localhost/api/health
sudo docker compose -f docker-compose.production.yml ps
```

**Expected:** All services "Up" and healthy, automation service shows "active (exited)" with exit code 0

### Scenario 2: Manual Full Restart with Automation (Recommended)

**When to use:** 
- After configuration changes
- When troubleshooting issues  
- After system updates
- When you want all automation benefits

**Command:**
```bash
cd /home/llurad/ai-lab-platform
sudo ./post-reboot-automation.sh
```

**What it does:**
1. Waits for Docker daemon
2. Cleans up orphaned containers
3. Fixes data directory permissions  
4. Starts all services with dependency management
5. Performs health checks on each service
6. Verifies data consistency
7. Tests system functionality
8. Sets up continuous monitoring

**Time:** 2-4 minutes

### Scenario 3: Manual Docker Services Restart (Fast)

**When to use:**
- Quick restart needed
- No configuration changes
- Services are healthy, just need refresh
- After minor code updates

**Steps:**
```bash
# Option A: Restart all services
cd /home/llurad/ai-lab-platform
sudo docker compose -f docker-compose.production.yml restart

# Option B: Stop and start (cleaner)
sudo docker compose -f docker-compose.production.yml down
sudo docker compose -f docker-compose.production.yml up -d

# Verify
sudo docker compose -f docker-compose.production.yml ps
curl -k https://localhost/api/health
```

**Time:** 30-60 seconds

### Scenario 4: Individual Service Restart (Targeted)

**When to use:**
- Only specific service has issues
- Testing service-specific changes
- Minimal disruption needed

**Backend only:**
```bash
sudo docker compose -f docker-compose.production.yml restart backend
```

**MLflow only:**
```bash
sudo docker compose -f docker-compose.production.yml restart mlflow
```

**Database only:**
```bash
sudo docker compose -f docker-compose.production.yml restart postgres
```

**Multiple specific services:**
```bash
sudo docker compose -f docker-compose.production.yml restart backend nginx mlflow
```

**Time:** 10-20 seconds per service

### Scenario 5: Test Automation System

**When to use:**
- Testing automation functionality
- Verifying automation works
- Troubleshooting automation issues

**Command:**
```bash
# Run automation via systemd service
sudo systemctl start ai-lab-startup.service

# Monitor in real-time
sudo journalctl -u ai-lab-startup.service -f

# Check final status
sudo systemctl status ai-lab-startup.service
```

### Scenario 6: Emergency Full Reset

**When to use:**
- Major issues that other methods can't fix
- Corrupt container states
- Need complete clean slate

**Steps:**
```bash
cd /home/llurad/ai-lab-platform

# Nuclear option - removes all containers and networks
sudo docker compose -f docker-compose.production.yml down --remove-orphans
sudo docker system prune -f

# Full restart with automation
sudo ./post-reboot-automation.sh
```

**Time:** 3-5 minutes

---

## 🎯 **When to Use Which Restart Method**

| **Scenario** | **Method** | **Time** | **Benefits** | **Use When** |
|--------------|------------|----------|--------------|--------------|
| **Full automation** | `./post-reboot-automation.sh` | 2-4 min | All fixes & checks | Config changes, troubleshooting, after updates |
| **Docker restart** | `docker compose restart` | 30-60 sec | Quick & simple | Minor updates, quick refresh |
| **Individual service** | `docker compose restart [service]` | 10-20 sec | Targeted fix | Single service issue |
| **Test automation** | `systemctl start ai-lab-startup.service` | 2-4 min | Test automation | Verify automation works |
| **Emergency reset** | `down --remove-orphans` + automation | 3-5 min | Complete rebuild | Nuclear option |

---

## 🔍 Verification Steps

After restarting, verify all components are working:

### 1. Check Container Status
```bash
sudo docker compose -f docker-compose.production.yml ps
```
**Expected:** All services showing "Up" status

### 2. Check Service Health (Enhanced)
```bash
# API health check (most comprehensive)
curl -k https://localhost/api/health
# Expected: {"status":"healthy","timestamp":"..."}

# Individual service checks
curl -f http://localhost:5555/health || echo "Backend not ready"
curl -f http://localhost:5000/health || echo "MLflow not ready"
sudo docker exec ai-lab-postgres pg_isready -U postgres || echo "Database not ready"
```

### 3. Check Automation System
```bash
# Verify automation is enabled and working
sudo systemctl status ai-lab-startup.service
sudo systemctl is-enabled ai-lab-startup.service

# Check automation logs
sudo tail -20 /var/log/ai-lab-post-reboot.log

# Check continuous monitoring
sudo tail -10 /var/log/ai-lab-health-monitor.log
```

### 4. Web Interface Tests

**Main Platform:**
- Visit: `https://localhost` or `https://YOUR_IP`
- Should show AI Lab Platform homepage
- Accept SSL certificate warning (for self-signed certs)

**Admin Portal:**
- Visit: `https://localhost/admin`
- Should prompt for username/password
- Check `credentials.txt` for admin credentials

**MLflow Integration:**
- MLflow accessible through: `https://localhost/mlflow/`
- Should show MLflow UI integrated with platform

**Grafana Monitoring:**
- Visit: `https://localhost/grafana/`
- Should load Grafana dashboard

### 5. Test Environment Creation
```bash
# Test environment creation via API
curl -k -X POST https://localhost/api/environments/create \
  -H "Content-Type: application/json" \
  -d '{"env_type": "pytorch-jupyter", "user_id": "test@example.com"}'
```
**Expected:** JSON response with environment details

### 6. Data Consistency Verification
```bash
# Check data directory permissions
ls -la ai-lab-data/

# Verify shared data is accessible
ls -la ai-lab-data/shared/

# Check HOST_DATA_PATH configuration
grep HOST_DATA_PATH production.env
# Expected: HOST_DATA_PATH=/home/llurad/ai-lab-platform/ai-lab-data
```

---

## 🚨 Troubleshooting

### Problem: Automation Failed to Start

**Check automation service:**
```bash
sudo systemctl status ai-lab-startup.service
sudo journalctl -u ai-lab-startup.service --no-pager -l
```

**Manual execution for debugging:**
```bash
sudo ./post-reboot-automation.sh
```

**Common fixes:**
- Ensure Docker is running: `sudo systemctl start docker`
- Check disk space: `df -h`
- Verify permissions: `ls -la post-reboot-automation.sh`

### Problem: Services Won't Start

**Check Docker daemon:**
```bash
sudo systemctl status docker
sudo systemctl start docker  # if stopped
```

**Check for port conflicts:**
```bash
sudo netstat -tulpn | grep -E ":(80|443|5555|5000|5432|3000|9090)"
```

**View service logs:**
```bash
sudo docker compose -f docker-compose.production.yml logs [service_name]
```

**Use automation to fix:**
```bash
sudo ./post-reboot-automation.sh  # Handles most common issues
```

### Problem: Database Connection Issues

**Check PostgreSQL:**
```bash
sudo docker compose -f docker-compose.production.yml logs postgres
sudo docker exec ai-lab-postgres pg_isready -U postgres
```

**Reset database connection:**
```bash
sudo docker compose -f docker-compose.production.yml restart postgres
sleep 10
sudo docker compose -f docker-compose.production.yml restart backend mlflow
```

### Problem: Permission Issues (Auto-Fixed by Automation)

**Check current permissions:**
```bash
ls -la ai-lab-data/
```

**Manual fix (or use automation):**
```bash
sudo chown -R llurad:docker ai-lab-data/
sudo find ai-lab-data/ -type d -exec chmod 775 {} \;
```

**Automated fix:**
```bash
sudo ./post-reboot-automation.sh  # Includes permission fixing
```

### Problem: Data Volume Consistency Issues

**Check configuration:**
```bash
grep HOST_DATA_PATH production.env
# Should show: HOST_DATA_PATH=/home/llurad/ai-lab-platform/ai-lab-data
```

**Verify backend can access data:**
```bash
docker exec ai-lab-backend ls -la /app/ai-lab-data/
```

**Auto-fix with automation:**
```bash
sudo ./post-reboot-automation.sh  # Verifies and reports data consistency
```

### Problem: SSL Certificate Issues

**Check certificate files:**
```bash
ls -la ssl/
# Should see: fullchain.pem and privkey.pem
```

**Regenerate self-signed certificate:**
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/privkey.pem \
    -out ssl/fullchain.pem \
    -subj "/C=US/ST=State/L=City/O=Institution/CN=YOUR_IP" \
    -addext "subjectAltName = IP:YOUR_IP"
```

### Problem: GPU Access Issues

**Check NVIDIA drivers:**
```bash
nvidia-smi
```

**Check NVIDIA Docker runtime:**
```bash
sudo docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

**Restart GPU monitoring:**
```bash
sudo docker compose -f docker-compose.production.yml restart nvidia-dcgm-exporter
```

### Problem: Orphaned Containers (Auto-Fixed by Automation)

**Manual cleanup:**
```bash
# Remove orphaned AI Lab containers
sudo docker ps -a --filter "name=ai-lab-" | grep -E "(pytorch|tensorflow|jupyter|vscode)" | awk '{print $1}' | xargs -r sudo docker rm -f
```

**Automated cleanup:**
```bash
sudo ./post-reboot-automation.sh  # Includes smart container cleanup
```

---

## 📊 Service Dependencies

Understanding service startup order:

1. **PostgreSQL** - Database (must start first)
2. **Redis** - Session storage  
3. **MLflow** - Depends on PostgreSQL
4. **Backend** - Depends on PostgreSQL and MLflow
5. **Nginx** - Depends on Backend, MLflow, Grafana
6. **Grafana** - Depends on Prometheus
7. **Prometheus** - Independent
8. **TorchServe** - Depends on MLflow
9. **GPU Monitor** - Independent

**The automation system handles these dependencies automatically with health checks.**

---

## 🔐 Important Files and Locations

### Critical Files (DO NOT DELETE):
- `production.env` - Environment configuration
- `post-reboot-automation.sh` - Automation script
- `ai-lab-startup.service` - Systemd service (in `/etc/systemd/system/`)
- `ssl/fullchain.pem` - SSL certificate
- `ssl/privkey.pem` - SSL private key
- `ai-lab-data/` - User data directory

### Persistent Volumes:
- `ai-lab-platform_postgres_data` - Database
- `ai-lab-platform_mlflow_artifacts` - MLflow experiments
- `ai-lab-platform_grafana_data` - Grafana settings
- `ai-lab-platform_prometheus_data` - Monitoring data
- `ai-lab-platform_redis_data` - Session data

### Log Locations:
```bash
# Automation logs
sudo tail -f /var/log/ai-lab-post-reboot.log
sudo tail -f /var/log/ai-lab-health-monitor.log

# Service logs
sudo docker compose -f docker-compose.production.yml logs [service]
sudo journalctl -u ai-lab-startup.service

# System backup logs
sudo tail -f /var/log/ai-lab-backup.log
```

---

## ⚡ Emergency Recovery

### Option 1: Use Automation (Recommended)
```bash
cd /home/llurad/ai-lab-platform
sudo ./post-reboot-automation.sh
```

### Option 2: Complete Reset (Nuclear Option)
```bash
cd /home/llurad/ai-lab-platform

# Stop everything
sudo docker compose -f docker-compose.production.yml down --remove-orphans

# Clean up containers (not volumes)
sudo docker container prune -f
sudo docker image prune -f

# Use automation for recovery
sudo ./post-reboot-automation.sh
```

### Option 3: Full Redeployment
```bash
cd /home/llurad/ai-lab-platform
sudo ./deploy_production_ip.sh
```

---

## 📞 Quick Support Commands

**Get all service status:**
```bash
sudo docker compose -f docker-compose.production.yml ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
```

**Check automation status:**
```bash
sudo systemctl status ai-lab-startup.service
systemctl is-enabled ai-lab-startup.service
```

**View recent logs:**
```bash
sudo docker compose -f docker-compose.production.yml logs --tail=20 --timestamps
sudo journalctl -u ai-lab-startup.service --no-pager
```

**Complete health check:**
```bash
curl -k https://localhost/api/health
sudo docker stats --no-stream
```

**Resource usage:**
```bash
sudo docker stats --no-stream
df -h
free -h
nvidia-smi
```

---

## 🎯 Success Indicators

**Everything is working when:**
- [ ] All containers show "Up" status
- [ ] `curl -k https://localhost/api/health` returns `{"status":"healthy"}`
- [ ] Main platform loads at `https://localhost`
- [ ] Admin portal requires authentication at `https://localhost/admin`
- [ ] Automation service is enabled: `systemctl is-enabled ai-lab-startup.service`
- [ ] Health monitoring is active: `sudo tail /var/log/ai-lab-health-monitor.log`
- [ ] Users can create environments successfully
- [ ] Data directories have correct permissions (`llurad:docker`, `775`)

---

## 📝 Notes

- **Automatic startup:** The platform now starts automatically after every reboot (2-4 minutes)
- **Manual control:** You can still restart manually anytime using the methods above
- **Startup time:** Allow 2-4 minutes for full automation, 30-60 seconds for Docker restart
- **SSL warnings:** Self-signed certificates will show browser warnings (normal)
- **Monitoring:** Continuous health checks run every 5 minutes
- **Log retention:** Docker logs retained for 30 days, automation logs grow ~1MB/day
- **Updates:** Always use automation after major updates for best results

---

## 🔗 Related Documentation

- **`POST_REBOOT_AUTOMATION.md`** - Complete automation system documentation
- **`REBOOT_PROTECTION_COMPLETE.md`** - Summary of all protection measures  
- **`DATA_VOLUME_CONSISTENCY_GUIDE.md`** - Data architecture explanation
- **`RESTART_QUICK_REFERENCE.md`** - Quick command reference
- **`PRODUCTION_DEPLOYMENT.md`** - Full deployment guide
- **`DEPLOYMENT_CHECKLIST.md`** - Pre-deployment checklist

---

**🚀 Your AI Lab Platform now handles reboots automatically! Use manual restart methods when needed, but enjoy the peace of mind that comes with full automation.** 
- Container logs for specific error messages 
- Container logs for specific error messages 
- Container logs for specific error messages 
- Container logs for specific error messages 
- Container logs for specific error messages 