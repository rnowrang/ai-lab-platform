#!/usr/bin/env pwsh

Write-Host "🔒 Testing User Isolation and Access Control" -ForegroundColor Cyan

# Test 1: Bob tries to stop Alice's environment (should be denied)
Write-Host "`n1. Testing Bob trying to stop Alice's environment:" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5555/api/environments/ai-lab-pytorch-jupyter-1749421551/stop" -Method POST -ContentType "application/json" -Body '{"user_id": "bob@company.com"}' -ErrorAction Stop
    Write-Host "❌ SECURITY ISSUE: Bob was able to stop Alice's environment!" -ForegroundColor Red
    Write-Host $response
} catch {
    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
    if ($errorResponse.error -like "*Access denied*") {
        Write-Host "✅ Access correctly denied: $($errorResponse.error)" -ForegroundColor Green
    } else {
        Write-Host "❓ Unexpected error: $($errorResponse.error)" -ForegroundColor Orange
    }
}

# Test 2: Alice tries to stop her own environment (should succeed)
Write-Host "`n2. Testing Alice stopping her own environment:" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5555/api/environments/ai-lab-pytorch-jupyter-1749421551/stop" -Method POST -ContentType "application/json" -Body '{"user_id": "alice@company.com"}' -ErrorAction Stop
    Write-Host "✅ Alice successfully stopped her environment: $($response.message)" -ForegroundColor Green
} catch {
    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "❌ Alice couldn't stop her own environment: $($errorResponse.error)" -ForegroundColor Red
}

# Test 3: Check what each user sees after the stop
Write-Host "`n3. Checking what each user sees after stopping:" -ForegroundColor Yellow

Write-Host "Alice's environments:" -ForegroundColor Cyan
$aliceEnvs = Invoke-RestMethod -Uri "http://localhost:5555/api/users/alice@company.com/environments"
Write-Host "Count: $($aliceEnvs.environments.Count)"
$aliceEnvs.environments | ForEach-Object { Write-Host "  - $($_.name) ($($_.status))" }

Write-Host "Bob's environments:" -ForegroundColor Cyan
$bobEnvs = Invoke-RestMethod -Uri "http://localhost:5555/api/users/bob@company.com/environments"
Write-Host "Count: $($bobEnvs.environments.Count)"
$bobEnvs.environments | ForEach-Object { Write-Host "  - $($_.name) ($($_.status))" }

Write-Host "`n🎯 User isolation test completed!" -ForegroundColor Cyan 