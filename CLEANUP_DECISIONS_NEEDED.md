# CLEANUP DECISIONS NEEDED

## 🔴 Large Model Files (127MB total)
**Decision needed:** Keep or remove?
- `model_store/resnet18.pt` (45MB)
- `model_store/resnet18.mar` (42MB) 
- `model_store/simple_classifier.mar` (40MB)

**Questions:**
- Are these example models still needed?
- Should they be moved to external storage?
- Are they used by any active services?

## 🔄 Deployment Scripts Consolidation
**Current scripts (8 total, 3,448 lines):**
- `deploy_production_ip.sh` (CURRENT ACTIVE - 440 lines)
- `deploy_production.sh` (455 lines)
- `deploy_k3s_optimized.sh` (442 lines)
- `deploy_stage1.sh` (604 lines)
- `deploy_stage2.sh` (624 lines)
- `deploy_local_dev.sh` (345 lines)
- `deploy_example_model.py` (287 lines)
- `deploy_simple_stage2.py` (251 lines)

**Recommendation:** Keep only active production script, archive others

## 🧪 Test Files & Data
**Test directories to review:**
- `ai-lab-data/users/test_*` (5 test user directories)
- `test_*.py` files (3 files)
- `final_user_isolation_test.ps1`
- Test datasets and notebooks

**Decision:** Remove test users from production data?

## 📝 Configuration Files (30 total)
**Multiple environment configs:**
- `docker-compose.yml` vs `docker-compose.production.yml`
- `values-jupyterhub*.yaml` (3 variants)
- `k3s-*.yaml` files
- PowerShell scripts for Windows deployment (3 files)

**Questions:**
- Which deployment target is primary?
- Are Windows PowerShell scripts still needed?
- Which Kubernetes configs are active?

## 🗂️ Duplicate Files Detected
**Potential duplicates:**
- Multiple `router.py` files (2 instances)
- Multiple `multi_gpu_workaround.py` files (2 instances)

## 📂 Directory Structure Review
**Consider organizing:**
- Move all deployment scripts to `deployment/` directory
- Move all test files to `tests/` directory
- Consolidate configuration files by environment 