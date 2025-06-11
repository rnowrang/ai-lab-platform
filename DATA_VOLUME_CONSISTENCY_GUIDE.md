# Data Volume Consistency Guide

## 🔍 **The Problem (SOLVED)**

The AI Lab Platform had a "split-brain" data architecture where:

- **Backend Service**: Used `./ai-lab-data/` (project directory)
- **User Environments**: Used `/opt/ai-lab-data/` (production directory)

This caused the shared folder to appear empty in environments after reboots because the two locations weren't synchronized.

## ✅ **The Solution (IMPLEMENTED)**

**Single Source of Truth**: All components now use the **project directory** as the canonical data location.

### **Configuration Changes Made:**

1. **Updated `production.env`:**
   ```bash
   # OLD (split-brain):
   HOST_DATA_PATH=/opt/ai-lab-data
   
   # NEW (single source):
   HOST_DATA_PATH=/home/llurad/ai-lab-platform/ai-lab-data
   ```

2. **Data Flow Now:**
   ```
   Backend Service     →  ./ai-lab-data/          (project directory)
   User Environments  →  ./ai-lab-data/          (SAME location)
   ```

## 🎯 **Benefits**

✅ **Consistency**: Both backend and environments use the same data location
✅ **Persistence**: Data survives reboots automatically
✅ **Simplicity**: No need to sync between multiple locations
✅ **Version Control**: Shared data can be included in git (if desired)

## 📂 **Current Data Structure**

```
ai-lab-platform/
├── ai-lab-data/           # ← Single source of truth
│   ├── shared/           # ← Shared data (MLflow examples, datasets)
│   ├── users/            # ← User-specific data
│   └── admin/            # ← Admin data and backups
├── production.env        # ← Points to ai-lab-data/ above
└── docker-compose.production.yml
```

## 🔄 **How It Works Now**

1. **Backend**: Mounts `./ai-lab-data` to `/app/ai-lab-data`
2. **Environments**: Mount `HOST_DATA_PATH` (now pointing to `./ai-lab-data`)
3. **Result**: Both see the exact same files

## 🛡️ **Backup and Migration**

### **Pre-Fix Backup Created:**
- `production.env.backup` - Original configuration

### **Data Locations:**
- **Active**: `./ai-lab-data/` (project directory)
- **Legacy**: `/opt/ai-lab-data/` (can be removed if no longer needed)

## 🚀 **Future Data Management**

### **Adding Shared Data:**
```bash
# Add files directly to the project directory
cp new-dataset.csv ai-lab-data/shared/datasets/
cp new-example.py ai-lab-data/shared/
```

### **Adding User Data:**
```bash
# Files go to user-specific directories
cp user-file.ipynb ai-lab-data/users/demo@ailab.com/
```

### **Environment Access:**
- Shared data: `/home/jovyan/shared/`
- User data: `/home/jovyan/data/`

## 🔧 **Verification Commands**

### **Check Configuration:**
```bash
grep HOST_DATA_PATH production.env
# Should show: HOST_DATA_PATH=/home/llurad/ai-lab-platform/ai-lab-data
```

### **Verify Data Consistency:**
```bash
# Backend sees:
docker exec ai-lab-backend ls /app/ai-lab-data/shared/

# Environment sees (create environment first):
docker exec <environment-name> ls /home/jovyan/shared/
```

### **Test New Environment:**
1. Create new environment
2. Check shared folder has all your MLflow examples
3. Data should persist after restart

## 📋 **Troubleshooting**

### **If Shared Folder Empty:**
1. Check current config: `grep HOST_DATA_PATH production.env`
2. Should point to: `/home/llurad/ai-lab-platform/ai-lab-data`
3. Restart backend: `docker restart ai-lab-backend`

### **If Data Missing After Reboot:**
- This should NOT happen anymore with the fix
- All data is in the project directory which persists

## 🎉 **Status: RESOLVED**

The data volume consistency issue has been permanently resolved. Your shared folder will now:
- ✅ Always map to the same location
- ✅ Persist across reboots
- ✅ Be consistent between backend and environments
- ✅ Allow easy data management

No more manual syncing required! 