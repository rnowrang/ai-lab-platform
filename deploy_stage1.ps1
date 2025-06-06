# PowerShell script for Windows Docker Compose deployment
param(
    [string]$Domain = "ml-platform.local",
    [string]$GitHubClientId = "your-github-client-id",
    [string]$GitHubClientSecret = "your-github-client-secret"
)

Write-Host "🪟 Windows ML Platform Deployment" -ForegroundColor Green
Write-Host "Using Docker Compose for local development" -ForegroundColor Yellow

# Check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue
    
    # Check Docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is required. Please install Docker Desktop for Windows."
        exit 1
    }
    
    # Check Docker Compose
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Error "Docker Compose is required. Please install Docker Desktop for Windows."
        exit 1
    }
    
    # Check if Docker is running
    try {
        docker version | Out-Null
    }
    catch {
        Write-Error "Docker is not running. Please start Docker Desktop."
        exit 1
    }
    
    Write-Host "✅ Prerequisites check passed" -ForegroundColor Green
}

# Setup environment
function Set-Environment {
    Write-Host "Setting up environment variables..." -ForegroundColor Blue
    
    $env:DOMAIN = $Domain
    $env:GITHUB_CLIENT_ID = $GitHubClientId
    $env:GITHUB_CLIENT_SECRET = $GitHubClientSecret
    
    Write-Host "✅ Environment configured" -ForegroundColor Green
}

# Start services
function Start-Services {
    Write-Host "Starting ML Platform services..." -ForegroundColor Blue
    
    try {
        # Build and start services
        docker-compose up --build -d
        
        Write-Host "✅ Services started successfully" -ForegroundColor Green
        
        # Wait for services to be ready
        Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # Show status
        docker-compose ps
        
    }
    catch {
        Write-Error "Failed to start services: $_"
        exit 1
    }
}

# Print access information
function Show-AccessInfo {
    Write-Host ""
    Write-Host "🎉 ML Platform Started Successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Access URLs ===" -ForegroundColor Cyan
    Write-Host "JupyterLab:        http://localhost:8888" -ForegroundColor White
    Write-Host "VS Code Server:    http://localhost:8080" -ForegroundColor White
    Write-Host "MLflow:            http://localhost:5000" -ForegroundColor White
    Write-Host "TorchServe:        http://localhost:8081" -ForegroundColor White
    Write-Host "Grafana:           http://localhost:3000 (admin/admin123)" -ForegroundColor White
    Write-Host "Prometheus:        http://localhost:9090" -ForegroundColor White
    Write-Host ""
    Write-Host "=== Quick Start ===" -ForegroundColor Cyan
    Write-Host "1. Open JupyterLab: http://localhost:8888" -ForegroundColor Yellow
    Write-Host "2. Create a notebook and start experimenting!" -ForegroundColor Yellow
    Write-Host "3. Models will be tracked in MLflow automatically" -ForegroundColor Yellow
    Write-Host "4. Monitor everything in Grafana" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== Stop Platform ===" -ForegroundColor Cyan
    Write-Host "docker-compose down" -ForegroundColor Red
    Write-Host ""
    Write-Host "=== View Logs ===" -ForegroundColor Cyan
    Write-Host "docker-compose logs -f [service-name]" -ForegroundColor White
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "🚀 Starting Windows ML Platform Deployment..." -ForegroundColor Magenta
    Write-Host ""
    
    Test-Prerequisites
    Set-Environment
    Start-Services
    Show-AccessInfo
}

# Run main function
Main 