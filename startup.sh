#!/bin/bash
#
# Startup script for Intelligent Supply Chain Digital Twin project
# Usage: ./startup.sh [OPTIONS]
# Options:
#   --trigger    Trigger DAG after startup
#   --browser    Open browser to Airflow UI
#   --logs       Follow logs after startup
#   --rebuild    Rebuild Docker image
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Parse arguments
TRIGGER=false
BROWSER=false
LOGS=false
REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --trigger) TRIGGER=true; shift ;;
        --browser) BROWSER=true; shift ;;
        --logs) LOGS=true; shift ;;
        --rebuild) REBUILD=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Helper functions
write_header() {
    echo -e "\n${CYAN}$(printf '=%.0s' {1..60})${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..60})${NC}"
}

write_success() {
    echo -e "${GREEN} $1${NC}"
}

write_error() {
    echo -e "${RED}❌ $1${NC}"
}

write_warning() {
    echo -e "${YELLOW}  $1${NC}"
}

write_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

write_header " Intelligent Supply Chain Digital Twin - Startup"

# 1. Check if in correct directory
write_info "Checking project directory..."
if [ ! -f "docker-compose.yaml" ]; then
    write_error "docker-compose.yaml not found in current directory"
    echo "Please run this script from the project root directory"
    exit 1
fi
write_success "Project root directory verified"

# 2. Check if .env file exists
write_info "Checking .env file..."
if [ ! -f ".env" ]; then
    write_error ".env file not found"
    echo ""
    echo "Please create .env from .env.example:"
    echo -e "${YELLOW}  cp .env.example .env${NC}"
    echo -e "${YELLOW}  # Then edit .env and update passwords${NC}"
    echo ""
    exit 1
fi
write_success ".env file found"

# 3. Load and validate .env variables
write_info "Loading environment variables from .env..."
source .env

# Define required variables
REQUIRED_VARS=(
    "POSTGRES_PASSWORD"
    "AIRFLOW_FERNET_KEY"
    "AIRFLOW_ADMIN_USERNAME"
    "AIRFLOW_ADMIN_PASSWORD"
)

# Check for missing variables
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    write_error "Missing or empty required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "${RED}  - $var${NC}"
    done
    echo ""
    echo -e "${YELLOW}Please edit .env and provide values for all required variables${NC}"
    exit 1
fi

write_success "All required environment variables are set"

# 4. Check if Docker is running
write_info "Checking Docker daemon..."
if ! docker ps > /dev/null 2>&1; then
    write_error "Docker is not running or not installed"
    echo -e "${YELLOW}Please start Docker and try again${NC}"
    exit 1
fi
write_success "Docker is running"

# 5. Check if containers are already running
write_info "Checking existing containers..."
RUNNING=$(docker-compose ps --services --filter "status=running" 2>/dev/null || true)
if [ -n "$RUNNING" ]; then
    write_warning "Some services are already running: $RUNNING"
    echo -e "${YELLOW}Restarting services to apply configuration changes...${NC}"
    docker-compose down --remove-orphans > /dev/null 2>&1 || true
fi

# 6. Rebuild image if requested
if [ "$REBUILD" = true ]; then
    write_header "🔨 Rebuilding Docker Image"
    docker-compose build --no-cache
fi

# 7. Start services
write_header "  Starting Services"

write_info "Starting Docker Compose services..."
echo -e "${GRAY}This may take a minute on first run...${NC}"

docker-compose --env-file .env up -d

write_success "Docker services started"

# 8. Wait for services to initialize
write_header " Waiting for Services to Initialize"

MAX_WAIT=120
WAIT_INTERVAL=5
ELAPSED=0

write_info "Waiting for PostgreSQL to be ready..."

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        write_success "PostgreSQL is ready"
        break
    fi
    
    echo -n "."
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    write_warning "PostgreSQL took too long to start, but continuing..."
fi

write_info "Waiting for Airflow to initialize (30 seconds)..."
sleep 30

write_success "Services should be ready"

# 9. Display service status
write_header " Service Status"
docker-compose ps

# 10. Display access information
write_header " Access URLs"

echo -e "\n${CYAN}  Airflow Webserver:${NC}"
echo -e "  ${GREEN} http://localhost:8081${NC}"
echo -e "  ${GRAY}   Username: $AIRFLOW_ADMIN_USERNAME${NC}"
echo -e "  ${GRAY}   Password: (from .env)${NC}"

echo -e "\n${CYAN}  PgAdmin:${NC}"
echo -e "  ${GREEN} http://localhost:8080${NC}"
echo -e "  ${GRAY}   Email: admin@example.com${NC}"
echo -e "  ${GRAY}   Password: (from .env)${NC}"

echo -e "\n${CYAN}  PostgreSQL:${NC}"
echo -e "  ${GREEN} http://localhost:5435${NC}"
echo -e "  ${GRAY}   Database: supply_chain_db${NC}"
echo -e "  ${GRAY}   User: user${NC}"
echo -e "  ${GRAY}   Password: (from .env)${NC}"

echo ""

# 11. Check if DAG exists in Airflow
write_info "Verifying DAG registration..."
sleep 10

if docker-compose exec -T airflow-webserver airflow dags list 2>/dev/null | grep -q "supply_chain_pipeline"; then
    write_success "DAG 'supply_chain_pipeline' is registered"
else
    write_warning "DAG 'supply_chain_pipeline' not found yet"
    echo -e "${YELLOW}It may take a few more seconds to appear in Airflow${NC}"
fi

# 12. Optionally trigger DAG
if [ "$TRIGGER" = true ]; then
    write_header " Triggering DAG"
    write_info "Triggering supply_chain_pipeline DAG..."
    
    sleep 5
    
    if docker-compose exec -T airflow-webserver airflow dags trigger supply_chain_pipeline 2>/dev/null; then
        write_success "DAG triggered successfully"
        write_info "Monitor progress in Airflow UI or with: docker-compose logs -f airflow-scheduler"
    else
        write_warning "Could not trigger DAG via CLI (you can trigger manually in UI)"
    fi
fi

# 13. Optionally open browser
if [ "$BROWSER" = true ]; then
    write_info "Opening Airflow UI in browser..."
    sleep 2
    if command -v xdg-open > /dev/null; then
        xdg-open "http://localhost:8081" &
    elif command -v open > /dev/null; then
        open "http://localhost:8081" &
    else
        write_warning "Could not open browser automatically"
    fi
fi

# 14. Optionally follow logs
if [ "$LOGS" = true ]; then
    write_header " Following Logs (Press Ctrl+C to stop)"
    write_info "Showing logs from all services..."
    docker-compose logs -f
fi

# 15. Show next steps
write_header " Next Steps"

echo -e "\n${GREEN}  1. Open Airflow UI in browser:${NC}"
echo -e "     ${CYAN}http://localhost:8081${NC}"

echo -e "\n${GREEN}  2. Login with credentials from .env${NC}"

echo -e "\n${GREEN}  3. Enable the DAG:${NC}"
echo -e "     ${CYAN}Toggle ON the 'supply_chain_pipeline' DAG${NC}"

echo -e "\n${GREEN}  4. Trigger manually (optional):${NC}"
echo -e "     ${CYAN}Run: docker-compose exec airflow-webserver airflow dags trigger supply_chain_pipeline${NC}"

echo -e "\n${GREEN}  5. Monitor execution:${NC}"
echo -e "     ${CYAN}Run: docker-compose logs -f airflow-scheduler${NC}"

echo -e "\n${GREEN}  6. View data in PgAdmin:${NC}"
echo -e "     ${CYAN}http://localhost:8080${NC}"

echo -e "\n${GREEN}  Useful Commands:${NC}"
echo -e "     ${GRAY}docker-compose ps                 # Check service status${NC}"
echo -e "     ${GRAY}docker-compose logs -f            # Follow all logs${NC}"
echo -e "     ${GRAY}docker-compose logs -f postgres   # Follow PostgreSQL logs${NC}"
echo -e "     ${GRAY}docker-compose down               # Stop all services (data persists)${NC}"
echo -e "     ${GRAY}docker-compose down -v            # Stop and delete all data${NC}"

echo ""
write_success "✨ Project startup complete! Services are running."
write_info "Open http://localhost:8081 to access Airflow"

exit 0
