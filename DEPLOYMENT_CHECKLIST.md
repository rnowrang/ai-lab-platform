# AI Lab Platform - Production Deployment Checklist

## Pre-Deployment Checklist

### Server Requirements
- [ ] Ubuntu 22.04 LTS installed
- [ ] 4 NVIDIA GPUs available
- [ ] Minimum 64GB RAM
- [ ] 10TB+ storage mounted
- [ ] Static IP address assigned
- [ ] Root/sudo access available

### NVIDIA Setup
- [ ] NVIDIA drivers installed (`nvidia-smi` works)
- [ ] All 4 GPUs detected
- [ ] CUDA version compatible (11.8+)

### Domain & DNS
- [ ] Domain name registered
- [ ] DNS A records configured:
  - [ ] `@` → Server IP
  - [ ] `*` → Server IP
  - [ ] `mlflow` → Server IP
  - [ ] `grafana` → Server IP
  - [ ] `prometheus` → Server IP
  - [ ] `inference` → Server IP

### GitHub OAuth
- [ ] GitHub OAuth App created
- [ ] Client ID obtained
- [ ] Client Secret obtained
- [ ] Callback URL set to `https://your-domain.com/api/auth/github/callback`

## Deployment Steps

### 1. Repository Setup
- [ ] Clone repository: `git clone https://github.com/your-repo/ai-lab-platform.git`
- [ ] Change to directory: `cd ai-lab-platform`
- [ ] Copy environment file: `cp production.env.example production.env`

### 2. Configuration
- [ ] Edit `production.env` with:
  - [ ] `DOMAIN` set to your domain
  - [ ] `ALERT_EMAIL` set
  - [ ] `GITHUB_CLIENT_ID` configured
  - [ ] `GITHUB_CLIENT_SECRET` configured
  - [ ] Storage paths verified
  - [ ] Resource limits reviewed

### 3. Run Deployment
- [ ] Make script executable: `chmod +x deploy_production.sh`
- [ ] Run deployment: `sudo ./deploy_production.sh`
- [ ] Monitor output for errors
- [ ] Note generated passwords

### 4. Verify Installation
- [ ] All Docker containers running: `docker ps`
- [ ] No container restart loops
- [ ] GPU access verified: `docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi`

## Post-Deployment Checklist

### Service Access
- [ ] Main platform accessible: `https://your-domain.com`
- [ ] SSL certificate valid (padlock in browser)
- [ ] Admin portal accessible: `https://your-domain.com/admin`
- [ ] MLflow accessible: `https://mlflow.your-domain.com`
- [ ] Grafana accessible: `https://grafana.your-domain.com`
- [ ] Can login to Grafana with generated password

### Security
- [ ] Review `credentials.txt` file
- [ ] Change default admin password (admin/admin123)
- [ ] Set up team access in GitHub OAuth
- [ ] Delete or secure `credentials.txt`
- [ ] Firewall rules active: `sudo ufw status`

### Monitoring Setup
- [ ] Grafana datasource connected
- [ ] GPU metrics visible in Grafana
- [ ] Import custom dashboards
- [ ] Configure alert channels
- [ ] Set up alert rules

### Backup Verification
- [ ] Backup script created: `/usr/local/bin/ai-lab-backup.sh`
- [ ] Cron job configured: `crontab -l`
- [ ] Test manual backup: `sudo /usr/local/bin/ai-lab-backup.sh`
- [ ] Verify backup files created in `$BACKUP_PATH`

### Platform Testing
- [ ] Create test user account
- [ ] Launch PyTorch environment
- [ ] GPU available in environment
- [ ] MLflow tracking works
- [ ] File uploads work
- [ ] Model training succeeds
- [ ] TorchServe inference works

## Maintenance Schedule

### Daily
- [ ] Check Grafana dashboards
- [ ] Review backup logs
- [ ] Monitor disk usage

### Weekly
- [ ] Review user activity
- [ ] Check for security updates
- [ ] Verify SSL certificate status
- [ ] Review resource utilization

### Monthly
- [ ] Update platform components
- [ ] Rotate logs
- [ ] Audit user access
- [ ] Test disaster recovery

## Troubleshooting Quick Reference

### Service Issues
```bash
# View all logs
docker-compose -f docker-compose.production.yml logs

# Restart all services
docker-compose -f docker-compose.production.yml restart

# Check specific service
docker logs ai-lab-backend
```

### GPU Issues
```bash
# Test GPU access
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# Check NVIDIA runtime
docker info | grep nvidia
```

### SSL Issues
```bash
# Test certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Force renewal
sudo certbot renew --force-renewal
```

## Support Contacts

- Platform Issues: [Create GitHub Issue]
- Security Concerns: security@your-domain.com
- Emergency: [Your emergency contact]

## Sign-off

- [ ] Deployment completed by: ________________
- [ ] Date: ________________
- [ ] All checklist items verified
- [ ] Documentation provided to team
- [ ] Credentials secured 