# AI Lab Platform - Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the AI Lab Platform in a production environment on Ubuntu Server with 4 GPUs.

## Prerequisites

### Hardware Requirements
- **Server**: Ubuntu 22.04 LTS
- **GPUs**: 4× NVIDIA GPUs (2080 Ti or better)
- **RAM**: Minimum 64GB
- **Storage**: 10TB+ attached storage
- **Network**: Static IP address with domain name

### Software Requirements
- Ubuntu 22.04 LTS (fresh installation)
- NVIDIA drivers installed
- Root or sudo access
- Domain name with DNS control

## Quick Start

```bash
# Clone the repository
git clone https://github.com/your-repo/ai-lab-platform.git
cd ai-lab-platform

# Configure environment
cp production.env.example production.env
nano production.env  # Edit with your settings

# Run deployment script
sudo chmod +x deploy_production.sh
sudo ./deploy_production.sh
```

## Detailed Setup Instructions

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install NVIDIA drivers if not already installed
sudo apt install nvidia-driver-530
sudo reboot

# Verify GPU installation
nvidia-smi
```

### 2. Domain Configuration

Configure your DNS with the following records:

```
A     @              -> YOUR_SERVER_IP
A     *.             -> YOUR_SERVER_IP
A     mlflow         -> YOUR_SERVER_IP
A     grafana        -> YOUR_SERVER_IP
A     prometheus     -> YOUR_SERVER_IP
A     inference      -> YOUR_SERVER_IP
```

### 3. Environment Configuration

Edit `production.env` with your settings:

```bash
# Essential configurations
DOMAIN=your-domain.com
ALERT_EMAIL=admin@your-domain.com
DATA_PATH=/opt/ai-lab-data
BACKUP_PATH=/opt/backups

# OAuth (for GitHub authentication)
GITHUB_CLIENT_ID=your-github-oauth-client-id
GITHUB_CLIENT_SECRET=your-github-oauth-client-secret

# Leave passwords blank to auto-generate secure ones
POSTGRES_PASSWORD=
SECRET_KEY=
REDIS_PASSWORD=
GRAFANA_ADMIN_PASSWORD=
```

### 4. Run Deployment

```bash
sudo ./deploy_production.sh
```

The script will:
1. ✅ Check system requirements
2. ✅ Install Docker and NVIDIA Docker runtime
3. ✅ Set up storage directories
4. ✅ Configure firewall rules
5. ✅ Generate SSL certificates
6. ✅ Create secure passwords
7. ✅ Deploy all services
8. ✅ Set up automated backups
9. ✅ Configure monitoring

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Users     │────▶│   Nginx     │────▶│   Backend   │
└─────────────┘     │   (SSL)     │     │   (Flask)   │
                    └─────────────┘     └─────────────┘
                           │                     │
                           ▼                     ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   MLflow    │     │  PostgreSQL │     │   Docker    │
│   Tracking  │────▶│  Database   │     │ Containers  │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                     │
                           ▼                     ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Prometheus │────▶│   Grafana   │     │ TorchServe  │
│   Metrics   │     │ Dashboards  │     │   Models    │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Service Endpoints

After deployment, services are available at:

| Service | URL | Purpose |
|---------|-----|---------|
| Main Platform | `https://your-domain.com` | User portal |
| Admin Portal | `https://your-domain.com/admin` | Admin interface |
| MLflow | `https://mlflow.your-domain.com` | Experiment tracking |
| Grafana | `https://grafana.your-domain.com` | Monitoring dashboards |
| Prometheus | `https://prometheus.your-domain.com` | Metrics (restricted) |
| Inference API | `https://inference.your-domain.com` | Model serving |

## Post-Deployment Configuration

### 1. Change Default Passwords

```bash
# Review generated credentials
sudo cat credentials.txt

# Login to the platform and change admin password
# Default: admin/admin123
```

### 2. Configure OAuth Authentication

1. Create GitHub OAuth App:
   - Go to GitHub Settings > Developer settings > OAuth Apps
   - New OAuth App with:
     - Homepage URL: `https://your-domain.com`
     - Authorization callback URL: `https://your-domain.com/api/auth/github/callback`

2. Update `production.env` with Client ID and Secret

3. Restart services:
   ```bash
   docker-compose -f docker-compose.production.yml restart backend
   ```

### 3. Setup Monitoring Alerts

1. Access Grafana: `https://grafana.your-domain.com`
2. Configure alert channels (email, Slack, etc.)
3. Import dashboards from `monitoring/grafana/dashboards/`

### 4. Configure Backup Retention

Edit `/usr/local/bin/ai-lab-backup.sh` to adjust backup settings.

## Security Hardening

### SSL/TLS Configuration

The platform uses strong TLS settings:
- TLS 1.2 and 1.3 only
- Strong cipher suites
- HSTS enabled
- SSL stapling

### Firewall Rules

Only required ports are open:
- 22 (SSH)
- 80 (HTTP - redirects to HTTPS)
- 443 (HTTPS)

### Access Control

- Admin areas protected with HTTP Basic Auth
- API rate limiting enabled
- CORS configured for your domain only

## Maintenance

### Daily Tasks
- Monitor Grafana dashboards
- Check backup logs: `/var/log/ai-lab-backup.log`

### Weekly Tasks
- Review resource usage
- Check for security updates
- SSL certificate renewal (automated)

### Monthly Tasks
- Update platform components
- Review and rotate logs
- Audit user access

## Backup and Recovery

### Automated Backups

Daily backups run at 2 AM including:
- PostgreSQL databases
- MLflow artifacts
- User data

### Manual Backup

```bash
sudo /usr/local/bin/ai-lab-backup.sh
```

### Restore Process

```bash
# Stop services
docker-compose -f docker-compose.production.yml down

# Restore PostgreSQL
docker-compose -f docker-compose.production.yml up -d postgres
docker exec -i ai-lab-postgres psql -U postgres < backup.sql

# Restore data files
tar -xzf mlflow_artifacts.tar.gz -C /opt/ai-lab-data/
tar -xzf user_data.tar.gz -C /opt/ai-lab-data/

# Start services
docker-compose -f docker-compose.production.yml up -d
```

## Troubleshooting

### Common Issues

#### Services Not Starting

```bash
# Check logs
docker-compose -f docker-compose.production.yml logs -f [service-name]

# Restart specific service
docker-compose -f docker-compose.production.yml restart [service-name]
```

#### GPU Not Available

```bash
# Check NVIDIA Docker runtime
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# Restart Docker
sudo systemctl restart docker
```

#### SSL Certificate Issues

```bash
# Test certificate
openssl s_client -connect your-domain.com:443

# Renew manually
sudo certbot renew --force-renewal
```

### Log Locations

- Nginx: `docker logs ai-lab-nginx`
- Backend: `docker logs ai-lab-backend`
- PostgreSQL: `docker logs ai-lab-postgres`
- System: `journalctl -u ai-lab-platform`

## Scaling

### Horizontal Scaling

To add more GPU nodes:

1. Install Docker and NVIDIA runtime on new node
2. Join Docker Swarm cluster
3. Update service constraints

### Vertical Scaling

Adjust resource limits in `docker-compose.production.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'
      memory: 32G
```

## Updates and Upgrades

### Platform Updates

```bash
# Backup first
sudo /usr/local/bin/ai-lab-backup.sh

# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose -f docker-compose.production.yml build
docker-compose -f docker-compose.production.yml up -d
```

### Security Updates

```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Docker updates
docker-compose -f docker-compose.production.yml pull
docker-compose -f docker-compose.production.yml up -d
```

## Support

For issues:
1. Check logs first
2. Review this documentation
3. Check GitHub issues
4. Contact support with:
   - Error messages
   - Log excerpts
   - Steps to reproduce

## License

This deployment is subject to the project license terms. 