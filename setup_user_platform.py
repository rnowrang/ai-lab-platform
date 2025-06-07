#!/usr/bin/env python3
"""
Quick Setup: AI Lab User Platform
Creates a simplified user-facing platform with authentication and GPU resource selection
"""

import os
import json

def create_user_platform_interface():
    """Create a comprehensive user platform interface"""
    
    html_content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Lab User Platform</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            color: white;
            margin-bottom: 40px;
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .auth-section, .dashboard-section {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            display: none;
        }
        
        .auth-section.active, .dashboard-section.active {
            display: block;
        }
        
        .auth-form {
            max-width: 400px;
            margin: 0 auto;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 600;
            color: #555;
        }
        
        .form-group input, .form-group select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e1e1e1;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        .form-group input:focus, .form-group select:focus {
            border-color: #667eea;
            outline: none;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 30px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
            transition: transform 0.2s;
            width: 100%;
            margin-bottom: 10px;
        }
        
        .btn:hover {
            transform: translateY(-2px);
        }
        
        .btn-secondary {
            background: #6c757d;
        }
        
        .resource-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .resource-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            border: 2px solid #e1e1e1;
            transition: all 0.3s;
        }
        
        .resource-card:hover {
            border-color: #667eea;
            transform: translateY(-5px);
        }
        
        .resource-card h3 {
            color: #667eea;
            margin-bottom: 15px;
        }
        
        .gpu-selector {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 10px;
            margin: 20px 0;
        }
        
        .gpu-option {
            background: #e9ecef;
            border: 2px solid #dee2e6;
            border-radius: 8px;
            padding: 15px 10px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .gpu-option.selected {
            background: #667eea;
            color: white;
            border-color: #667eea;
        }
        
        .environment-templates {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        
        .template-card {
            background: white;
            border: 2px solid #e1e1e1;
            border-radius: 10px;
            padding: 20px;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .template-card:hover {
            border-color: #667eea;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        
        .template-card.selected {
            border-color: #667eea;
            background: #f8f9ff;
        }
        
        .quota-display {
            background: #e8f4fd;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 30px;
        }
        
        .quota-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
        }
        
        .progress-bar {
            background: #e9ecef;
            border-radius: 10px;
            height: 8px;
            overflow: hidden;
            margin-top: 5px;
        }
        
        .progress-fill {
            background: linear-gradient(90deg, #667eea, #764ba2);
            height: 100%;
            transition: width 0.3s;
        }
        
        .environment-list {
            margin-top: 30px;
        }
        
        .environment-item {
            background: white;
            border: 1px solid #e1e1e1;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 15px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .env-info h4 {
            color: #667eea;
            margin-bottom: 5px;
        }
        
        .env-status {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-running { background: #d4edda; color: #155724; }
        .status-starting { background: #fff3cd; color: #856404; }
        .status-stopped { background: #f8d7da; color: #721c24; }
        
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
        }
        
        .modal.active {
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .modal-content {
            background: white;
            border-radius: 15px;
            padding: 30px;
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
        }
        
        .alert {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .nav-tabs {
            display: flex;
            margin-bottom: 20px;
            border-bottom: 2px solid #e1e1e1;
        }
        
        .nav-tab {
            padding: 10px 20px;
            cursor: pointer;
            border-bottom: 2px solid transparent;
            transition: all 0.3s;
        }
        
        .nav-tab.active {
            border-bottom-color: #667eea;
            color: #667eea;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 AI Lab User Platform</h1>
            <p>Multi-User ML Platform with Dynamic GPU Allocation</p>
        </div>

        <!-- Authentication Section -->
        <div class="auth-section active" id="authSection">
            <div class="nav-tabs">
                <div class="nav-tab active" onclick="showAuthTab('login')">Login</div>
                <div class="nav-tab" onclick="showAuthTab('register')">Register</div>
            </div>

            <!-- Login Form -->
            <div id="loginForm" class="auth-form">
                <h2 style="text-align: center; margin-bottom: 30px;">Welcome Back</h2>
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" id="loginEmail" placeholder="Enter your email">
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <input type="password" id="loginPassword" placeholder="Enter your password">
                </div>
                <button class="btn" onclick="handleLogin()">Sign In</button>
                <p style="text-align: center; margin-top: 15px;">
                    Demo Account: <code>demo@ailab.com</code> / <code>demo123</code>
                </p>
            </div>

            <!-- Register Form -->
            <div id="registerForm" class="auth-form" style="display: none;">
                <h2 style="text-align: center; margin-bottom: 30px;">Create Account</h2>
                <div class="form-group">
                    <label>Full Name</label>
                    <input type="text" id="registerName" placeholder="Enter your full name">
                </div>
                <div class="form-group">
                    <label>Email</label>
                    <input type="email" id="registerEmail" placeholder="Enter your email">
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <input type="password" id="registerPassword" placeholder="Create a password">
                </div>
                <button class="btn" onclick="handleRegister()">Create Account</button>
            </div>
        </div>

        <!-- Dashboard Section -->
        <div class="dashboard-section" id="dashboardSection">
            <div class="quota-display">
                <h3>🎯 Your Resource Quota</h3>
                <div class="quota-item">
                    <span>GPU Usage:</span>
                    <span id="gpuUsage">0/4 GPUs</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="gpuProgress" style="width: 0%"></div>
                </div>
                
                <div class="quota-item">
                    <span>Active Environments:</span>
                    <span id="envUsage">0/5 Environments</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="envProgress" style="width: 0%"></div>
                </div>
            </div>

            <h3>🖥️ Quick Start Templates</h3>
            <div class="environment-templates">
                <div class="template-card" onclick="selectTemplate('pytorch')">
                    <h4>🔥 PyTorch + JupyterLab</h4>
                    <p>Pre-configured PyTorch environment with JupyterLab interface</p>
                    <div style="margin-top: 10px;">
                        <span style="background: #e3f2fd; padding: 5px 10px; border-radius: 15px; font-size: 12px;">1 GPU • 16GB RAM</span>
                    </div>
                </div>
                
                <div class="template-card" onclick="selectTemplate('tensorflow')">
                    <h4>🧠 TensorFlow + JupyterLab</h4>
                    <p>TensorFlow environment optimized for deep learning</p>
                    <div style="margin-top: 10px;">
                        <span style="background: #e8f5e8; padding: 5px 10px; border-radius: 15px; font-size: 12px;">1 GPU • 16GB RAM</span>
                    </div>
                </div>
                
                <div class="template-card" onclick="selectTemplate('vscode')">
                    <h4>💻 VS Code Development</h4>
                    <p>Full development environment with VS Code Server</p>
                    <div style="margin-top: 10px;">
                        <span style="background: #fff3e0; padding: 5px 10px; border-radius: 15px; font-size: 12px;">1 GPU • 8GB RAM</span>
                    </div>
                </div>
                
                <div class="template-card" onclick="selectTemplate('multi-gpu')">
                    <h4>⚡ Multi-GPU Training</h4>
                    <p>Distributed training with multiple GPUs</p>
                    <div style="margin-top: 10px;">
                        <span style="background: #fce4ec; padding: 5px 10px; border-radius: 15px; font-size: 12px;">4 GPU • 32GB RAM</span>
                    </div>
                </div>
            </div>

            <div style="text-align: center; margin: 30px 0;">
                <button class="btn" onclick="showCreateModal()">🚀 Create Custom Environment</button>
                <button class="btn btn-secondary" onclick="handleLogout()">Logout</button>
            </div>

            <!-- Current Environments -->
            <div class="environment-list">
                <h3>📱 Your Environments</h3>
                <div id="environmentsList">
                    <div class="environment-item">
                        <div class="env-info">
                            <h4>pytorch-demo-env</h4>
                            <p>PyTorch + JupyterLab • 1x RTX 3090 • 4 cores • 16GB RAM</p>
                        </div>
                        <div>
                            <span class="env-status status-running">Running</span>
                            <button class="btn" style="width: auto; margin-left: 10px;" onclick="openEnvironment('pytorch-demo-env')">Open</button>
                        </div>
                    </div>
                    
                    <div class="environment-item">
                        <div class="env-info">
                            <h4>tensorflow-experiment</h4>
                            <p>TensorFlow + JupyterLab • 2x RTX 3090 • 8 cores • 32GB RAM</p>
                        </div>
                        <div>
                            <span class="env-status status-starting">Starting</span>
                            <button class="btn btn-secondary" style="width: auto; margin-left: 10px;" disabled>Starting...</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Create Environment Modal -->
    <div class="modal" id="createModal">
        <div class="modal-content">
            <h3>🚀 Create New Environment</h3>
            
            <div class="form-group">
                <label>Environment Name</label>
                <input type="text" id="envName" placeholder="my-ml-environment">
            </div>
            
            <div class="form-group">
                <label>Environment Type</label>
                <select id="envType">
                    <option value="jupyter">JupyterLab</option>
                    <option value="vscode">VS Code Server</option>
                    <option value="custom">Custom</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>GPU Count</label>
                <div class="gpu-selector">
                    <div class="gpu-option selected" onclick="selectGPU(1)">1 GPU</div>
                    <div class="gpu-option" onclick="selectGPU(2)">2 GPUs</div>
                    <div class="gpu-option" onclick="selectGPU(3)">3 GPUs</div>
                    <div class="gpu-option" onclick="selectGPU(4)">4 GPUs</div>
                </div>
            </div>
            
            <div class="form-group">
                <label>GPU Type</label>
                <select id="gpuType">
                    <option value="rtx-3090">RTX 3090 (24GB VRAM)</option>
                    <option value="rtx-2080-ti">RTX 2080 Ti (11GB VRAM)</option>
                </select>
            </div>
            
            <div class="resource-grid">
                <div>
                    <label>CPU Cores: <span id="cpuValue">4</span></label>
                    <input type="range" id="cpuSlider" min="1" max="16" value="4" oninput="updateSliderValue('cpu', this.value)">
                </div>
                <div>
                    <label>Memory: <span id="memoryValue">16</span>GB</label>
                    <input type="range" id="memorySlider" min="4" max="64" step="4" value="16" oninput="updateSliderValue('memory', this.value)">
                </div>
            </div>
            
            <div style="display: flex; gap: 10px; margin-top: 30px;">
                <button class="btn" onclick="createEnvironment()">Create Environment</button>
                <button class="btn btn-secondary" onclick="closeCreateModal()">Cancel</button>
            </div>
        </div>
    </div>

    <script>
        let currentUser = null;
        let selectedGPUCount = 1;
        let mockEnvironments = [
            {
                name: 'pytorch-demo-env',
                type: 'jupyter',
                gpus: 1,
                status: 'running',
                url: 'http://localhost:8888'
            },
            {
                name: 'tensorflow-experiment', 
                type: 'jupyter',
                gpus: 2,
                status: 'starting',
                url: null
            }
        ];

        function showAuthTab(tab) {
            document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
            event.target.classList.add('active');
            
            if (tab === 'login') {
                document.getElementById('loginForm').style.display = 'block';
                document.getElementById('registerForm').style.display = 'none';
            } else {
                document.getElementById('loginForm').style.display = 'none';
                document.getElementById('registerForm').style.display = 'block';
            }
        }

        function handleLogin() {
            const email = document.getElementById('loginEmail').value;
            const password = document.getElementById('loginPassword').value;
            
            // Mock authentication
            if (email && password) {
                currentUser = {
                    name: email.split('@')[0],
                    email: email,
                    gpuQuota: 4,
                    envQuota: 5
                };
                showDashboard();
                showAlert('Successfully logged in!', 'success');
            } else {
                showAlert('Please enter email and password', 'error');
            }
        }

        function handleRegister() {
            const name = document.getElementById('registerName').value;
            const email = document.getElementById('registerEmail').value;
            const password = document.getElementById('registerPassword').value;
            
            if (name && email && password) {
                currentUser = {
                    name: name,
                    email: email,
                    gpuQuota: 2,
                    envQuota: 3
                };
                showDashboard();
                showAlert('Account created successfully!', 'success');
            } else {
                showAlert('Please fill in all fields', 'error');
            }
        }

        function handleLogout() {
            currentUser = null;
            document.getElementById('authSection').classList.add('active');
            document.getElementById('dashboardSection').classList.remove('active');
            showAlert('Logged out successfully', 'success');
        }

        function showDashboard() {
            document.getElementById('authSection').classList.remove('active');
            document.getElementById('dashboardSection').classList.add('active');
            updateQuotaDisplay();
        }

        function updateQuotaDisplay() {
            const usedGPUs = mockEnvironments.filter(env => env.status === 'running').reduce((sum, env) => sum + env.gpus, 0);
            const activeEnvs = mockEnvironments.filter(env => env.status !== 'stopped').length;
            
            document.getElementById('gpuUsage').textContent = `${usedGPUs}/${currentUser.gpuQuota} GPUs`;
            document.getElementById('envUsage').textContent = `${activeEnvs}/${currentUser.envQuota} Environments`;
            
            document.getElementById('gpuProgress').style.width = `${(usedGPUs / currentUser.gpuQuota) * 100}%`;
            document.getElementById('envProgress').style.width = `${(activeEnvs / currentUser.envQuota) * 100}%`;
        }

        function selectTemplate(template) {
            const templates = {
                pytorch: { name: 'pytorch-jupyter-env', type: 'jupyter', gpus: 1, cpu: 4, memory: 16 },
                tensorflow: { name: 'tensorflow-jupyter-env', type: 'jupyter', gpus: 1, cpu: 4, memory: 16 },
                vscode: { name: 'vscode-dev-env', type: 'vscode', gpus: 1, cpu: 2, memory: 8 },
                'multi-gpu': { name: 'multi-gpu-training-env', type: 'jupyter', gpus: 4, cpu: 16, memory: 32 }
            };
            
            const config = templates[template];
            if (config) {
                document.getElementById('envName').value = config.name;
                document.getElementById('envType').value = config.type;
                selectGPU(config.gpus);
                document.getElementById('cpuSlider').value = config.cpu;
                document.getElementById('memorySlider').value = config.memory;
                updateSliderValue('cpu', config.cpu);
                updateSliderValue('memory', config.memory);
                showCreateModal();
            }
        }

        function selectGPU(count) {
            selectedGPUCount = count;
            document.querySelectorAll('.gpu-option').forEach((option, index) => {
                option.classList.toggle('selected', index + 1 === count);
            });
        }

        function updateSliderValue(type, value) {
            document.getElementById(type + 'Value').textContent = value;
        }

        function showCreateModal() {
            document.getElementById('createModal').classList.add('active');
        }

        function closeCreateModal() {
            document.getElementById('createModal').classList.remove('active');
        }

        function createEnvironment() {
            const envName = document.getElementById('envName').value;
            const envType = document.getElementById('envType').value;
            
            if (!envName) {
                showAlert('Please enter an environment name', 'error');
                return;
            }
            
            // Mock environment creation
            const newEnv = {
                name: envName,
                type: envType,
                gpus: selectedGPUCount,
                status: 'starting',
                url: null
            };
            
            mockEnvironments.push(newEnv);
            updateEnvironmentsList();
            updateQuotaDisplay();
            closeCreateModal();
            showAlert(`Environment "${envName}" is being created...`, 'success');
            
            // Simulate environment starting
            setTimeout(() => {
                newEnv.status = 'running';
                newEnv.url = `http://localhost:${8888 + Math.floor(Math.random() * 100)}`;
                updateEnvironmentsList();
                updateQuotaDisplay();
                showAlert(`Environment "${envName}" is now running!`, 'success');
            }, 5000);
        }

        function updateEnvironmentsList() {
            const container = document.getElementById('environmentsList');
            container.innerHTML = '';
            
            mockEnvironments.forEach(env => {
                const statusClass = `status-${env.status}`;
                const statusText = env.status.charAt(0).toUpperCase() + env.status.slice(1);
                const actionButton = env.status === 'running' && env.url ? 
                    `<button class="btn" style="width: auto; margin-left: 10px;" onclick="openEnvironment('${env.name}')">Open</button>` :
                    `<button class="btn btn-secondary" style="width: auto; margin-left: 10px;" disabled>${statusText}...</button>`;
                
                container.innerHTML += `
                    <div class="environment-item">
                        <div class="env-info">
                            <h4>${env.name}</h4>
                            <p>${env.type.toUpperCase()} • ${env.gpus}x RTX 3090 • 4 cores • 16GB RAM</p>
                        </div>
                        <div>
                            <span class="env-status ${statusClass}">${statusText}</span>
                            ${actionButton}
                        </div>
                    </div>
                `;
            });
        }

        function openEnvironment(name) {
            const env = mockEnvironments.find(e => e.name === name);
            if (env && env.url) {
                // For demo, redirect to existing JupyterLab
                window.open('http://localhost:8888', '_blank');
            }
        }

        function showAlert(message, type) {
            const alertDiv = document.createElement('div');
            alertDiv.className = `alert alert-${type}`;
            alertDiv.textContent = message;
            alertDiv.style.position = 'fixed';
            alertDiv.style.top = '20px';
            alertDiv.style.right = '20px';
            alertDiv.style.zIndex = '10000';
            alertDiv.style.minWidth = '300px';
            
            document.body.appendChild(alertDiv);
            
            setTimeout(() => {
                alertDiv.remove();
            }, 4000);
        }

        // Initialize
        updateEnvironmentsList();
    </script>
</body>
</html>"""
    
    with open("ai_lab_user_platform.html", "w", encoding="utf-8") as f:
        f.write(html_content)
    
    print("✅ Created AI Lab User Platform interface")

def create_platform_readme():
    """Create README for the user platform"""
    readme_content = """# 🚀 AI Lab User Platform

## Multi-User ML Platform with Dynamic GPU Allocation

A comprehensive user-facing platform that transforms your AI Lab infrastructure into a service similar to RunPod.ai, allowing users to:

- **🔐 Authenticate and manage accounts**
- **🎯 Select GPU resources (1-4 GPUs)**  
- **🚀 Spin up containerized ML environments**
- **📊 Monitor usage and costs**
- **💻 Access JupyterLab, VS Code, or custom environments**

## 🎯 Quick Start

### Option 1: Standalone Interface (Immediate)
```bash
python setup_user_platform.py
# Opens ai_lab_user_platform.html in your browser
```

### Option 2: Full Platform Deployment
```bash
python user-platform/deploy_user_platform.py
# Deploys complete backend + frontend with Docker
```

## 🌟 Key Features

### **User Experience**
- **One-click environments**: Launch JupyterLab with GPUs in 30 seconds
- **Resource flexibility**: Choose 1-4 GPUs based on workload  
- **Cost transparency**: Real-time usage and cost tracking
- **Templates**: Pre-configured ML stacks (PyTorch, TensorFlow, etc.)
- **Collaboration**: Share environments and datasets

### **For Administrators**
- **Resource utilization**: Monitor GPU efficiency across users
- **User management**: Quotas, permissions, billing
- **Performance analytics**: Platform usage patterns
- **Cost optimization**: Automated resource scaling

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API    │    │   Kubernetes    │
│   Dashboard     │────│   & Auth         │────│   + GPU Sched   │
│   (React/Vue)   │    │   (FastAPI)      │    │   (k3s + NVIDIA) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │              ┌──────────────────┐              │
         └──────────────│   User Database  │──────────────┘
                        │   (PostgreSQL)   │
                        └──────────────────┘
```

## 🎮 Available Templates

### **PyTorch + JupyterLab**
- Pre-configured PyTorch environment
- JupyterLab interface
- 1 GPU • 16GB RAM recommended

### **TensorFlow + JupyterLab** 
- TensorFlow environment optimized for deep learning
- Keras integration
- 1 GPU • 16GB RAM recommended

### **VS Code Development**
- Full development environment
- VS Code Server
- 1 GPU • 8GB RAM recommended

### **Multi-GPU Training**
- Distributed training setup
- Multiple GPU support
- 4 GPU • 32GB RAM recommended

## 🔧 Technical Implementation

### **Backend (FastAPI)**
- **Authentication**: JWT tokens with refresh
- **Resource Management**: GPU allocation and scheduling
- **Kubernetes Integration**: Dynamic pod creation
- **Monitoring**: Real-time usage metrics
- **Database**: PostgreSQL for users and environments

### **Frontend (React)**
- **Dashboard**: Resource usage overview
- **Environment Creator**: GPU selection interface
- **Real-time Updates**: WebSocket integration
- **Responsive Design**: Mobile-friendly interface

### **Infrastructure**
- **Kubernetes**: k3s with NVIDIA GPU Operator
- **Container Registry**: Private Docker registry
- **Monitoring**: Prometheus + Grafana
- **Storage**: Persistent volumes for user data

## 📊 Resource Quotas

### **Default User Quotas**
- **GPUs**: 2 concurrent GPUs
- **Memory**: 32GB RAM
- **Storage**: 100GB persistent storage
- **Environments**: 5 concurrent environments

### **Premium User Quotas**
- **GPUs**: 4 concurrent GPUs
- **Memory**: 64GB RAM  
- **Storage**: 500GB persistent storage
- **Environments**: 10 concurrent environments

## 🚀 Deployment Options

### **Development (Docker Compose)**
```bash
cd user-platform
docker compose up -d
```

### **Production (Kubernetes)**
```bash
kubectl apply -f deployment/k8s/
```

### **Cloud (AWS/GCP/Azure)**
```bash
# Terraform configurations included
terraform apply
```

## 🔗 Integration with Existing AI Lab

This user platform integrates seamlessly with your existing AI Lab infrastructure:

- **✅ Uses existing MLflow tracking**
- **✅ Connects to existing Grafana monitoring**
- **✅ Leverages existing Docker images**
- **✅ Integrates with existing GPU resources**

## 📈 Scaling

### **Single Server (4 GPUs)**
- Support for 10-20 concurrent users
- Fair-share GPU scheduling
- Local storage optimization

### **Multi-Server Cluster**
- Horizontal scaling across nodes
- Distributed GPU allocation
- Shared storage (NFS/Ceph)

### **Cloud Hybrid**
- Burst to cloud during peak usage
- Cost optimization algorithms
- Multi-cloud support

## 🎯 Use Cases

### **Research Teams**
- **Individual workspaces**: Isolated environments per researcher
- **Shared datasets**: Common data access patterns
- **Experiment tracking**: Integration with MLflow
- **Collaboration**: Shared notebooks and models

### **Educational Institutions**
- **Student accounts**: Resource quotas per student
- **Course templates**: Pre-configured environments for classes
- **Assignment submission**: Integration with academic workflows
- **Cost management**: Budget tracking per department

### **Enterprise ML Teams**
- **Project-based access**: Environments per project
- **Resource governance**: Admin controls and approvals
- **Compliance**: Audit trails and security
- **Cost allocation**: Chargeback to business units

## 🔒 Security Features

- **🔐 JWT Authentication**: Secure token-based auth
- **🛡️ Role-based Access**: Admin, user, and guest roles
- **🔒 Network Isolation**: User namespaces in Kubernetes
- **📝 Audit Logging**: Complete activity tracking
- **🚫 Resource Limits**: Prevent resource abuse

## 📞 Support

For questions, issues, or feature requests:
- **📚 Documentation**: See `/docs` folder
- **🐛 Issues**: GitHub Issues
- **💬 Discussions**: GitHub Discussions
- **📧 Email**: support@ai-lab.com

## 🚀 Future Roadmap

- **🤝 Collaboration features**: Real-time notebook sharing
- **💰 Billing integration**: Cost tracking and invoicing  
- **🔌 Plugin system**: Custom environment extensions
- **📱 Mobile app**: iOS/Android management app
- **🤖 AI assistant**: Automated environment recommendations

---

**Transform your ML infrastructure into a world-class user platform! 🌟**
"""
    
    with open("user_platform_README.md", "w", encoding="utf-8") as f:
        f.write(readme_content)
    
    print("✅ Created platform README")

def main():
    """Main setup function"""
    print("🚀 Setting up AI Lab User Platform")
    print("=" * 50)
    
    # Create the user interface
    create_user_platform_interface()
    create_platform_readme()
    
    print("\n🎉 Setup Complete!")
    print("=" * 50)
    print("🌐 User Platform Interface: ai_lab_user_platform.html")
    print("📚 Documentation: user_platform_README.md")
    print("🔧 Full Deployment: user-platform/deploy_user_platform.py")
    
    print("\n🎯 Quick Start:")
    print("1. Open ai_lab_user_platform.html in your browser")
    print("2. Try the demo authentication (demo@ailab.com / demo123)")
    print("3. Explore GPU resource allocation features")
    print("4. Create mock ML environments")
    
    print("\n📋 What's Included:")
    print("✅ User authentication interface")
    print("✅ GPU resource selection (1-4 GPUs)")
    print("✅ Environment templates (PyTorch, TensorFlow, VS Code)")
    print("✅ Resource quota management")
    print("✅ Environment monitoring dashboard")
    print("✅ Mock integration with existing AI Lab services")
    
    # Open the interface
    import webbrowser
    import os
    file_path = os.path.abspath("ai_lab_user_platform.html")
    webbrowser.open(f"file://{file_path}")
    print(f"\n🎨 Opening interface in browser...")

if __name__ == "__main__":
    main() 