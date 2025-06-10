# AI Lab Platform Upgrade Guide

This guide provides comprehensive instructions for managing upgrades and new features in the AI Lab Platform while preserving data and ensuring system stability.

## 🔄 Upgrade Strategy Overview

### 1. **Git Branching Strategy**

**Main branches:**
- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - Individual feature branches
- `release/*` - Release preparation branches

**Workflow:**
1. Create feature branches from `develop`
2. Merge completed features to `develop`
3. Create release branches from `develop` for testing
4. Merge stable releases to `main` with version tags

### 1.1 **Detailed Git Workflow**

#### Branch Structure
```
main
  └── develop
      ├── feature/user-authentication
      ├── feature/mlflow-integration
      ├── feature/gpu-monitoring
      └── release/v1.1.0
```

#### Branch Naming Conventions
- Feature branches: `feature/description-of-feature`
- Bug fixes: `fix/description-of-fix`
- Hotfixes: `hotfix/description-of-issue`
- Releases: `release/vX.Y.Z`
- Upgrades: `upgrade/vX.Y.Z`

#### Workflow Steps

1. **Starting a New Feature**
   ```bash
   # Create and switch to new feature branch
   git checkout develop
   git pull origin develop
   git checkout -b feature/new-feature-name
   
   # Make changes and commit
   git add .
   git commit -m "feat: add new feature description"
   
   # Push to remote
   git push origin feature/new-feature-name
   ```

2. **Completing a Feature**
   ```bash
   # Update feature branch with latest develop
   git checkout feature/new-feature-name
   git pull origin develop
   
   # Resolve any conflicts
   git merge develop
   
   # Push updates
   git push origin feature/new-feature-name
   
   # Create pull request to develop
   # Use PR template and request reviews
   ```

3. **Preparing a Release**
   ```bash
   # Create release branch
   git checkout develop
   git checkout -b release/v1.1.0
   
   # Make release-specific changes
   git commit -m "chore: prepare release v1.1.0"
   
   # Push release branch
   git push origin release/v1.1.0
   ```

4. **Completing a Release**
   ```bash
   # Merge to main
   git checkout main
   git merge release/v1.1.0
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin main
   git push origin v1.1.0
   
   # Merge back to develop
   git checkout develop
   git merge release/v1.1.0
   git push origin develop
   
   # Delete release branch
   git branch -d release/v1.1.0
   git push origin --delete release/v1.1.0
   ```

5. **Hotfix Process**
   ```bash
   # Create hotfix branch from main
   git checkout main
   git checkout -b hotfix/critical-issue
   
   # Make fixes and commit
   git commit -m "fix: resolve critical issue"
   
   # Merge to main and tag
   git checkout main
   git merge hotfix/critical-issue
   git tag -a v1.1.1 -m "Hotfix v1.1.1"
   git push origin main
   git push origin v1.1.1
   
   # Merge to develop
   git checkout develop
   git merge hotfix/critical-issue
   git push origin develop
   ```

#### Commit Message Convention
Use conventional commits format:
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

Example:
```
feat(mlflow): add artifact storage configuration

- Add S3 storage backend support
- Configure artifact cleanup policy
- Update documentation

Closes #123
```

#### Pull Request Process
1. Create PR using template
2. Request reviews from team members
3. Address review comments
4. Ensure CI/CD passes
5. Get required approvals
6. Merge using squash or rebase

#### Version Tagging
```bash
# Create annotated tag
git tag -a v1.1.0 -m "Version 1.1.0"

# Push tag
git push origin v1.1.0

# List tags
git tag -l "v*"

# Show tag details
git show v1.1.0
```

#### Git Configuration
```bash
# Set up global git config
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set up branch protection
# Configure in repository settings:
# - Require pull request reviews
# - Require status checks to pass
# - Require branches to be up to date
```

### 2. **Database Migration Strategy**

**For PostgreSQL:**
- Use Alembic or Flyway for schema migrations
- Create migration scripts for each schema change
- Test migrations on staging before production
- Back up database before applying migrations

**Example migration workflow:**
```bash
# Create migration script
alembic revision --autogenerate -m "Add user preferences table"

# Apply migration to staging
alembic upgrade head

# After testing, apply to production
alembic upgrade head
```

### 3. **Docker Image Versioning**

**Tag your images with semantic versions:**
```bash
# Build with version tag
docker build -t ai-lab-backend:1.2.3 -f Dockerfile.backend .

# Update docker-compose to use specific versions
services:
  backend:
    image: ai-lab-backend:1.2.3
```

### 4. **Configuration Management**

**Use environment variables with defaults:**
- Keep `production.env` as template
- Store actual values in secure vault or environment
- Use `.env.example` for documentation

### 5. **Data Preservation Techniques**

**For MLflow artifacts:**
- Use external storage (S3, GCS) for artifacts
- Configure MLflow to use external storage
- Keep local cache for performance

**For user data:**
- Mount volumes to persistent storage
- Regular backups with versioning
- Test restore procedures 

## 🚀 Upgrade Process

### 1. **Preparation Phase**

```bash
# Create upgrade branch
git checkout -b upgrade/v1.1.0

# Backup current state
./backup_platform.sh

# Test backup restoration
./test_restore.sh
```

### 2. **Development Phase**

```bash
# Pull latest changes
git pull origin develop

# Apply database migrations
alembic upgrade head

# Build new images
docker compose -f docker-compose.production.yml build

# Test in staging environment
docker compose -f docker-compose.staging.yml up -d
```

### 3. **Deployment Phase**

```bash
# Stop services (preserves volumes)
docker compose -f docker-compose.production.yml down

# Update images
docker compose -f docker-compose.production.yml pull

# Start with new configuration
docker compose -f docker-compose.production.yml up -d

# Verify upgrade
./verify_upgrade.sh
```

### 4. **Rollback Plan**

```bash
# If issues occur, rollback to previous version
git checkout v1.0.0
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d
```

## 📋 Upgrade Checklist

### Before Upgrade:
- [ ] Backup all data (database, volumes, configurations)
- [ ] Test upgrade in staging environment
- [ ] Document current version and configuration
- [ ] Plan maintenance window
- [ ] Prepare rollback procedure

### During Upgrade:
- [ ] Stop services gracefully
- [ ] Apply database migrations
- [ ] Update Docker images
- [ ] Update configurations
- [ ] Start services in correct order
- [ ] Verify all components

### After Upgrade:
- [ ] Run health checks
- [ ] Verify data integrity
- [ ] Test critical functionality
- [ ] Monitor for issues
- [ ] Update documentation 

## 🔧 Tools and Scripts

### 1. **Upgrade Script Template**

```bash
#!/bin/bash
# upgrade_platform.sh

set -e

VERSION=$1
BACKUP_DIR="/opt/backups/pre_upgrade_${VERSION}"

# Backup
echo "Creating backup..."
mkdir -p $BACKUP_DIR
docker exec ai-lab-postgres pg_dumpall -U postgres > $BACKUP_DIR/postgres_backup.sql
tar -czf $BACKUP_DIR/volumes.tar.gz /opt/ai-lab-data

# Update code
echo "Updating code..."
git fetch origin
git checkout $VERSION

# Apply migrations
echo "Applying database migrations..."
alembic upgrade head

# Update services
echo "Updating services..."
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d

# Verify
echo "Verifying upgrade..."
./verify_upgrade.sh

echo "Upgrade to $VERSION completed!"
```

### 2. **Verification Script**

```bash
#!/bin/bash
# verify_upgrade.sh

# Check services
docker compose -f docker-compose.production.yml ps

# Health checks
curl -f http://localhost:5555/health || echo "Backend not ready"
curl -f http://localhost:5000/health || echo "MLflow not ready"
docker exec ai-lab-postgres pg_isready -U postgres || echo "Database not ready"

# Test critical functionality
curl -X POST http://localhost:5555/api/environments \
  -H "Content-Type: application/json" \
  -d '{"user_email": "test@example.com", "environment_type": "pytorch", "gpu_count": 1}'
```

## 📊 Version Management

### 1. **Semantic Versioning**

Use semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR: Incompatible API changes
- MINOR: Backward-compatible functionality
- PATCH: Backward-compatible bug fixes

### 2. **Version Tags in Git**

```bash
# Create version tag
git tag -a v1.1.0 -m "Version 1.1.0 with new features"

# Push tag
git push origin v1.1.0
```

### 3. **Version Tracking in Database**

Add version tracking to your database:
```sql
CREATE TABLE platform_versions (
    id SERIAL PRIMARY KEY,
    version VARCHAR(20) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);
```

## 🔐 Security Considerations

### 1. **Secrets Management**

- Use Docker secrets or external vault
- Rotate credentials after upgrades
- Audit access logs

### 2. **Access Control**

- Review and update permissions
- Test authentication flows
- Verify SSL/TLS configurations

## 📈 Monitoring Upgrades

### 1. **Metrics to Watch**

- Service response times
- Error rates
- Resource utilization
- Database performance

### 2. **Alerting**

- Set up alerts for critical services
- Monitor for unusual patterns
- Have on-call procedures ready

## 🎯 Best Practices

1. **Always test upgrades in staging first**
2. **Maintain backward compatibility when possible**
3. **Document all changes and procedures**
4. **Have a rollback plan for every upgrade**
5. **Schedule upgrades during low-usage periods**
6. **Communicate changes to users in advance**
7. **Monitor closely after upgrades**
8. **Keep upgrade history and documentation**

## 📝 Example Upgrade Workflow

1. **Create upgrade branch:**
   ```bash
   git checkout -b upgrade/v1.1.0
   ```

2. **Backup current state:**
   ```bash
   ./backup_platform.sh
   ```

3. **Apply changes:**
   ```bash
   # Update code
   git pull origin develop
   
   # Apply migrations
   alembic upgrade head
   
   # Build new images
   docker compose -f docker-compose.production.yml build
   ```

4. **Test in staging:**
   ```bash
   docker compose -f docker-compose.staging.yml up -d
   ./verify_upgrade.sh
   ```

5. **Deploy to production:**
   ```bash
   # Stop services
   docker compose -f docker-compose.production.yml down
   
   # Update images
   docker compose -f docker-compose.production.yml pull
   
   # Start services
   docker compose -f docker-compose.production.yml up -d
   ```

6. **Verify and monitor:**
   ```bash
   ./verify_upgrade.sh
   # Monitor logs and metrics
   ```

7. **Tag release:**
   ```bash
   git tag -a v1.1.0 -m "Version 1.1.0"
   git push origin v1.1.0
   ```

## 📚 Related Documentation

- `RESTART_GUIDE.md` - Platform restart procedures
- `PRODUCTION_DEPLOYMENT.md` - Production deployment guide
- `DEPLOYMENT_CHECKLIST.md` - Deployment checklist
- `MULTI_GPU_SETUP.md` - Multi-GPU configuration guide

## 🆘 Support

For upgrade-related issues:
1. Check the logs: `docker compose -f docker-compose.production.yml logs`
2. Review the backup: `/opt/backups/`
3. Check version history: `git log --tags --simplify-by-decoration`
4. Contact system administrator

---

**Remember:** Always test upgrades in a staging environment before applying to production!

## 🔄 Upgrade Scripts

### 1. **Backup Script**

```bash
#!/bin/bash
# backup_platform.sh

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/backup_${TIMESTAMP}"

echo "Creating backup in $BACKUP_DIR..."

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
docker exec ai-lab-postgres pg_dumpall -U postgres > $BACKUP_DIR/postgres_backup.sql

# Backup volumes
echo "Backing up volumes..."
tar -czf $BACKUP_DIR/volumes.tar.gz /opt/ai-lab-data

# Backup configurations
echo "Backing up configurations..."
cp production.env $BACKUP_DIR/
cp -r ssl $BACKUP_DIR/
cp -r nginx $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
```

### 2. **Restore Script**

```bash
#!/bin/bash
# restore_platform.sh

set -e

BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

echo "Restoring from $BACKUP_DIR..."

# Stop services
echo "Stopping services..."
docker compose -f docker-compose.production.yml down

# Restore PostgreSQL
echo "Restoring PostgreSQL..."
docker compose -f docker-compose.production.yml up -d postgres
sleep 10
cat $BACKUP_DIR/postgres_backup.sql | docker exec -i ai-lab-postgres psql -U postgres

# Restore volumes
echo "Restoring volumes..."
tar -xzf $BACKUP_DIR/volumes.tar.gz -C /

# Restore configurations
echo "Restoring configurations..."
cp $BACKUP_DIR/production.env .
cp -r $BACKUP_DIR/ssl .
cp -r $BACKUP_DIR/nginx .

# Start services
echo "Starting services..."
docker compose -f docker-compose.production.yml up -d

echo "Restore completed!" 