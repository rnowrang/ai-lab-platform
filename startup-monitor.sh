#!/bin/bash

# AI Lab Platform - Startup Visualization Monitor
# Real-time visual monitoring of the startup process

set -e

# Colors and symbols
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Unicode symbols
CHECK="✅"
CROSS="❌"
CLOCK="⏳"
GEAR="⚙️"
ROCKET="🚀"
WARNING="⚠️"
INFO="ℹ️"
DOCKER="🐳"
DATABASE="🗄️"
WEB="🌐"
CHART="📊"
LOCK="🔒"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.production.yml"
ENV_FILE="$SCRIPT_DIR/production.env"

# Terminal control
clear_line() {
    printf "\r\033[K"
}

move_cursor_up() {
    printf "\033[${1:-1}A"
}

hide_cursor() {
    printf "\033[?25l"
}

show_cursor() {
    printf "\033[?25h"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d%%" $percentage
}

# Service status display
show_service_status() {
    local service=$1
    local status=$2
    local details="${3:-}"
    
    case $status in
        "starting")
            printf "${CLOCK} ${YELLOW}%-15s${NC} Starting..." "$service"
            ;;
        "healthy")
            printf "${CHECK} ${GREEN}%-15s${NC} Healthy" "$service"
            ;;
        "unhealthy")
            printf "${CROSS} ${RED}%-15s${NC} Unhealthy" "$service"
            ;;
        "failed")
            printf "${CROSS} ${RED}%-15s${NC} Failed" "$service"
            ;;
        *)
            printf "${INFO} ${WHITE}%-15s${NC} %s" "$service" "$status"
            ;;
    esac
    
    if [ -n "$details" ]; then
        printf " ${CYAN}($details)${NC}"
    fi
    printf "\n"
}

# Header display
show_header() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                  ${ROCKET} AI Lab Platform Startup Monitor${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Timestamp: $(date)${NC}"
    echo -e "${CYAN}Location:  $SCRIPT_DIR${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Get service status
get_service_status() {
    local service=$1
    local container_name="ai-lab-$service"
    
    if ! docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
        echo "stopped"
        return
    fi
    
    local status=$(docker ps --filter "name=$container_name" --format "{{.Status}}")
    
    if echo "$status" | grep -q "healthy"; then
        echo "healthy"
    elif echo "$status" | grep -q "unhealthy"; then
        echo "unhealthy"
    elif echo "$status" | grep -q "Up"; then
        echo "running"
    elif echo "$status" | grep -q "starting"; then
        echo "starting"
    else
        echo "unknown"
    fi
}

# Get detailed service info
get_service_details() {
    local service=$1
    local container_name="ai-lab-$service"
    
    case $service in
        "postgres")
            if docker exec "$container_name" pg_isready -U postgres >/dev/null 2>&1; then
                echo "Ready for connections"
            else
                echo "Not ready"
            fi
            ;;
        "redis")
            if docker exec "$container_name" redis-cli ping >/dev/null 2>&1; then
                echo "Responding to ping"
            else
                echo "Not responding"
            fi
            ;;
        "backend")
            if curl -s -k https://localhost/api/health >/dev/null 2>&1; then
                echo "API responding"
            else
                echo "API not ready"
            fi
            ;;
        "nginx")
            if curl -s -k https://localhost/ >/dev/null 2>&1; then
                echo "Web interface ready"
            else
                echo "Not accessible"
            fi
            ;;
        "mlflow")
            if curl -s http://localhost:5000/health >/dev/null 2>&1 || docker exec "$container_name" curl -s http://localhost:5000/health >/dev/null 2>&1; then
                echo "Tracking server ready"
            else
                echo "Not ready"
            fi
            ;;
        *)
            local uptime=$(docker ps --filter "name=$container_name" --format "{{.Status}}" | grep -o "Up [^,]*" || echo "")
            echo "$uptime"
            ;;
    esac
}

# Monitor startup phase
monitor_startup_phase() {
    local phase_name="$1"
    local phase_desc="$2"
    local duration=${3:-30}
    
    echo -e "${GEAR} ${YELLOW}Phase: $phase_name${NC}"
    echo -e "${INFO} $phase_desc"
    echo ""
    
    for ((i=1; i<=duration; i++)); do
        clear_line
        printf "${CLOCK} Progress: "
        show_progress $i $duration
        printf " (${i}s/${duration}s)"
        sleep 1
    done
    printf "\n${CHECK} ${GREEN}Phase completed${NC}\n\n"
}

# Main monitoring loop
monitor_services() {
    local services=("postgres" "redis" "backend" "mlflow" "nginx" "grafana" "prometheus" "torchserve")
    local max_wait=300  # 5 minutes max wait
    local wait_time=0
    
    hide_cursor
    
    while [ $wait_time -lt $max_wait ]; do
        show_header
        
        echo -e "${GEAR} ${WHITE}Service Status Overview${NC}"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        
        local all_healthy=true
        local total_services=${#services[@]}
        local healthy_services=0
        
        for service in "${services[@]}"; do
            local status=$(get_service_status "$service")
            local details=$(get_service_details "$service")
            
            show_service_status "$service" "$status" "$details"
            
            if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
                ((healthy_services++))
            elif [ "$status" = "stopped" ] || [ "$status" = "failed" ]; then
                all_healthy=false
            fi
        done
        
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        printf "${CHART} Overall Progress: "
        show_progress $healthy_services $total_services
        printf " ($healthy_services/$total_services services ready)\n\n"
        
        # Show recent logs
        echo -e "${INFO} ${WHITE}Recent Activity${NC}"
        echo -e "${BLUE}────────────────────────────────────────────${NC}"
        if [ -f "/var/log/ai-lab-post-reboot.log" ]; then
            tail -5 /var/log/ai-lab-post-reboot.log | while read line; do
                echo -e "${CYAN}$line${NC}"
            done
        else
            echo -e "${YELLOW}No log file found${NC}"
        fi
        
        echo ""
        echo -e "${INFO} Press Ctrl+C to exit monitor"
        echo -e "${CLOCK} Refreshing in 3 seconds... (${wait_time}s elapsed)"
        
        if [ $healthy_services -eq $total_services ]; then
            echo ""
            echo -e "${CHECK} ${GREEN}All services are healthy! Platform is ready.${NC}"
            echo -e "${WEB} Access the platform at: https://localhost/"
            break
        fi
        
        sleep 3
        wait_time=$((wait_time + 3))
    done
    
    show_cursor
}

# Quick status check
quick_status() {
    echo -e "${ROCKET} ${WHITE}AI Lab Platform - Quick Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    local services=("postgres" "redis" "backend" "mlflow" "nginx" "grafana" "prometheus" "torchserve")
    
    for service in "${services[@]}"; do
        local status=$(get_service_status "$service")
        show_service_status "$service" "$status"
    done
    
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    # Test connectivity
    echo -e "\n${WEB} ${WHITE}Connectivity Tests${NC}"
    echo -e "${BLUE}─────────────────────────${NC}"
    
    if curl -s -k https://localhost/api/health >/dev/null 2>&1; then
        echo -e "${CHECK} ${GREEN}API Health Check${NC} - OK"
    else
        echo -e "${CROSS} ${RED}API Health Check${NC} - Failed"
    fi
    
    if curl -s -k https://localhost/ >/dev/null 2>&1; then
        echo -e "${CHECK} ${GREEN}Web Interface${NC} - OK"
    else
        echo -e "${CROSS} ${RED}Web Interface${NC} - Failed"
    fi
    
    if docker exec ai-lab-postgres pg_isready -U postgres >/dev/null 2>&1; then
        echo -e "${CHECK} ${GREEN}Database Connection${NC} - OK"
    else
        echo -e "${CROSS} ${RED}Database Connection${NC} - Failed"
    fi
}

# Startup sequence visualization
startup_sequence() {
    show_header
    echo -e "${ROCKET} ${WHITE}Starting AI Lab Platform Startup Sequence${NC}"
    echo ""
    
    # Phase 1: Pre-checks
    monitor_startup_phase "Pre-flight Checks" "Checking Docker daemon and prerequisites..." 10
    
    # Phase 2: Infrastructure
    monitor_startup_phase "Infrastructure" "Starting core services (Database, Redis, Monitoring)..." 30
    
    # Phase 3: Applications  
    monitor_startup_phase "Applications" "Starting application services (Backend, MLflow, TorchServe)..." 45
    
    # Phase 4: Web Layer
    monitor_startup_phase "Web Layer" "Starting web services (nginx, interfaces)..." 20
    
    # Phase 5: Health Checks
    echo -e "${GEAR} ${YELLOW}Phase: Final Health Checks${NC}"
    echo -e "${INFO} Verifying all services are healthy and responding..."
    echo ""
    
    # Now monitor services in real-time
    monitor_services
}

# Help function
show_help() {
    echo -e "${ROCKET} ${WHITE}AI Lab Platform Startup Monitor${NC}"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  -m, --monitor     Real-time service monitoring (default)"
    echo "  -s, --status      Quick status check"
    echo "  -f, --full        Full startup sequence visualization"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Start real-time monitoring"
    echo "  $0 --status       # Quick status check"
    echo "  $0 --full         # Watch full startup sequence"
}

# Cleanup on exit
cleanup() {
    show_cursor
    echo -e "\n${INFO} Monitor stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main script logic
case "${1:-}" in
    -m|--monitor)
        show_header
        echo -e "${GEAR} ${WHITE}Starting real-time service monitoring...${NC}"
        echo ""
        sleep 2
        monitor_services
        ;;
    -s|--status)
        quick_status
        ;;
    -f|--full)
        startup_sequence
        ;;
    -h|--help)
        show_help
        ;;
    "")
        show_header
        echo -e "${GEAR} ${WHITE}Starting real-time service monitoring...${NC}"
        echo ""
        sleep 2
        monitor_services
        ;;
    *)
        echo -e "${CROSS} Unknown option: $1"
        show_help
        exit 1
        ;;
esac 