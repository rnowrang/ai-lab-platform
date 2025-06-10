# AI Lab Platform Restart Guide

This guide provides step-by-step instructions for restarting the AI Lab Platform after server reboots, maintenance, or issues.

## 🚀 Quick Reference

**Most common restart command:**
```bash
cd /home/llurad/ai-lab-platform
sudo docker compose -f docker-compose.production.yml up -d
```

**Check status:**
```bash
sudo docker compose -f docker-compose.production.yml ps
```

---

## 📋 Pre-Restart Checklist

Before restarting, verify these prerequisites:

- [ ] You have `sudo` access
- [ ] You're in the `/home/llurad/ai-lab-platform` directory
- [ ] The `production.env` file exists and contains your configuration
- [ ] SSL certificates are in the `ssl/` directory

---

## 🔄 Restart Scenarios

### Scenario 1: After Server Reboot (Automatic)

**What happens:**
- All services have `restart: unless-stopped` policy
- Services should automatically restart within 2-3 minutes
- Docker volumes and data persist

**Verification:**
```bash
cd /home/llurad/ai-lab-platform
sudo docker compose -f docker-compose.production.yml ps
```

**Expected output:** All services should show "Up" status

### Scenario 2: Manual Restart (Recommended)

**When to use:** After server reboot, maintenance, or updates

**Steps:**
```bash
# 1. Navigate to project directory
cd /home/llurad/ai-lab-platform

# 2. Stop all services (optional, for clean restart)
sudo docker compose -f docker-compose.production.yml down

# 3. Start all services
sudo docker compose -f docker-compose.production.yml up -d

# 4. Check status
sudo docker compose -f docker-compose.production.yml ps
```

### Scenario 3: Individual Service Restart

**When to use:** When only specific services need restarting

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

**All core services:**
```bash
sudo docker compose -f docker-compose.production.yml restart backend mlflow postgres nginx grafana
```

### Scenario 4: Full Redeployment

**When to use:** Major issues, configuration changes, or updates

**Steps:**
```bash
cd /home/llurad/ai-lab-platform
sudo ./deploy_production_ip.sh
```

**Note:** This will rebuild images and recreate containers while preserving data.

---

## 🔍 Verification Steps

After restarting, verify all components are working:

### 1. Check Container Status
```bash
sudo docker compose -f docker-compose.production.yml ps
```

**Expected:** All services showing "Up" status

### 2. Check Service Health
```bash
# Backend health check
curl -f http://localhost:5555/health || echo "Backend not ready"

# MLflow health check
curl -f http://localhost:5000/health || echo "MLflow not ready"

# PostgreSQL check
sudo docker exec ai-lab-postgres pg_isready -U postgres || echo "Database not ready"
```

### 3. Web Interface Tests

**Main Platform:**
- Visit: `https://YOUR_IP`
- Should show AI Lab Platform homepage
- Accept SSL certificate warning (for self-signed certs)

**Admin Portal:**
- Visit: `https://YOUR_IP/admin`
- Should prompt for username/password
- Check `credentials.txt` for admin credentials

**Grafana Monitoring:**
- Visit: `https://YOUR_IP/grafana`
- Should load without authentication (anonymous access enabled)
- Or login with admin credentials from `credentials.txt`

**MLflow Tracking:**
- MLflow UI accessible through backend API
- Check MLflow experiments are visible

### 4. Test User Environment Creation

**Create test environment:**
```bash
curl -X POST http://localhost:5555/api/environments \
  -H "Content-Type: application/json" \
  -d '{"user_email": "test@example.com", "environment_type": "pytorch", "gpu_count": 1}'
```

**Expected:** JSON response with environment details

---

## 🚨 Troubleshooting

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

### Problem: Disk Space Issues

**Check disk usage:**
```bash
df -h
sudo docker system df
```

**Clean up Docker (careful!):**
```bash
# Remove unused containers and images
sudo docker system prune -f

# Remove unused volumes (BE CAREFUL - this removes data!)
# sudo docker volume prune -f  # DON'T run this unless you're sure
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

**Docker Compose handles these dependencies automatically.**

---

## 🔐 Important Files and Locations

### Critical Files (DO NOT DELETE):
- `production.env` - Environment configuration
- `credentials.txt` - Login credentials
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
# Service logs
sudo docker compose -f docker-compose.production.yml logs [service]

# System backup logs
sudo tail -f /var/log/ai-lab-backup.log
```

---

## ⚡ Emergency Recovery

If everything fails, use this nuclear option:

### Complete Reset (Preserves Data):
```bash
cd /home/llurad/ai-lab-platform

# Stop everything
sudo docker compose -f docker-compose.production.yml down

# Clean up containers (not volumes)
sudo docker container prune -f
sudo docker image prune -f

# Full redeployment
sudo ./deploy_production_ip.sh
```

### Data Recovery:
```bash
# Check backups
ls -la /opt/backups/

# Restore from latest backup (if needed)
# Follow backup restoration procedures in deployment docs
```

---

## 📞 Quick Support Commands

**Get all service status:**
```bash
sudo docker compose -f docker-compose.production.yml ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
```

**View recent logs for all services:**
```bash
sudo docker compose -f docker-compose.production.yml logs --tail=20 --timestamps
```

**Resource usage:**
```bash
sudo docker stats --no-stream
```

**Network connectivity:**
```bash
sudo docker network ls
sudo docker network inspect ai-lab-platform_ai-lab-network
```

---

## 🎯 Success Indicators

**Everything is working when:**
- [ ] All containers show "Up" status
- [ ] Main platform loads at `https://YOUR_IP`
- [ ] Grafana loads at `https://YOUR_IP/grafana`
- [ ] Admin portal requires authentication
- [ ] Users can create Jupyter environments
- [ ] MLflow experiments are accessible
- [ ] GPU monitoring shows metrics

---

## 📝 Notes

- **Startup time:** Allow 2-3 minutes for all services to fully initialize
- **SSL warnings:** Self-signed certificates will show browser warnings (normal)
- **Automatic backups:** Run daily at 2 AM, stored in `/opt/backups/`
- **Log retention:** Docker logs are retained for 30 days by default
- **Updates:** Always backup before applying updates

---

**For additional help, check:**
- `PRODUCTION_DEPLOYMENT.md` - Full deployment guide
- `DEPLOYMENT_CHECKLIST.md` - Pre-deployment checklist
- Container logs for specific error messages 