# AI Lab Platform - Full Stack Deployment Script for Windows
# This script deploys the complete ML platform

Write-Host "🚀 AI Lab Platform - Full Stack Deployment" -ForegroundColor Green
Write-Host "=" * 50

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        docker ps 2>$null | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to wait for Docker to start
function Wait-ForDocker {
    Write-Host "⏳ Waiting for Docker Desktop to start..." -ForegroundColor Yellow
    $timeout = 120  # 2 minutes
    $elapsed = 0
    
    while (-not (Test-DockerRunning) -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        Write-Host "." -NoNewline
    }
    
    if (Test-DockerRunning) {
        Write-Host "`n✅ Docker is running!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "`n❌ Docker failed to start within $timeout seconds" -ForegroundColor Red
        return $false
    }
}

# Check if Docker Desktop is running
Write-Host "1️⃣ Checking Docker Desktop status..."
if (-not (Test-DockerRunning)) {
    Write-Host "❌ Docker Desktop is not running" -ForegroundColor Red
    Write-Host "📋 Please follow these steps:" -ForegroundColor Yellow
    Write-Host "   1. Open Docker Desktop from Start Menu"
    Write-Host "   2. Wait until it says 'Docker is running'"
    Write-Host "   3. Press Enter to continue..."
    Read-Host
    
    if (-not (Wait-ForDocker)) {
        Write-Host "❌ Cannot proceed without Docker. Please start Docker Desktop and try again." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ Docker is running!" -ForegroundColor Green
}

# Install Python dependencies
Write-Host "`n2️⃣ Installing Python dependencies..."
try {
    pip install -r requirements.txt
    Write-Host "✅ Dependencies installed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Build and start Docker services
Write-Host "`n3️⃣ Starting Docker services..."
try {
    # Stop any existing services
    docker-compose down 2>$null
    
    # Start the full stack
    docker-compose up -d --build
    Write-Host "✅ Docker services started!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to start Docker services" -ForegroundColor Red
    exit 1
}

# Wait for services to be ready
Write-Host "`n4️⃣ Waiting for services to be ready..."
Start-Sleep -Seconds 30

# Start the backend API
Write-Host "`n5️⃣ Starting AI Lab Backend API..."
Write-Host "🌐 Frontend will be available at: http://localhost:5555" -ForegroundColor Cyan
Write-Host "🔧 API health check: http://localhost:5555/api/health" -ForegroundColor Cyan
Write-Host "📊 MLflow: http://localhost:5000" -ForegroundColor Cyan
Write-Host "📈 Grafana: http://localhost:3000 (admin/admin123)" -ForegroundColor Cyan
Write-Host "🔍 Prometheus: http://localhost:9090" -ForegroundColor Cyan
Write-Host "`n✨ Starting backend API server (Ctrl+C to stop)..." -ForegroundColor Green

# Start the backend in a new process
Start-Process powershell -ArgumentList "-Command", "cd '$PWD'; python ai_lab_backend.py"

Write-Host "`n🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "📋 To run tests, open a new terminal and run: python test_environment_management.py" -ForegroundColor Yellow 