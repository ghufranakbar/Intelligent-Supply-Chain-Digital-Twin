#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Startup script for Intelligent Supply Chain Digital Twin project
    
.DESCRIPTION
    Starts all Docker services (PostgreSQL, PgAdmin, Airflow) and validates configuration
    
.EXAMPLE
    .\startup.ps1
    .\startup.ps1 -Trigger
#>

param(
    [Switch]$Trigger,      # Trigger DAG after startup
    [Switch]$Browser,      # Open browser to Airflow UI
    [Switch]$Logs,         # Follow logs after startup
    [Switch]$RebuildImage  # Rebuild Docker image
)

# Color scheme
$Green = @{ForegroundColor = 'Green'}
$Red = @{ForegroundColor = 'Red'}
$Yellow = @{ForegroundColor = 'Yellow'}
$Cyan = @{ForegroundColor = 'Cyan'}
$Gray = @{ForegroundColor = 'Gray'}

function Write-Header {
    param([string]$Message)
    Write-Host "`n$('=' * 60)" @Cyan
    Write-Host $Message @Cyan
    Write-Host $('=' * 60) @Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" @Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ $Message" @Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  $Message" @Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" @Cyan
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Write-Header "🚀 Intelligent Supply Chain Digital Twin - Startup"

# 1. Check if in correct directory
Write-Info "Checking project directory..."
if (-not (Test-Path "docker-compose.yaml")) {
    Write-Error-Custom "docker-compose.yaml not found in current directory"
    Write-Host "Please run this script from the project root directory" @Red
    exit 1
}
Write-Success "Project root directory verified"

# 2. Check if .env file exists
Write-Info "Checking .env file..."
if (-not (Test-Path ".env")) {
    Write-Error-Custom ".env file not found"
    Write-Host @Red
    Write-Host "Please create .env from .env.example:" @Yellow
    Write-Host "  cp .env.example .env" @Yellow
    Write-Host "  # Then edit .env and update passwords" @Yellow
    Write-Host @Red
    exit 1
}
Write-Success ".env file found"

# 3. Load and validate .env variables
Write-Info "Loading environment variables from .env..."
$envVars = @{}
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$key] = $value
    }
}

# Define required variables
$requiredVars = @(
    'POSTGRES_PASSWORD',
    'AIRFLOW_FERNET_KEY',
    'AIRFLOW_ADMIN_USERNAME',
    'AIRFLOW_ADMIN_PASSWORD'
)

$missingVars = @()
foreach ($var in $requiredVars) {
    if (-not $envVars.ContainsKey($var) -or [string]::IsNullOrWhiteSpace($envVars[$var])) {
        $missingVars += $var
    }
}

if ($missingVars.Count -gt 0) {
    Write-Error-Custom "Missing or empty required environment variables:"
    $missingVars | ForEach-Object { Write-Host "  - $_" @Red }
    Write-Host @Red
    Write-Host "Please edit .env and provide values for all required variables" @Yellow
    exit 1
}

Write-Success "All required environment variables are set"

# 4. Check if Docker is running
Write-Info "Checking Docker daemon..."
try {
    $null = docker ps 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not running"
    }
} catch {
    Write-Error-Custom "Docker is not running or not installed"
    Write-Host "Please start Docker Desktop and try again" @Yellow
    exit 1
}
Write-Success "Docker is running"

# 5. Check if containers are already running
Write-Info "Checking existing containers..."
$runningContainers = docker-compose ps --services --filter "status=running" 2>$null
if ($runningContainers) {
    Write-Warning-Custom "Some services are already running"
    Write-Host "Services running: $($runningContainers -join ', ')" @Yellow
    Write-Host "Restarting services to apply configuration changes..." @Yellow
    docker-compose down --remove-orphans | Out-Null
}

# 6. Rebuild image if requested
if ($RebuildImage) {
    Write-Header "🔨 Rebuilding Docker Image"
    docker-compose build --no-cache
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Docker image build failed"
        exit 1
    }
}

# 7. Start services
Write-Header "  Starting Services"

Write-Info "Starting Docker Compose services..."
Write-Host "This may take a minute on first run..." @Gray

# Use --env-file to explicitly load .env
docker-compose --env-file .env up -d 2>&1 | ForEach-Object {
    if ($_ -match "Starting|Created|Attaching") {
        Write-Host "  $_" @Gray
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to start Docker Compose services"
    exit 1
}

Write-Success "Docker services started"

# 8. Wait for services to initialize
Write-Header " Waiting for Services to Initialize"

$maxWaitTime = 120  # 2 minutes
$waitInterval = 5
$elapsedTime = 0

Write-Info "Waiting for PostgreSQL to be ready..."

while ($elapsedTime -lt $maxWaitTime) {
    try {
        # Try to connect to PostgreSQL
        $result = docker-compose exec -T postgres pg_isready -U postgres 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "PostgreSQL is ready"
            break
        }
    } catch {
        # Continue waiting
    }
    
    Write-Host "." -NoNewline @Gray
    Start-Sleep -Seconds $waitInterval
    $elapsedTime += $waitInterval
}

if ($elapsedTime -ge $maxWaitTime) {
    Write-Warning-Custom "PostgreSQL took too long to start, but continuing..."
}

Write-Info "Waiting for Airflow to initialize (30 seconds)..."
Start-Sleep -Seconds 30

Write-Success "Services should be ready"

# 9. Display service status
Write-Header " Service Status"

$services = docker-compose ps --services
$output = docker-compose ps

Write-Host $output @Gray

# 10. Display access information
Write-Header " Access URLs"

Write-Host "`n  Airflow Webserver:" @Cyan
Write-Host "   http://localhost:8081" @Green
Write-Host "     Username: $($envVars['AIRFLOW_ADMIN_USERNAME'])" @Gray
Write-Host "     Password: (from .env)" @Gray

Write-Host "`n  PgAdmin:" @Cyan
Write-Host "   http://localhost:8080" @Green
Write-Host "     Email: admin@example.com" @Gray
Write-Host "     Password: (from .env)" @Gray

Write-Host "`n  PostgreSQL:" @Cyan
Write-Host "   http://localhost:5435" @Green
Write-Host "     Database: supply_chain_db" @Gray
Write-Host "     User: user" @Gray
Write-Host "     Password: (from .env)" @Gray

Write-Host "`n"

# 11. Check if DAG exists in Airflow
Write-Info "Verifying DAG registration..."
Start-Sleep -Seconds 10

try {
    $dagList = docker-compose exec -T airflow-webserver airflow dags list 2>&1
    if ($dagList -match "supply_chain_pipeline") {
        Write-Success "DAG 'supply_chain_pipeline' is registered"
    } else {
        Write-Warning-Custom "DAG 'supply_chain_pipeline' not found yet"
        Write-Host "It may take a few more seconds to appear in Airflow" @Yellow
    }
} catch {
    Write-Warning-Custom "Could not verify DAG registration (this is OK, check UI)"
}

# 12. Optionally trigger DAG
if ($Trigger) {
    Write-Header "🎯 Triggering DAG"
    Write-Info "Triggering supply_chain_pipeline DAG..."
    
    Start-Sleep -Seconds 5
    
    try {
        docker-compose exec -T airflow-webserver airflow dags trigger supply_chain_pipeline 2>&1 | Out-Null
        Write-Success "DAG triggered successfully"
        Write-Info "Monitor progress in Airflow UI or with: docker-compose logs -f airflow-scheduler"
    } catch {
        Write-Warning-Custom "Could not trigger DAG via CLI (you can trigger manually in UI)"
    }
}

# 13. Optionally open browser
if ($Browser) {
    Write-Info "Opening Airflow UI in browser..."
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:8081"
}

# 14. Optionally follow logs
if ($Logs) {
    Write-Header " Following Logs (Press Ctrl+C to stop)"
    Write-Info "Showing logs from all services..."
    docker-compose logs -f
}

# 15. Show next steps
Write-Header " Next Steps"

Write-Host "`n  1. Open Airflow UI in browser:" @Green
Write-Host "     http://localhost:8081" @Cyan

Write-Host "`n  2. Login with credentials from .env" @Green

Write-Host "`n  3. Enable the DAG:" @Green
Write-Host "     Toggle ON the 'supply_chain_pipeline' DAG" @Cyan

Write-Host "`n  4. Trigger manually (optional):" @Green
Write-Host "     Run: docker-compose exec airflow-webserver airflow dags trigger supply_chain_pipeline" @Cyan

Write-Host "`n  5. Monitor execution:" @Green
Write-Host "     Run: docker-compose logs -f airflow-scheduler" @Cyan

Write-Host "`n  6. View data in PgAdmin:" @Green
Write-Host "     http://localhost:8080" @Cyan

Write-Host "`n  Useful Commands:" @Green
Write-Host "     docker-compose ps                 # Check service status" @Gray
Write-Host "     docker-compose logs -f            # Follow all logs" @Gray
Write-Host "     docker-compose logs -f postgres   # Follow PostgreSQL logs" @Gray
Write-Host "     docker-compose down               # Stop all services (data persists)" @Gray
Write-Host "     docker-compose down -v            # Stop and delete all data" @Gray

Write-Host "`n"
Write-Success "✨ Project startup complete! Services are running."
Write-Info "Open http://localhost:8081 to access Airflow"

exit 0
