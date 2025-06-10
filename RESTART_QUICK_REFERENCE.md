# AI Lab Platform - Quick Restart Reference

## 🚀 Most Common Commands

### Basic Restart
```bash
cd /home/llurad/ai-lab-platform
sudo docker compose -f docker-compose.production.yml up -d
```

### Check Status
```bash
sudo docker compose -f docker-compose.production.yml ps
```

### View Logs
```bash
sudo docker compose -f docker-compose.production.yml logs [service_name]
```

---

## 🔄 Common Restart Scenarios

| Scenario | Command |
|----------|---------|
| **After reboot** | `sudo docker compose -f docker-compose.production.yml up -d` |
| **Clean restart** | `sudo docker compose -f docker-compose.production.yml down && sudo docker compose -f docker-compose.production.yml up -d` |
| **Restart backend** | `sudo docker compose -f docker-compose.production.yml restart backend` |
| **Restart database** | `sudo docker compose -f docker-compose.production.yml restart postgres` |
| **Full redeployment** | `sudo ./deploy_production_ip.sh` |

---

## 🔍 Quick Health Checks

```bash
# All services status
sudo docker compose -f docker-compose.production.yml ps

# Service health
curl -f http://localhost:5555/health  # Backend
curl -f http://localhost:5000/health  # MLflow
sudo docker exec ai-lab-postgres pg_isready -U postgres  # Database
```

---

## 🌐 Access URLs

- **Main Platform**: `https://YOUR_IP`
- **Admin Portal**: `https://YOUR_IP/admin`
- **Grafana**: `https://YOUR_IP/grafana`
- **Credentials**: Check `credentials.txt` file

---

## 🚨 Emergency Commands

```bash
# Stop everything
sudo docker compose -f docker-compose.production.yml down

# Start everything
sudo docker compose -f docker-compose.production.yml up -d

# Nuclear option (preserves data)
sudo docker compose -f docker-compose.production.yml down
sudo docker container prune -f
sudo ./deploy_production_ip.sh
```

---

## 📊 Quick Diagnostics

```bash
# Resource usage
sudo docker stats --no-stream

# Disk space
df -h
sudo docker system df

# Recent logs
sudo docker compose -f docker-compose.production.yml logs --tail=10 --timestamps

# Port conflicts
sudo netstat -tulpn | grep -E ":(80|443|5555|5000|5432)"
```

---

**⏱️ Typical startup time: 2-3 minutes**

**📄 Full guide: See `RESTART_GUIDE.md`** 