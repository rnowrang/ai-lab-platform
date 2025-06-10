# Data Recovery Guide - AI Lab Platform

## 🔒 **Credential Loss Scenarios & Solutions**

### **What Credentials Control What Data**

**Database Access (CRITICAL):**
- **PostgreSQL:** Contains user accounts, MLflow experiment metadata, application data
- **Redis:** Contains session data, temporary cache (not critical for long-term data)

**Admin Access:**
- **Grafana:** Contains monitoring dashboards (can be recreated)
- **Admin Portal:** Application admin interface

**Application Secrets:**
- **Session encryption keys:** Used for user sessions (not data storage)

---

## 🔄 **Recovery Scenarios**

### **Scenario 1: Lost credentials.txt only**
**Risk Level:** 🟢 **LOW - No data loss**

**What you lose:**
- Convenience reference file
- Some admin portal passwords (if different from production.env)

**What you keep:**
- All database data ✅
- All MLflow experiments ✅
- All user data ✅
- Platform functionality ✅

**Recovery:**
```bash
# All critical credentials are in production.env
grep PASSWORD production.env
grep SECRET production.env

# Extract specific credentials
echo "PostgreSQL:" && grep POSTGRES_PASSWORD production.env
echo "Grafana:" && grep GRAFANA_ADMIN_PASSWORD production.env
echo "Redis:" && grep REDIS_PASSWORD production.env
```

### **Scenario 2: Lost both credentials.txt AND production.env**
**Risk Level:** 🟡 **MEDIUM - Data safe, access needs reset**

**What you lose:**
- Password access to admin interfaces
- Ability to start services with current config

**What you keep:**
- All data in Docker volumes ✅
- All files in /opt/ai-lab-data ✅
- All MLflow artifacts ✅

**Recovery Steps:**

#### **Step 1: Extract Data While You Can**
```bash
# Immediate data backup
docker exec ai-lab-postgres pg_dumpall -U postgres > emergency_full_backup.sql
tar -czf all_volumes_backup.tar.gz /var/lib/docker/volumes/ai-lab-platform_*
tar -czf user_data_backup.tar.gz /opt/ai-lab-data
```

#### **Step 2: Reset Database Password**
```bash
# Stop services
docker compose -f docker-compose.production.yml down

# Start PostgreSQL in recovery mode
docker run -it --rm -v ai-lab-platform_postgres_data:/var/lib/postgresql/data postgres:15-alpine bash

# Inside container, reset password
su - postgres
psql
ALTER USER postgres PASSWORD 'new_password_here';
\q
exit
```

#### **Step 3: Recreate production.env**
```bash
# Copy from example
cp production.env.example production.env

# Edit with new passwords
nano production.env
# Update: POSTGRES_PASSWORD=new_password_here
# Update: GRAFANA_ADMIN_PASSWORD=new_grafana_password
# Update: other passwords as needed
```

#### **Step 4: Restart Services**
```bash
docker compose -f docker-compose.production.yml up -d
```

### **Scenario 3: Complete System Loss**
**Risk Level:** 🟠 **HIGH - Need backups**

**If you lose the entire server:**
- Docker volumes contain your data
- Regular backups are essential

**Prevention:** Set up automatic backups

---

## 🛡️ **Data Backup Strategy**

### **Critical Data Locations**
1. **PostgreSQL Database:** Docker volume `ai-lab-platform_postgres_data`
2. **MLflow Artifacts:** Docker volume `ai-lab-platform_mlflow_artifacts`
3. **User Data:** Directory `/opt/ai-lab-data`
4. **Configuration:** Files `production.env`, docker-compose files

### **Automated Backup Script**
```bash
#!/bin/bash
# backup-all-data.sh

BACKUP_DIR="/opt/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Database backup
docker exec ai-lab-postgres pg_dumpall -U postgres > "$BACKUP_DIR/database.sql"

# Volume backups
tar -czf "$BACKUP_DIR/volumes.tar.gz" /var/lib/docker/volumes/ai-lab-platform_*

# User data backup
tar -czf "$BACKUP_DIR/user_data.tar.gz" /opt/ai-lab-data

# Configuration backup
cp production.env "$BACKUP_DIR/"
cp docker-compose.production.yml "$BACKUP_DIR/"

# Credentials backup (if exists)
if [ -f "/opt/backups/sensitive-files/credentials.txt" ]; then
    cp /opt/backups/sensitive-files/credentials.txt "$BACKUP_DIR/"
fi

echo "Backup completed: $BACKUP_DIR"
```

### **Recovery from Complete Backup**
```bash
#!/bin/bash
# restore-from-backup.sh

BACKUP_DIR="$1"

# Restore configuration
cp "$BACKUP_DIR/production.env" .
cp "$BACKUP_DIR/docker-compose.production.yml" .

# Restore database
cat "$BACKUP_DIR/database.sql" | docker exec -i ai-lab-postgres psql -U postgres

# Restore volumes
tar -xzf "$BACKUP_DIR/volumes.tar.gz" -C /

# Restore user data  
tar -xzf "$BACKUP_DIR/user_data.tar.gz" -C /

# Restart services
docker compose -f docker-compose.production.yml restart
```

---

## 🔍 **Current Backup Status**

**Existing Backups:**
- ✅ Sensitive files: `/opt/backups/sensitive-files/`
- ✅ SSL certificates: Auto-renewed
- ✅ Configuration: In git repository
- ❓ Database: No automatic backup yet
- ❓ User data: No automatic backup yet

**Recommendations:**
1. Set up weekly database backups
2. Set up daily user data backups  
3. Consider off-site backup storage
4. Test restore procedures regularly

---

## ⚡ **Quick Recovery Commands**

### **Check what data exists:**
```bash
# List all volumes
docker volume ls | grep ai-lab

# Check database
docker exec ai-lab-postgres psql -U postgres -c "\l"

# Check user data
ls -la /opt/ai-lab-data/

# Check current credentials
grep PASSWORD production.env
```

### **Emergency data export:**
```bash
# Quick database export
docker exec ai-lab-postgres pg_dumpall -U postgres > emergency_db_backup.sql

# Quick user data export
tar -czf emergency_user_backup.tar.gz /opt/ai-lab-data/
```

---

## 📞 **Emergency Contacts**

**If you need help with data recovery:**
1. Check this guide first
2. Look for backup files in `/opt/backups/`
3. Verify Docker volumes still exist: `docker volume ls`
4. Check production.env for credential redundancy

**Remember:** Your data is stored separately from credentials. Losing passwords doesn't mean losing data! 